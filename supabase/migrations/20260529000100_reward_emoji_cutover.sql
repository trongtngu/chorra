drop function if exists public.create_reward(text, text, integer, text, uuid);
drop function if exists public.update_reward(uuid, text, text, integer, text);
drop function if exists public.reward_image_path_matches(text, uuid, uuid);
drop function if exists public.path_reward_id(text);

drop policy if exists "Reward images visible to scoped household members" on storage.objects;
drop policy if exists "Parents can upload reward images" on storage.objects;
drop policy if exists "Parents can update reward images" on storage.objects;

alter table public.rewards
    add column if not exists emoji text;

update public.rewards
set emoji = '🎁'
where emoji is null
   or char_length(trim(emoji)) = 0;

alter table public.rewards
    alter column emoji set default '🎁',
    alter column emoji set not null,
    drop column if exists description,
    drop column if exists image_storage_path,
    drop constraint if exists rewards_emoji_check,
    add constraint rewards_emoji_check check (char_length(trim(emoji)) between 1 and 16);

alter table public.reward_redemptions
    add column if not exists reward_emoji text;

update public.reward_redemptions
set reward_emoji = '🎁'
where reward_emoji is null
   or char_length(trim(reward_emoji)) = 0;

alter table public.reward_redemptions
    alter column reward_emoji set not null,
    drop column if exists reward_description,
    drop column if exists reward_image_storage_path,
    drop constraint if exists reward_redemptions_reward_emoji_check,
    add constraint reward_redemptions_reward_emoji_check check (char_length(trim(reward_emoji)) between 1 and 16);

create or replace function public.create_reward(
    p_name text,
    p_emoji text,
    p_point_cost integer,
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
    normalized_emoji text := coalesce(nullif(trim(p_emoji), ''), '🎁');
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

    if char_length(normalized_emoji) > 16 then
        raise exception 'Reward emoji is too long';
    end if;

    insert into public.rewards (
        id,
        household_id,
        created_by,
        name,
        emoji,
        point_cost
    )
    values (
        p_reward_id,
        parent_household_id,
        parent_user_id,
        trim(p_name),
        normalized_emoji,
        p_point_cost
    )
    returning * into reward_row;

    return reward_row;
end;
$$;

create or replace function public.update_reward(
    p_reward_id uuid,
    p_name text,
    p_emoji text,
    p_point_cost integer
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
    normalized_emoji text := coalesce(nullif(trim(p_emoji), ''), '🎁');
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

    if char_length(normalized_emoji) > 16 then
        raise exception 'Reward emoji is too long';
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

    update public.rewards
    set name = trim(p_name),
        emoji = normalized_emoji,
        point_cost = p_point_cost
    where id = reward_row.id
    returning * into reward_row;

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
        raise exception 'Not enough points to unlock this reward';
    end if;

    insert into public.reward_redemptions (
        household_id,
        child_id,
        reward_id,
        redeemed_by,
        reward_name,
        reward_emoji,
        reward_point_cost
    )
    values (
        child_row.household_id,
        child_row.id,
        reward_row.id,
        current_user_id,
        reward_row.name,
        reward_row.emoji,
        reward_row.point_cost
    )
    returning * into redemption_row;

    return redemption_row;
end;
$$;

grant execute on function public.create_reward(text, text, integer, uuid) to authenticated;
grant execute on function public.update_reward(uuid, text, text, integer) to authenticated;
grant execute on function public.redeem_reward(uuid) to authenticated;
