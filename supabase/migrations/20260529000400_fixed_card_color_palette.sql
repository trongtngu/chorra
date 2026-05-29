update public.tasks
set card_color_hex = upper(trim(card_color_hex))
where card_color_hex is not null;

update public.tasks
set card_color_hex = '#FFD5F5'
where card_color_hex is null
   or card_color_hex not in (
       '#FFD5F5',
       '#FFDFBD',
       '#FFEC7F',
       '#D7F5B3',
       '#C7E4F4',
       '#BBF2E8',
       '#E5D5FB'
   );

alter table public.tasks
    alter column card_color_hex set default '#FFD5F5',
    alter column card_color_hex set not null,
    drop constraint if exists tasks_card_color_hex_check,
    add constraint tasks_card_color_hex_check check (
        card_color_hex in (
            '#FFD5F5',
            '#FFDFBD',
            '#FFEC7F',
            '#D7F5B3',
            '#C7E4F4',
            '#BBF2E8',
            '#E5D5FB'
        )
    );

alter table public.rewards
    add column if not exists card_color_hex text;

update public.rewards
set card_color_hex = upper(trim(card_color_hex))
where card_color_hex is not null;

update public.rewards
set card_color_hex = '#FFD5F5'
where card_color_hex is null
   or card_color_hex not in (
       '#FFD5F5',
       '#FFDFBD',
       '#FFEC7F',
       '#D7F5B3',
       '#C7E4F4',
       '#BBF2E8',
       '#E5D5FB'
   );

alter table public.rewards
    alter column card_color_hex set default '#FFD5F5',
    alter column card_color_hex set not null,
    drop constraint if exists rewards_card_color_hex_check,
    add constraint rewards_card_color_hex_check check (
        card_color_hex in (
            '#FFD5F5',
            '#FFDFBD',
            '#FFEC7F',
            '#D7F5B3',
            '#C7E4F4',
            '#BBF2E8',
            '#E5D5FB'
        )
    );

drop function if exists public.create_assigned_task(uuid, text, text, integer, text);

create or replace function public.create_assigned_task(
    p_child_id uuid,
    p_title text,
    p_description text,
    p_point_value integer,
    p_card_color_hex text default '#FFD5F5'
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
    normalized_card_color_hex text := upper(trim(coalesce(p_card_color_hex, '#FFD5F5')));
begin
    if parent_user_id is null or not public.is_parent() then
        raise exception 'Parent authentication required';
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

drop function if exists public.create_reward(text, text, integer, uuid);
drop function if exists public.create_reward(text, text, integer, text, uuid);

create or replace function public.create_reward(
    p_name text,
    p_emoji text,
    p_point_cost integer,
    p_card_color_hex text default '#FFD5F5',
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
    normalized_card_color_hex text := upper(trim(coalesce(p_card_color_hex, '#FFD5F5')));
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

    if normalized_card_color_hex not in (
        '#FFD5F5',
        '#FFDFBD',
        '#FFEC7F',
        '#D7F5B3',
        '#C7E4F4',
        '#BBF2E8',
        '#E5D5FB'
    ) then
        raise exception 'Reward card colour must use an allowed palette colour';
    end if;

    insert into public.rewards (
        id,
        household_id,
        created_by,
        name,
        emoji,
        point_cost,
        card_color_hex
    )
    values (
        p_reward_id,
        parent_household_id,
        parent_user_id,
        trim(p_name),
        normalized_emoji,
        p_point_cost,
        normalized_card_color_hex
    )
    returning * into reward_row;

    return reward_row;
end;
$$;

drop function if exists public.update_reward(uuid, text, text, integer);
drop function if exists public.update_reward(uuid, text, text, integer, text);

create or replace function public.update_reward(
    p_reward_id uuid,
    p_name text,
    p_emoji text,
    p_point_cost integer,
    p_card_color_hex text default '#FFD5F5'
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
    normalized_card_color_hex text := upper(trim(coalesce(p_card_color_hex, '#FFD5F5')));
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

    if normalized_card_color_hex not in (
        '#FFD5F5',
        '#FFDFBD',
        '#FFEC7F',
        '#D7F5B3',
        '#C7E4F4',
        '#BBF2E8',
        '#E5D5FB'
    ) then
        raise exception 'Reward card colour must use an allowed palette colour';
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
        point_cost = p_point_cost,
        card_color_hex = normalized_card_color_hex
    where id = reward_row.id
    returning * into reward_row;

    return reward_row;
end;
$$;

grant execute on function public.create_assigned_task(uuid, text, text, integer, text) to authenticated;
grant execute on function public.create_reward(text, text, integer, text, uuid) to authenticated;
grant execute on function public.update_reward(uuid, text, text, integer, text) to authenticated;
