alter table public.reward_redemptions
    add column if not exists reward_card_color_hex text;

update public.reward_redemptions rr
set reward_card_color_hex = upper(trim(coalesce(rr.reward_card_color_hex, r.card_color_hex, '#C7E4F4')))
from public.rewards r
where rr.reward_id = r.id;

update public.reward_redemptions
set reward_card_color_hex = '#C7E4F4'
where reward_card_color_hex is null
   or reward_card_color_hex not in (
       '#FFD5F5',
       '#FFDFBD',
       '#FFEC7F',
       '#D7F5B3',
       '#C7E4F4',
       '#BBF2E8',
       '#E5D5FB'
   );

alter table public.reward_redemptions
    alter column reward_card_color_hex set default '#C7E4F4',
    alter column reward_card_color_hex set not null,
    drop constraint if exists reward_redemptions_reward_card_color_hex_check,
    add constraint reward_redemptions_reward_card_color_hex_check check (
        reward_card_color_hex in (
            '#FFD5F5',
            '#FFDFBD',
            '#FFEC7F',
            '#D7F5B3',
            '#C7E4F4',
            '#BBF2E8',
            '#E5D5FB'
        )
    );

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
        reward_icon_name,
        reward_point_cost,
        reward_card_color_hex
    )
    values (
        child_row.household_id,
        child_row.id,
        reward_row.id,
        current_user_id,
        reward_row.name,
        reward_row.icon_name,
        reward_row.point_cost,
        reward_row.card_color_hex
    )
    returning * into redemption_row;

    return redemption_row;
end;
$$;

grant execute on function public.redeem_reward(uuid) to authenticated;
