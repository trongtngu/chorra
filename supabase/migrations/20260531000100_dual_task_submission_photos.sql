do $$
begin
    create type public.task_submission_image_kind as enum ('task', 'face');
exception
    when duplicate_object then null;
end;
$$;

alter table public.task_submission_images
add column if not exists image_kind public.task_submission_image_kind not null default 'task';

alter table public.task_submission_images
drop constraint if exists task_submission_images_submission_id_key;

drop index if exists task_submission_images_submission_id_key;

create unique index if not exists task_submission_images_submission_kind_idx
on public.task_submission_images (submission_id, image_kind);

drop function if exists public.submit_task_completion(uuid, text, uuid);

create or replace function public.submit_task_completion(
    p_assignment_id uuid,
    p_task_storage_path text,
    p_face_storage_path text,
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

    if public.path_household_id(p_task_storage_path) <> assignment_row.household_id
       or public.path_child_id(p_task_storage_path) <> claimed_child_id
       or public.path_household_id(p_face_storage_path) <> assignment_row.household_id
       or public.path_child_id(p_face_storage_path) <> claimed_child_id then
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
        image_kind,
        uploaded_by
    )
    values
    (
        assignment_row.household_id,
        submission_row.id,
        claimed_child_id,
        p_task_storage_path,
        'task',
        current_user_id
    ),
    (
        assignment_row.household_id,
        submission_row.id,
        claimed_child_id,
        p_face_storage_path,
        'face',
        current_user_id
    );

    update public.task_assignments
    set status = 'submitted'
    where id = assignment_row.id;

    return submission_row;
end;
$$;

grant execute on function public.submit_task_completion(uuid, text, text, uuid) to authenticated;
