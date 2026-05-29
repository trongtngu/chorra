alter table public.tasks
    add column if not exists is_archived boolean not null default false;

create index if not exists tasks_household_active_idx
    on public.tasks (household_id, is_archived, created_at desc);

create or replace function public.update_task(
    p_task_id uuid,
    p_title text,
    p_point_value integer,
    p_card_color_hex text default '#C7E4F4',
    p_icon_name text default 'Icon_Star'
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

    update public.tasks
    set title = trim(p_title),
        point_value = p_point_value,
        card_color_hex = normalized_card_color_hex,
        icon_name = normalized_icon_name
    where id = p_task_id
      and household_id = parent_household_id
      and not is_archived
    returning * into task_row;

    if not found then
        raise exception 'Task not found';
    end if;

    return task_row;
end;
$$;

create or replace function public.archive_task(p_task_id uuid)
returns public.tasks
language plpgsql
security definer
set search_path = public, auth
as $$
declare
    parent_user_id uuid := auth.uid();
    parent_household_id uuid := public.current_household_id();
    task_row public.tasks;
begin
    if parent_user_id is null or not public.is_parent() then
        raise exception 'Parent authentication required';
    end if;

    update public.tasks
    set is_archived = true
    where id = p_task_id
      and household_id = parent_household_id
      and not is_archived
    returning * into task_row;

    if not found then
        raise exception 'Task not found';
    end if;

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
      and t.household_id = parent_household_id
      and not t.is_archived;

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

grant execute on function public.update_task(uuid, text, integer, text, text) to authenticated;
grant execute on function public.archive_task(uuid) to authenticated;
grant execute on function public.assign_task(uuid, uuid) to authenticated;
