create table if not exists public.rewards (
    id uuid primary key default gen_random_uuid(),
    household_id uuid not null references public.households(id) on delete cascade,
    created_by uuid not null references auth.users(id) on delete restrict,
    name text not null check (char_length(trim(name)) between 1 and 160),
    description text,
    point_cost integer not null check (point_cost > 0 and point_cost <= 100000),
    image_storage_path text unique,
    is_archived boolean not null default false,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create index if not exists rewards_household_active_idx
    on public.rewards (household_id, is_archived, created_at desc);

create table if not exists public.reward_redemptions (
    id uuid primary key default gen_random_uuid(),
    household_id uuid not null references public.households(id) on delete cascade,
    child_id uuid not null references public.children(id) on delete cascade,
    reward_id uuid not null references public.rewards(id) on delete restrict,
    redeemed_by uuid not null references auth.users(id) on delete restrict,
    reward_name text not null,
    reward_description text,
    reward_point_cost integer not null check (reward_point_cost > 0),
    reward_image_storage_path text,
    redeemed_at timestamptz not null default now()
);

create index if not exists reward_redemptions_household_idx
    on public.reward_redemptions (household_id, redeemed_at desc);

create index if not exists reward_redemptions_child_id_idx
    on public.reward_redemptions (child_id, redeemed_at desc);

drop trigger if exists rewards_set_updated_at on public.rewards;
create trigger rewards_set_updated_at
before update on public.rewards
for each row execute function public.set_updated_at();

create or replace function public.path_reward_id(path text)
returns uuid
language sql
immutable
as $$
    select case
        when split_part(path, '/', 2) ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
            then split_part(path, '/', 2)::uuid
        else null
    end;
$$;

create or replace view public.child_points_balances
with (security_invoker = true) as
select
    c.id as child_id,
    c.household_id,
    (
        coalesce(earned.points, 0) - coalesce(spent.points, 0)
    )::integer as points,
    earned.last_earned_at
from public.children c
left join lateral (
    select
        sum(pl.amount)::integer as points,
        max(pl.created_at) as last_earned_at
    from public.points_ledger pl
    where pl.child_id = c.id
) earned on true
left join lateral (
    select sum(rr.reward_point_cost)::integer as points
    from public.reward_redemptions rr
    where rr.child_id = c.id
) spent on true;

create or replace function public.reward_image_path_matches(
    p_storage_path text,
    p_household_id uuid,
    p_reward_id uuid
)
returns boolean
language sql
immutable
as $$
    select p_storage_path is null
        or (
            public.path_household_id(p_storage_path) = p_household_id
            and public.path_reward_id(p_storage_path) = p_reward_id
        );
$$;

create or replace function public.create_reward(
    p_name text,
    p_description text,
    p_point_cost integer,
    p_image_storage_path text default null,
    p_reward_id uuid default gen_random_uuid()
)
returns public.rewards
language plpgsql
security definer
set search_path = public, auth
as $$
declare
    parent_user_id uuid := auth.uid();
    parent_household_id uuid := public.current_household_id();
    reward_row public.rewards;
    normalized_image_path text := nullif(trim(p_image_storage_path), '');
begin
    if parent_user_id is null or not public.is_parent() then
        raise exception 'Parent authentication required';
    end if;

    if p_name is null or char_length(trim(p_name)) = 0 then
        raise exception 'Reward name is required';
    end if;

    if p_point_cost is null or p_point_cost <= 0 then
        raise exception 'Reward point cost must be positive';
    end if;

    if not public.reward_image_path_matches(normalized_image_path, parent_household_id, p_reward_id) then
        raise exception 'Reward image path does not match the household reward scope';
    end if;

    insert into public.rewards (
        id,
        household_id,
        created_by,
        name,
        description,
        point_cost,
        image_storage_path
    )
    values (
        p_reward_id,
        parent_household_id,
        parent_user_id,
        trim(p_name),
        nullif(trim(p_description), ''),
        p_point_cost,
        normalized_image_path
    )
    returning * into reward_row;

    return reward_row;
end;
$$;

create or replace function public.update_reward(
    p_reward_id uuid,
    p_name text,
    p_description text,
    p_point_cost integer,
    p_image_storage_path text default null
)
returns public.rewards
language plpgsql
security definer
set search_path = public, auth
as $$
declare
    parent_user_id uuid := auth.uid();
    parent_household_id uuid := public.current_household_id();
    reward_row public.rewards;
    normalized_image_path text := nullif(trim(p_image_storage_path), '');
begin
    if parent_user_id is null or not public.is_parent() then
        raise exception 'Parent authentication required';
    end if;

    if p_name is null or char_length(trim(p_name)) = 0 then
        raise exception 'Reward name is required';
    end if;

    if p_point_cost is null or p_point_cost <= 0 then
        raise exception 'Reward point cost must be positive';
    end if;

    select *
    into reward_row
    from public.rewards r
    where r.id = p_reward_id
      and r.household_id = parent_household_id
      and not r.is_archived
    for update;

    if not found then
        raise exception 'Reward not found';
    end if;

    if not public.reward_image_path_matches(normalized_image_path, parent_household_id, reward_row.id) then
        raise exception 'Reward image path does not match the household reward scope';
    end if;

    update public.rewards
    set name = trim(p_name),
        description = nullif(trim(p_description), ''),
        point_cost = p_point_cost,
        image_storage_path = normalized_image_path
    where id = reward_row.id
    returning * into reward_row;

    return reward_row;
end;
$$;

create or replace function public.archive_reward(p_reward_id uuid)
returns public.rewards
language plpgsql
security definer
set search_path = public, auth
as $$
declare
    parent_user_id uuid := auth.uid();
    parent_household_id uuid := public.current_household_id();
    reward_row public.rewards;
begin
    if parent_user_id is null or not public.is_parent() then
        raise exception 'Parent authentication required';
    end if;

    update public.rewards
    set is_archived = true
    where id = p_reward_id
      and household_id = parent_household_id
      and not is_archived
    returning * into reward_row;

    if not found then
        raise exception 'Reward not found';
    end if;

    return reward_row;
end;
$$;

create or replace function public.redeem_reward(p_reward_id uuid)
returns public.reward_redemptions
language plpgsql
security definer
set search_path = public, auth
as $$
declare
    current_user_id uuid := auth.uid();
    claimed_child_id uuid := public.current_child_id();
    child_row public.children;
    reward_row public.rewards;
    available_points integer;
    redemption_row public.reward_redemptions;
begin
    if current_user_id is null or claimed_child_id is null then
        raise exception 'Child authentication required';
    end if;

    select *
    into child_row
    from public.children c
    where c.id = claimed_child_id
    for update;

    if not found then
        raise exception 'Child not found';
    end if;

    select *
    into reward_row
    from public.rewards r
    where r.id = p_reward_id
      and r.household_id = child_row.household_id
      and not r.is_archived;

    if not found then
        raise exception 'Reward not found';
    end if;

    select coalesce(cpb.points, 0)
    into available_points
    from public.child_points_balances cpb
    where cpb.child_id = child_row.id;

    if coalesce(available_points, 0) < reward_row.point_cost then
        raise exception 'Not enough points to redeem this reward';
    end if;

    insert into public.reward_redemptions (
        household_id,
        child_id,
        reward_id,
        redeemed_by,
        reward_name,
        reward_description,
        reward_point_cost,
        reward_image_storage_path
    )
    values (
        child_row.household_id,
        child_row.id,
        reward_row.id,
        current_user_id,
        reward_row.name,
        reward_row.description,
        reward_row.point_cost,
        reward_row.image_storage_path
    )
    returning * into redemption_row;

    return redemption_row;
end;
$$;

insert into storage.buckets (
    id,
    name,
    public,
    file_size_limit,
    allowed_mime_types
)
values (
    'reward-images',
    'reward-images',
    false,
    52428800,
    array['image/jpeg', 'image/png', 'image/heic', 'image/heif', 'image/webp']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

alter table public.rewards enable row level security;
alter table public.reward_redemptions enable row level security;

drop policy if exists "Rewards visible to household members" on public.rewards;
create policy "Rewards visible to household members"
on public.rewards
for select
to authenticated
using (
    household_id = public.current_household_id()
    and (public.is_parent() or not is_archived)
);

drop policy if exists "Reward redemptions visible to household parent or child" on public.reward_redemptions;
create policy "Reward redemptions visible to household parent or child"
on public.reward_redemptions
for select
to authenticated
using (
    (household_id = public.current_household_id() and public.is_parent())
    or child_id = public.current_child_id()
);

drop policy if exists "Reward images visible to scoped household members" on storage.objects;
create policy "Reward images visible to scoped household members"
on storage.objects
for select
to authenticated
using (
    bucket_id = 'reward-images'
    and public.path_household_id(name) = public.current_household_id()
);

drop policy if exists "Parents can upload reward images" on storage.objects;
create policy "Parents can upload reward images"
on storage.objects
for insert
to authenticated
with check (
    bucket_id = 'reward-images'
    and public.is_parent()
    and public.path_household_id(name) = public.current_household_id()
);

drop policy if exists "Parents can update reward images" on storage.objects;
create policy "Parents can update reward images"
on storage.objects
for update
to authenticated
using (
    bucket_id = 'reward-images'
    and public.is_parent()
    and public.path_household_id(name) = public.current_household_id()
)
with check (
    bucket_id = 'reward-images'
    and public.is_parent()
    and public.path_household_id(name) = public.current_household_id()
);

grant select on
    public.rewards,
    public.reward_redemptions
to authenticated;

grant execute on function public.create_reward(text, text, integer, text, uuid) to authenticated;
grant execute on function public.update_reward(uuid, text, text, integer, text) to authenticated;
grant execute on function public.archive_reward(uuid) to authenticated;
grant execute on function public.redeem_reward(uuid) to authenticated;
grant execute on function public.path_reward_id(text) to authenticated;
