create or replace function public.join_parent_household(
    p_display_name text,
    p_household_code text
)
returns public.profiles
language plpgsql
security definer
set search_path = public, auth
as $$
declare
    current_user_id uuid := auth.uid();
    household_row public.households;
    profile_row public.profiles;
begin
    if current_user_id is null then
        raise exception 'Authentication required';
    end if;

    if public.is_anonymous_auth_user() then
        raise exception 'Anonymous users cannot join parent households';
    end if;

    if p_display_name is null or char_length(trim(p_display_name)) = 0 then
        raise exception 'Display name is required';
    end if;

    if p_household_code is null or char_length(trim(p_household_code)) = 0 then
        raise exception 'Home code is required';
    end if;

    select *
    into household_row
    from public.households h
    where h.login_code = upper(trim(p_household_code))
    limit 1;

    if not found then
        raise exception 'Invalid home code';
    end if;

    select *
    into profile_row
    from public.profiles p
    where p.id = current_user_id;

    if found then
        if profile_row.role <> 'parent' then
            raise exception 'Child accounts cannot join as parents';
        end if;

        if profile_row.household_id <> household_row.id then
            raise exception 'Parent account is already linked to another household';
        end if;

        update public.profiles
        set display_name = trim(p_display_name)
        where id = current_user_id
        returning * into profile_row;

        return profile_row;
    end if;

    insert into public.profiles (id, household_id, role, display_name)
    values (current_user_id, household_row.id, 'parent', trim(p_display_name))
    returning * into profile_row;

    return profile_row;
end;
$$;

grant execute on function public.join_parent_household(text, text) to authenticated;
