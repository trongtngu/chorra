alter table public.task_assignments
    add column if not exists is_archived boolean not null default false;

create index if not exists task_assignments_household_active_idx
    on public.task_assignments (household_id, is_archived, assigned_at desc);

create or replace function public.update_task_assignment(
    p_assignment_id uuid,
    p_title text,
    p_point_value integer,
    p_card_color_hex text default '#C7E4F4',
    p_icon_name text default 'Icon_Star'
)
returns public.task_assignments
language plpgsql
security definer
set search_path = public, auth
as $$
declare
    parent_user_id uuid := auth.uid();
    parent_household_id uuid := public.current_household_id();
    assignment_row public.task_assignments;
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

    if p_point_value > 100000 then
        raise exception 'Task point value is too large';
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

    update public.task_assignments
    set title = trim(p_title),
        point_value = p_point_value,
        card_color_hex = normalized_card_color_hex,
        icon_name = normalized_icon_name
    where id = p_assignment_id
      and household_id = parent_household_id
      and status in ('assigned', 'rejected', 'submitted')
      and not is_archived
    returning * into assignment_row;

    if not found then
        raise exception 'Task assignment not found';
    end if;

    return assignment_row;
end;
$$;

create or replace function public.archive_task_assignment(p_assignment_id uuid)
returns public.task_assignments
language plpgsql
security definer
set search_path = public, auth
as $$
declare
    parent_user_id uuid := auth.uid();
    parent_household_id uuid := public.current_household_id();
    assignment_row public.task_assignments;
begin
    if parent_user_id is null or not public.is_parent() then
        raise exception 'Parent authentication required';
    end if;

    update public.task_assignments
    set is_archived = true
    where id = p_assignment_id
      and household_id = parent_household_id
      and status in ('assigned', 'rejected', 'submitted')
      and not is_archived
    returning * into assignment_row;

    if not found then
        raise exception 'Task assignment not found';
    end if;

    return assignment_row;
end;
$$;

grant execute on function public.update_task_assignment(uuid, text, integer, text, text) to authenticated;
grant execute on function public.archive_task_assignment(uuid) to authenticated;
