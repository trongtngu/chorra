create or replace function public.normalize_chorra_icon_name(p_icon_name text)
returns text
language sql
immutable
as $$
    select case
        when trim(coalesce(p_icon_name, '')) in (
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
        ) then trim(p_icon_name)
        else 'Icon_Star'
    end;
$$;

alter table public.tasks
    add column if not exists icon_name text;

update public.tasks
set icon_name = public.normalize_chorra_icon_name(icon_name);

alter table public.tasks
    alter column icon_name set default 'Icon_Star',
    alter column icon_name set not null,
    drop constraint if exists tasks_icon_name_check,
    add constraint tasks_icon_name_check check (
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

alter table public.rewards
    add column if not exists icon_name text;

update public.rewards
set icon_name = public.normalize_chorra_icon_name(icon_name);

alter table public.rewards
    alter column icon_name set default 'Icon_Star',
    alter column icon_name set not null,
    drop constraint if exists rewards_icon_name_check,
    add constraint rewards_icon_name_check check (
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

alter table public.reward_redemptions
    add column if not exists reward_icon_name text;

update public.reward_redemptions
set reward_icon_name = public.normalize_chorra_icon_name(reward_icon_name);

alter table public.reward_redemptions
    alter column reward_icon_name set default 'Icon_Star',
    alter column reward_icon_name set not null,
    alter column reward_emoji set default '🎁',
    drop constraint if exists reward_redemptions_reward_icon_name_check,
    add constraint reward_redemptions_reward_icon_name_check check (
        reward_icon_name in (
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

drop function if exists public.create_assigned_task(uuid, text, text, integer);
drop function if exists public.create_assigned_task(uuid, text, text, integer, text);
drop function if exists public.create_assigned_task(uuid, text, text, integer, text, text);

create or replace function public.create_assigned_task(
    p_child_id uuid,
    p_title text,
    p_description text,
    p_point_value integer,
    p_card_color_hex text default '#FFD5F5',
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
    task_row public.tasks;
    assignment_row public.task_assignments;
    normalized_card_color_hex text := upper(trim(coalesce(p_card_color_hex, '#FFD5F5')));
    normalized_icon_name text := public.normalize_chorra_icon_name(p_icon_name);
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
        card_color_hex,
        icon_name
    )
    values (
        parent_household_id,
        parent_user_id,
        trim(p_title),
        nullif(trim(p_description), ''),
        p_point_value,
        'assigned',
        normalized_card_color_hex,
        normalized_icon_name
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
    p_icon_name text,
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
    normalized_icon_name text := public.normalize_chorra_icon_name(p_icon_name);
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
        icon_name,
        point_cost,
        card_color_hex
    )
    values (
        p_reward_id,
        parent_household_id,
        parent_user_id,
        trim(p_name),
        '🎁',
        normalized_icon_name,
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
    p_icon_name text,
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
    normalized_icon_name text := public.normalize_chorra_icon_name(p_icon_name);
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
        icon_name = normalized_icon_name,
        point_cost = p_point_cost,
        card_color_hex = normalized_card_color_hex
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
        reward_icon_name,
        reward_point_cost
    )
    values (
        child_row.household_id,
        child_row.id,
        reward_row.id,
        current_user_id,
        reward_row.name,
        '🎁',
        reward_row.icon_name,
        reward_row.point_cost
    )
    returning * into redemption_row;

    return redemption_row;
end;
$$;

grant execute on function public.normalize_chorra_icon_name(text) to authenticated;
grant execute on function public.create_assigned_task(uuid, text, text, integer, text, text) to authenticated;
grant execute on function public.create_reward(text, text, integer, text, uuid) to authenticated;
grant execute on function public.update_reward(uuid, text, text, integer, text) to authenticated;
grant execute on function public.redeem_reward(uuid) to authenticated;
