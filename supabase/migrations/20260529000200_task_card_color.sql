alter table public.tasks
    add column if not exists card_color_hex text;

update public.tasks
set card_color_hex = upper(trim(card_color_hex))
where card_color_hex is not null
  and trim(card_color_hex) ~ '^#[0-9A-Fa-f]{6}$';

update public.tasks
set card_color_hex = '#DFF7AF'
where card_color_hex is null
   or card_color_hex !~ '^#[0-9A-F]{6}$';

alter table public.tasks
    alter column card_color_hex set default '#DFF7AF',
    alter column card_color_hex set not null,
    drop constraint if exists tasks_card_color_hex_check,
    add constraint tasks_card_color_hex_check check (card_color_hex ~ '^#[0-9A-F]{6}$');

drop function if exists public.create_assigned_task(uuid, text, text, integer);

create or replace function public.create_assigned_task(
    p_child_id uuid,
    p_title text,
    p_description text,
    p_point_value integer,
    p_card_color_hex text default '#DFF7AF'
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
    normalized_card_color_hex text := upper(trim(coalesce(p_card_color_hex, '#DFF7AF')));
begin
    if parent_user_id is null or not public.is_parent() then
        raise exception 'Parent authentication required';
    end if;

    if normalized_card_color_hex !~ '^#[0-9A-F]{6}$' then
        raise exception 'Task card colour must be #RRGGBB hex';
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
        status,
        card_color_hex
    )
    values (
        parent_household_id,
        parent_user_id,
        trim(p_title),
        nullif(trim(p_description), ''),
        p_point_value,
        'assigned',
        normalized_card_color_hex
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

grant execute on function public.create_assigned_task(uuid, text, text, integer, text) to authenticated;
