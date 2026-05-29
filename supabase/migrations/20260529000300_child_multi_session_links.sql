create table if not exists public.child_auth_sessions (
    auth_user_id uuid primary key references auth.users(id) on delete cascade,
    child_id uuid not null references public.children(id) on delete cascade,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

comment on table public.child_auth_sessions is 'Maps lightweight anonymous auth sessions to durable child records.';
comment on column public.children.auth_user_id is 'Legacy single-session child auth link. Authorization uses child_auth_sessions.';

create index if not exists child_auth_sessions_child_id_idx
    on public.child_auth_sessions (child_id);

drop trigger if exists child_auth_sessions_set_updated_at on public.child_auth_sessions;
create trigger child_auth_sessions_set_updated_at
before update on public.child_auth_sessions
for each row execute function public.set_updated_at();

insert into public.child_auth_sessions (auth_user_id, child_id)
select c.auth_user_id, c.id
from public.children c
where c.auth_user_id is not null
on conflict (auth_user_id) do update
set child_id = excluded.child_id;

drop index if exists public.children_auth_user_id_unique_idx;

create or replace function public.current_child_id()
returns uuid
language sql
stable
security definer
set search_path = public, auth
as $$
    select cas.child_id
    from public.child_auth_sessions cas
    where cas.auth_user_id = auth.uid()
    limit 1;
$$;

create or replace function public.claim_child_session(
    p_household_code text,
    p_login_name text,
    p_pin text
)
returns public.children
language plpgsql
security definer
set search_path = public, auth, extensions
as $$
declare
    current_user_id uuid := auth.uid();
    child_row public.children;
begin
    if current_user_id is null then
        raise exception 'Authentication required';
    end if;

    if not public.is_anonymous_auth_user() then
        raise exception 'Child PIN login requires an anonymous auth session';
    end if;

    select c.*
    into child_row
    from public.children c
    join public.households h on h.id = c.household_id
    where h.login_code = upper(trim(p_household_code))
      and c.login_name = lower(trim(p_login_name))
      and extensions.crypt(p_pin, c.pin_hash) = c.pin_hash
    for update;

    if not found then
        raise exception 'Invalid child login';
    end if;

    insert into public.child_auth_sessions (auth_user_id, child_id)
    values (current_user_id, child_row.id)
    on conflict (auth_user_id) do update
    set child_id = excluded.child_id;

    insert into public.profiles (id, household_id, role, display_name)
    values (current_user_id, child_row.household_id, 'child', child_row.display_name)
    on conflict (id) do update
    set household_id = excluded.household_id,
        role = 'child',
        display_name = excluded.display_name,
        updated_at = now();

    return child_row;
end;
$$;

alter table public.child_auth_sessions enable row level security;

drop policy if exists "Child auth sessions visible to owner" on public.child_auth_sessions;
create policy "Child auth sessions visible to owner"
on public.child_auth_sessions
for select
to authenticated
using (auth_user_id = auth.uid());

drop policy if exists "Children visible to household parent or self" on public.children;
create policy "Children visible to household parent or self"
on public.children
for select
to authenticated
using (
    (household_id = public.current_household_id() and public.is_parent())
    or id = public.current_child_id()
);

grant execute on function public.claim_child_session(text, text, text) to authenticated;
grant execute on function public.current_child_id() to authenticated;
