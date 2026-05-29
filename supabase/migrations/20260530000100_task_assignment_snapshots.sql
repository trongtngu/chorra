drop function if exists public.create_assigned_task(uuid, text, text, integer);
drop function if exists public.create_assigned_task(uuid, text, text, integer, text);
drop function if exists public.create_assigned_task(uuid, text, text, integer, text, text);

alter table public.task_assignments
    add column if not exists title text,
    add column if not exists point_value integer,
    add column if not exists card_color_hex text,
    add column if not exists icon_name text,
    add column if not exists status public.task_status;

update public.task_assignments ta
set title = coalesce(nullif(trim(ta.title), ''), t.title),
    point_value = coalesce(ta.point_value, t.point_value),
    card_color_hex = coalesce(
        nullif(upper(trim(ta.card_color_hex)), ''),
        t.card_color_hex,
        '#C7E4F4'
    ),
    icon_name = public.normalize_chorra_icon_name(coalesce(ta.icon_name, t.icon_name)),
    status = coalesce(ta.status, t.status, 'assigned')
from public.tasks t
where ta.task_id = t.id;

alter table public.task_assignments
    alter column title set not null,
    alter column point_value set not null,
    alter column card_color_hex set default '#C7E4F4',
    alter column card_color_hex set not null,
    alter column icon_name set default 'Icon_Star',
    alter column icon_name set not null,
    alter column status set default 'assigned',
    alter column status set not null,
    drop constraint if exists task_assignments_task_id_key,
    drop constraint if exists task_assignments_title_check,
    drop constraint if exists task_assignments_point_value_check,
    drop constraint if exists task_assignments_card_color_hex_check,
    drop constraint if exists task_assignments_icon_name_check,
    add constraint task_assignments_title_check check (char_length(trim(title)) between 1 and 160),
    add constraint task_assignments_point_value_check check (point_value > 0 and point_value <= 100000),
    add constraint task_assignments_card_color_hex_check check (
        card_color_hex in (
            '#FFD5F5',
            '#FFDFBD',
            '#FFEC7F',
            '#D7F5B3',
            '#C7E4F4',
            '#BBF2E8',
            '#E5D5FB'
        )
    ),
    add constraint task_assignments_icon_name_check check (
        icon_name in (
            'Icon_Star',
            'Icon_Camera',
            'Icon_Cart',
            'Icon_Crown',
            'Icon_Diamond',
            'Icon_FLag',
            'Icon_Film',
            'Icon_Flower',
            'Icon_Food',
            'Icon_Fork',
            'Icon_Ghost',
            'Icon_Globe',
            'Icon_Hanger',
            'Icon_Heart',
            'Icon_Image',
            'Icon_Key',
            'Icon_Lightning',
            'Icon_Magic',
            'Icon_Plant',
            'Icon_Sun'
        )
    );

create index if not exists task_assignments_task_id_idx
    on public.task_assignments (task_id);

create index if not exists task_assignments_child_status_idx
    on public.task_assignments (child_id, status);

alter table public.points_ledger
    add column if not exists assignment_id uuid;

update public.points_ledger pl
set assignment_id = ts.assignment_id
from public.task_submissions ts
where pl.submission_id = ts.id
  and pl.assignment_id is null;

do $$
begin
    if not exists (
        select 1
        from pg_constraint
        where conname = 'points_ledger_assignment_id_fkey'
          and conrelid = 'public.points_ledger'::regclass
    ) then
        alter table public.points_ledger
            add constraint points_ledger_assignment_id_fkey
            foreign key (assignment_id)
            references public.task_assignments(id)
            on delete restrict;
    end if;
end $$;

alter table public.points_ledger
    alter column assignment_id set not null;

create index if not exists points_ledger_assignment_id_idx
    on public.points_ledger (assignment_id);

create or replace function public.create_task(
    p_title text,
    p_point_value integer,
    p_card_color_hex text default '#C7E4F4',
    p_icon_name text default 'Icon_Star',
    p_task_id uuid default gen_random_uuid()
)
returns public.tasks
language plpgsql
security definer
set search_path = public, auth
as $$
declare
    parent_user_id uuid := auth.uid();
    parent_household_id uuid := public.current_household_id();
    task_row public.tasks;
    normalized_card_color_hex text := upper(trim(coalesce(p_card_color_hex, '#C7E4F4')));
    normalized_icon_name text := public.normalize_chorra_icon_name(p_icon_name);
begin
    if parent_user_id is null or not public.is_parent() then
        raise exception 'Parent authentication required';
    end if;

    if p_title is null or char_length(trim(p_title)) = 0 then
        raise exception 'Task title is required';
    end if;

    if p_point_value is null or p_point_value <= 0 then
        raise exception 'Task point value must be positive';
    end if;

    if normalized_card_color_hex not in (
        '#FFD5F5',
        '#FFDFBD',
        '#FFEC7F',
        '#D7F5B3',
        '#C7E4F4',
        '#BBF2E8',
        '#E5D5FB'
    ) then
        raise exception 'Task card colour must use an allowed palette colour';
    end if;

    insert into public.tasks (
        id,
        household_id,
        created_by,
        title,
        point_value,
        card_color_hex,
        icon_name
    )
    values (
        p_task_id,
        parent_household_id,
        parent_user_id,
        trim(p_title),
        p_point_value,
        normalized_card_color_hex,
        normalized_icon_name
    )
    returning * into task_row;

    return task_row;
end;
$$;

create or replace function public.assign_task(
    p_task_id uuid,
    p_child_id uuid
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

    select *
    into task_row
    from public.tasks t
    where t.id = p_task_id
      and t.household_id = parent_household_id;

    if not found then
        raise exception 'Task not found';
    end if;

    if not exists (
        select 1
        from public.children c
        where c.id = p_child_id
          and c.household_id = parent_household_id
    ) then
        raise exception 'Child does not belong to this household';
    end if;

    insert into public.task_assignments (
        household_id,
        task_id,
        child_id,
        assigned_by,
        title,
        point_value,
        card_color_hex,
        icon_name,
        status
    )
    values (
        parent_household_id,
        task_row.id,
        p_child_id,
        parent_user_id,
        task_row.title,
        task_row.point_value,
        task_row.card_color_hex,
        task_row.icon_name,
        'assigned'
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
    submission_row public.task_submissions;
begin
    if current_user_id is null or claimed_child_id is null then
        raise exception 'Child authentication required';
    end if;

    select *
    into assignment_row
    from public.task_assignments ta
    where ta.id = p_assignment_id
      and ta.child_id = claimed_child_id
    for update;

    if not found then
        raise exception 'Task assignment not found';
    end if;

    if assignment_row.status not in ('assigned', 'rejected') then
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

    update public.task_assignments
    set status = 'submitted'
    where id = assignment_row.id;

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
    assignment_row public.task_assignments;
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

    select *
    into assignment_row
    from public.task_assignments ta
    where ta.id = submission_row.assignment_id
      and ta.household_id = parent_household_id
    for update;

    if not found then
        raise exception 'Task assignment not found';
    end if;

    if p_decision = 'approved' then
        update public.task_submissions
        set status = 'approved',
            rejection_reason = null,
            reviewed_by = parent_user_id,
            reviewed_at = now()
        where id = submission_row.id
        returning * into submission_row;

        update public.task_assignments
        set status = 'completed'
        where id = assignment_row.id;

        insert into public.points_ledger (
            household_id,
            child_id,
            task_id,
            assignment_id,
            submission_id,
            amount,
            reason,
            created_by
        )
        values (
            submission_row.household_id,
            submission_row.child_id,
            assignment_row.task_id,
            assignment_row.id,
            submission_row.id,
            assignment_row.point_value,
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

        update public.task_assignments
        set status = 'rejected'
        where id = assignment_row.id;
    end if;

    return submission_row;
end;
$$;

drop policy if exists "Tasks visible to parent household or assigned child" on public.tasks;
drop policy if exists "Parents can view household tasks" on public.tasks;
create policy "Parents can view household tasks"
on public.tasks
for select
to authenticated
using (household_id = public.current_household_id() and public.is_parent());

alter table public.tasks
    drop column if exists description,
    drop column if exists status;

grant execute on function public.create_task(text, integer, text, text, uuid) to authenticated;
grant execute on function public.assign_task(uuid, uuid) to authenticated;
