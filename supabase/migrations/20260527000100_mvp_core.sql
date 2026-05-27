create extension if not exists pgcrypto with schema extensions;

do $$
begin
    create type public.user_role as enum ('parent', 'child');
exception
    when duplicate_object then null;
end $$;

do $$
begin
    create type public.task_status as enum ('created', 'assigned', 'submitted', 'rejected', 'completed');
exception
    when duplicate_object then null;
end $$;

do $$
begin
    create type public.submission_status as enum ('submitted', 'approved', 'rejected');
exception
    when duplicate_object then null;
end $$;

do $$
begin
    create type public.ledger_reason as enum ('task_approved');
exception
    when duplicate_object then null;
end $$;

create table if not exists public.households (
    id uuid primary key default gen_random_uuid(),
    name text not null check (char_length(trim(name)) between 1 and 120),
    login_code text not null unique check (login_code = upper(login_code) and char_length(login_code) between 6 and 16),
    created_by uuid not null references auth.users(id) on delete restrict,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists public.profiles (
    id uuid primary key references auth.users(id) on delete cascade,
    household_id uuid not null references public.households(id) on delete cascade,
    role public.user_role not null,
    display_name text not null check (char_length(trim(display_name)) between 1 and 120),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create unique index if not exists profiles_one_household_per_parent_idx
    on public.profiles (id)
    where role = 'parent';

create table if not exists public.children (
    id uuid primary key default gen_random_uuid(),
    household_id uuid not null references public.households(id) on delete cascade,
    auth_user_id uuid references auth.users(id) on delete set null,
    display_name text not null check (char_length(trim(display_name)) between 1 and 120),
    login_name text not null check (login_name = lower(login_name) and char_length(login_name) between 1 and 64),
    pin_hash text not null,
    created_by uuid not null references auth.users(id) on delete restrict,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique (household_id, login_name)
);

create unique index if not exists children_auth_user_id_unique_idx
    on public.children (auth_user_id)
    where auth_user_id is not null;

create table if not exists public.tasks (
    id uuid primary key default gen_random_uuid(),
    household_id uuid not null references public.households(id) on delete cascade,
    created_by uuid not null references auth.users(id) on delete restrict,
    title text not null check (char_length(trim(title)) between 1 and 160),
    description text,
    point_value integer not null check (point_value > 0 and point_value <= 100000),
    status public.task_status not null default 'created',
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists public.task_assignments (
    id uuid primary key default gen_random_uuid(),
    household_id uuid not null references public.households(id) on delete cascade,
    task_id uuid not null references public.tasks(id) on delete cascade,
    child_id uuid not null references public.children(id) on delete cascade,
    assigned_by uuid not null references auth.users(id) on delete restrict,
    assigned_at timestamptz not null default now(),
    unique (task_id)
);

create index if not exists task_assignments_child_id_idx on public.task_assignments (child_id);

create table if not exists public.task_submissions (
    id uuid primary key default gen_random_uuid(),
    household_id uuid not null references public.households(id) on delete cascade,
    assignment_id uuid not null references public.task_assignments(id) on delete cascade,
    child_id uuid not null references public.children(id) on delete cascade,
    submitted_by uuid not null references auth.users(id) on delete restrict,
    status public.submission_status not null default 'submitted',
    rejection_reason text,
    reviewed_by uuid references auth.users(id) on delete restrict,
    reviewed_at timestamptz,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create unique index if not exists task_submissions_one_pending_per_assignment_idx
    on public.task_submissions (assignment_id)
    where status = 'submitted';

create index if not exists task_submissions_child_id_idx on public.task_submissions (child_id);

create table if not exists public.task_submission_images (
    id uuid primary key default gen_random_uuid(),
    household_id uuid not null references public.households(id) on delete cascade,
    submission_id uuid not null unique references public.task_submissions(id) on delete cascade,
    child_id uuid not null references public.children(id) on delete cascade,
    storage_path text not null unique,
    uploaded_by uuid not null references auth.users(id) on delete restrict,
    created_at timestamptz not null default now()
);

create table if not exists public.points_ledger (
    id uuid primary key default gen_random_uuid(),
    household_id uuid not null references public.households(id) on delete cascade,
    child_id uuid not null references public.children(id) on delete cascade,
    task_id uuid not null references public.tasks(id) on delete restrict,
    submission_id uuid not null unique references public.task_submissions(id) on delete restrict,
    amount integer not null check (amount > 0),
    reason public.ledger_reason not null,
    created_by uuid not null references auth.users(id) on delete restrict,
    created_at timestamptz not null default now()
);

create index if not exists points_ledger_child_id_idx on public.points_ledger (child_id);

create or replace view public.child_points_balances
with (security_invoker = true) as
select
    c.id as child_id,
    c.household_id,
    coalesce(sum(pl.amount), 0)::integer as points,
    max(pl.created_at) as last_earned_at
from public.children c
left join public.points_ledger pl on pl.child_id = c.id
group by c.id, c.household_id;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

drop trigger if exists households_set_updated_at on public.households;
create trigger households_set_updated_at
before update on public.households
for each row execute function public.set_updated_at();

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

drop trigger if exists children_set_updated_at on public.children;
create trigger children_set_updated_at
before update on public.children
for each row execute function public.set_updated_at();

drop trigger if exists tasks_set_updated_at on public.tasks;
create trigger tasks_set_updated_at
before update on public.tasks
for each row execute function public.set_updated_at();

drop trigger if exists task_submissions_set_updated_at on public.task_submissions;
create trigger task_submissions_set_updated_at
before update on public.task_submissions
for each row execute function public.set_updated_at();

create or replace function public.is_anonymous_auth_user()
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
    select coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false);
$$;

create or replace function public.current_profile_id()
returns uuid
language sql
stable
security definer
set search_path = public, auth
as $$
    select auth.uid();
$$;

create or replace function public.current_household_id()
returns uuid
language sql
stable
security definer
set search_path = public, auth
as $$
    select p.household_id
    from public.profiles p
    where p.id = auth.uid()
    limit 1;
$$;

create or replace function public.is_parent()
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
    select exists (
        select 1
        from public.profiles p
        where p.id = auth.uid()
          and p.role = 'parent'
    );
$$;

create or replace function public.current_child_id()
returns uuid
language sql
stable
security definer
set search_path = public, auth
as $$
    select c.id
    from public.children c
    where c.auth_user_id = auth.uid()
    limit 1;
$$;

create or replace function public.path_household_id(path text)
returns uuid
language sql
immutable
as $$
    select case
        when split_part(path, '/', 1) ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
            then split_part(path, '/', 1)::uuid
        else null
    end;
$$;

create or replace function public.path_child_id(path text)
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

create or replace function public.generate_household_login_code()
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
    generated_code text;
begin
    loop
        generated_code := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));
        exit when not exists (
            select 1
            from public.households h
            where h.login_code = generated_code
        );
    end loop;

    return generated_code;
end;
$$;

create or replace function public.bootstrap_parent(
    p_display_name text,
    p_household_name text
)
returns public.profiles
language plpgsql
security definer
set search_path = public, auth
as $$
declare
    current_user_id uuid := auth.uid();
    created_household_id uuid;
    profile_row public.profiles;
begin
    if current_user_id is null then
        raise exception 'Authentication required';
    end if;

    if public.is_anonymous_auth_user() then
        raise exception 'Anonymous users cannot bootstrap parent households';
    end if;

    select *
    into profile_row
    from public.profiles p
    where p.id = current_user_id;

    if found then
        return profile_row;
    end if;

    insert into public.households (name, login_code, created_by)
    values (trim(p_household_name), public.generate_household_login_code(), current_user_id)
    returning id into created_household_id;

    insert into public.profiles (id, household_id, role, display_name)
    values (current_user_id, created_household_id, 'parent', trim(p_display_name))
    returning * into profile_row;

    return profile_row;
end;
$$;

create or replace function public.create_child(
    p_display_name text,
    p_login_name text,
    p_pin text
)
returns public.children
language plpgsql
security definer
set search_path = public, auth, extensions
as $$
declare
    parent_user_id uuid := auth.uid();
    parent_household_id uuid := public.current_household_id();
    child_row public.children;
    normalized_login text := lower(trim(p_login_name));
begin
    if parent_user_id is null or not public.is_parent() then
        raise exception 'Parent authentication required';
    end if;

    if char_length(trim(p_display_name)) = 0 then
        raise exception 'Child display name is required';
    end if;

    if char_length(normalized_login) = 0 then
        raise exception 'Child login name is required';
    end if;

    if char_length(p_pin) < 4 then
        raise exception 'PIN must contain at least 4 characters';
    end if;

    insert into public.children (
        household_id,
        display_name,
        login_name,
        pin_hash,
        created_by
    )
    values (
        parent_household_id,
        trim(p_display_name),
        normalized_login,
        extensions.crypt(p_pin, extensions.gen_salt('bf')),
        parent_user_id
    )
    returning * into child_row;

    return child_row;
end;
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

    if child_row.auth_user_id is not null and child_row.auth_user_id <> current_user_id then
        raise exception 'Child is already linked to another session';
    end if;

    update public.children
    set auth_user_id = current_user_id
    where id = child_row.id
    returning * into child_row;

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

create or replace function public.create_assigned_task(
    p_child_id uuid,
    p_title text,
    p_description text,
    p_point_value integer
)
returns public.task_assignments
language plpgsql
security definer
set search_path = public, auth
as $$
declare
    parent_user_id uuid := auth.uid();
    parent_household_id uuid := public.current_household_id();
    task_row public.tasks;
    assignment_row public.task_assignments;
begin
    if parent_user_id is null or not public.is_parent() then
        raise exception 'Parent authentication required';
    end if;

    if not exists (
        select 1
        from public.children c
        where c.id = p_child_id
          and c.household_id = parent_household_id
    ) then
        raise exception 'Child does not belong to this household';
    end if;

    insert into public.tasks (
        household_id,
        created_by,
        title,
        description,
        point_value,
        status
    )
    values (
        parent_household_id,
        parent_user_id,
        trim(p_title),
        nullif(trim(p_description), ''),
        p_point_value,
        'assigned'
    )
    returning * into task_row;

    insert into public.task_assignments (
        household_id,
        task_id,
        child_id,
        assigned_by
    )
    values (
        parent_household_id,
        task_row.id,
        p_child_id,
        parent_user_id
    )
    returning * into assignment_row;

    return assignment_row;
end;
$$;

create or replace function public.submit_task_completion(
    p_assignment_id uuid,
    p_storage_path text,
    p_submission_id uuid default gen_random_uuid()
)
returns public.task_submissions
language plpgsql
security definer
set search_path = public, auth
as $$
declare
    current_user_id uuid := auth.uid();
    claimed_child_id uuid := public.current_child_id();
    assignment_row public.task_assignments;
    task_row public.tasks;
    submission_row public.task_submissions;
begin
    if current_user_id is null or claimed_child_id is null then
        raise exception 'Child authentication required';
    end if;

    select *
    into assignment_row
    from public.task_assignments ta
    where ta.id = p_assignment_id
      and ta.child_id = claimed_child_id;

    if not found then
        raise exception 'Task assignment not found';
    end if;

    select *
    into task_row
    from public.tasks t
    where t.id = assignment_row.task_id
    for update;

    if task_row.status not in ('assigned', 'rejected') then
        raise exception 'Task is not available for submission';
    end if;

    if public.path_household_id(p_storage_path) <> assignment_row.household_id
       or public.path_child_id(p_storage_path) <> claimed_child_id then
        raise exception 'Storage path does not match the child task scope';
    end if;

    insert into public.task_submissions (
        id,
        household_id,
        assignment_id,
        child_id,
        submitted_by,
        status
    )
    values (
        p_submission_id,
        assignment_row.household_id,
        assignment_row.id,
        claimed_child_id,
        current_user_id,
        'submitted'
    )
    returning * into submission_row;

    insert into public.task_submission_images (
        household_id,
        submission_id,
        child_id,
        storage_path,
        uploaded_by
    )
    values (
        assignment_row.household_id,
        submission_row.id,
        claimed_child_id,
        p_storage_path,
        current_user_id
    );

    update public.tasks
    set status = 'submitted'
    where id = task_row.id;

    return submission_row;
end;
$$;

create or replace function public.review_task_submission(
    p_submission_id uuid,
    p_decision public.submission_status,
    p_rejection_reason text default null
)
returns public.task_submissions
language plpgsql
security definer
set search_path = public, auth
as $$
declare
    parent_user_id uuid := auth.uid();
    parent_household_id uuid := public.current_household_id();
    submission_row public.task_submissions;
    task_row public.tasks;
begin
    if parent_user_id is null or not public.is_parent() then
        raise exception 'Parent authentication required';
    end if;

    if p_decision not in ('approved', 'rejected') then
        raise exception 'Decision must be approved or rejected';
    end if;

    select *
    into submission_row
    from public.task_submissions ts
    where ts.id = p_submission_id
      and ts.household_id = parent_household_id
    for update;

    if not found then
        raise exception 'Submission not found';
    end if;

    if submission_row.status <> 'submitted' then
        raise exception 'Submission has already been reviewed';
    end if;

    select t.*
    into task_row
    from public.tasks t
    join public.task_assignments ta on ta.task_id = t.id
    where ta.id = submission_row.assignment_id
    for update;

    if p_decision = 'approved' then
        update public.task_submissions
        set status = 'approved',
            rejection_reason = null,
            reviewed_by = parent_user_id,
            reviewed_at = now()
        where id = submission_row.id
        returning * into submission_row;

        update public.tasks
        set status = 'completed'
        where id = task_row.id;

        insert into public.points_ledger (
            household_id,
            child_id,
            task_id,
            submission_id,
            amount,
            reason,
            created_by
        )
        values (
            submission_row.household_id,
            submission_row.child_id,
            task_row.id,
            submission_row.id,
            task_row.point_value,
            'task_approved',
            parent_user_id
        )
        on conflict (submission_id) do nothing;
    else
        update public.task_submissions
        set status = 'rejected',
            rejection_reason = nullif(trim(p_rejection_reason), ''),
            reviewed_by = parent_user_id,
            reviewed_at = now()
        where id = submission_row.id
        returning * into submission_row;

        update public.tasks
        set status = 'rejected'
        where id = task_row.id;
    end if;

    return submission_row;
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
    'task-photos',
    'task-photos',
    false,
    52428800,
    array['image/jpeg', 'image/png', 'image/heic', 'image/heif', 'image/webp']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

alter table public.households enable row level security;
alter table public.profiles enable row level security;
alter table public.children enable row level security;
alter table public.tasks enable row level security;
alter table public.task_assignments enable row level security;
alter table public.task_submissions enable row level security;
alter table public.task_submission_images enable row level security;
alter table public.points_ledger enable row level security;

drop policy if exists "Households are visible to members" on public.households;
create policy "Households are visible to members"
on public.households
for select
to authenticated
using (id = public.current_household_id());

drop policy if exists "Parents can update own household" on public.households;
create policy "Parents can update own household"
on public.households
for update
to authenticated
using (id = public.current_household_id() and public.is_parent())
with check (id = public.current_household_id() and public.is_parent());

drop policy if exists "Profiles are visible to household members" on public.profiles;
create policy "Profiles are visible to household members"
on public.profiles
for select
to authenticated
using (
    (household_id = public.current_household_id() and public.is_parent())
    or id = auth.uid()
);

drop policy if exists "Users can update their profile" on public.profiles;
create policy "Users can update their profile"
on public.profiles
for update
to authenticated
using (id = auth.uid())
with check (id = auth.uid() and household_id = public.current_household_id());

drop policy if exists "Children visible to household parent or self" on public.children;
create policy "Children visible to household parent or self"
on public.children
for select
to authenticated
using (
    (household_id = public.current_household_id() and public.is_parent())
    or auth_user_id = auth.uid()
);

drop policy if exists "Parents can maintain household children" on public.children;
create policy "Parents can maintain household children"
on public.children
for update
to authenticated
using (household_id = public.current_household_id() and public.is_parent())
with check (household_id = public.current_household_id() and public.is_parent());

drop policy if exists "Tasks visible to parent household or assigned child" on public.tasks;
create policy "Tasks visible to parent household or assigned child"
on public.tasks
for select
to authenticated
using (
    (household_id = public.current_household_id() and public.is_parent())
    or exists (
        select 1
        from public.task_assignments ta
        where ta.task_id = tasks.id
          and ta.child_id = public.current_child_id()
    )
);

drop policy if exists "Parents can update household tasks" on public.tasks;
create policy "Parents can update household tasks"
on public.tasks
for update
to authenticated
using (household_id = public.current_household_id() and public.is_parent())
with check (household_id = public.current_household_id() and public.is_parent());

drop policy if exists "Assignments visible to parent household or assigned child" on public.task_assignments;
create policy "Assignments visible to parent household or assigned child"
on public.task_assignments
for select
to authenticated
using (
    (household_id = public.current_household_id() and public.is_parent())
    or child_id = public.current_child_id()
);

drop policy if exists "Submissions visible to parent household or submitting child" on public.task_submissions;
create policy "Submissions visible to parent household or submitting child"
on public.task_submissions
for select
to authenticated
using (
    (household_id = public.current_household_id() and public.is_parent())
    or child_id = public.current_child_id()
);

drop policy if exists "Images visible to parent household or submitting child" on public.task_submission_images;
create policy "Images visible to parent household or submitting child"
on public.task_submission_images
for select
to authenticated
using (
    (household_id = public.current_household_id() and public.is_parent())
    or child_id = public.current_child_id()
);

drop policy if exists "Points visible to parent household or rewarded child" on public.points_ledger;
create policy "Points visible to parent household or rewarded child"
on public.points_ledger
for select
to authenticated
using (
    (household_id = public.current_household_id() and public.is_parent())
    or child_id = public.current_child_id()
);

drop policy if exists "Balances visible to parent household or child" on public.children;
-- Balance visibility is handled by the child_points_balances view through underlying child and ledger policies.

drop policy if exists "Task photo objects visible to scoped household members" on storage.objects;
create policy "Task photo objects visible to scoped household members"
on storage.objects
for select
to authenticated
using (
    bucket_id = 'task-photos'
    and (
        (public.is_parent() and public.path_household_id(name) = public.current_household_id())
        or (
            public.path_household_id(name) = public.current_household_id()
            and public.path_child_id(name) = public.current_child_id()
        )
    )
);

drop policy if exists "Children can upload own task photos" on storage.objects;
create policy "Children can upload own task photos"
on storage.objects
for insert
to authenticated
with check (
    bucket_id = 'task-photos'
    and public.path_household_id(name) = public.current_household_id()
    and public.path_child_id(name) = public.current_child_id()
);

grant usage on schema public to authenticated;
grant select on
    public.households,
    public.profiles,
    public.children,
    public.tasks,
    public.task_assignments,
    public.task_submissions,
    public.task_submission_images,
    public.points_ledger,
    public.child_points_balances
to authenticated;

grant update on
    public.households,
    public.profiles,
    public.children,
    public.tasks
to authenticated;

grant execute on function public.bootstrap_parent(text, text) to authenticated;
grant execute on function public.create_child(text, text, text) to authenticated;
grant execute on function public.claim_child_session(text, text, text) to authenticated;
grant execute on function public.create_assigned_task(uuid, text, text, integer) to authenticated;
grant execute on function public.submit_task_completion(uuid, text, uuid) to authenticated;
grant execute on function public.review_task_submission(uuid, public.submission_status, text) to authenticated;
grant execute on function public.current_household_id() to authenticated;
grant execute on function public.current_child_id() to authenticated;
grant execute on function public.is_parent() to authenticated;
