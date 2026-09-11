-- WS-3 / AC-P0-4.1–4.9, AC-P1-5, G1, G2, G6 / B2–B3
-- Gate A: Fail-closed email bind on accept*; strip invite_token/backup from preview; revoke PUBLIC+anon EXECUTE.
-- NEVER apply to production project bxiyosyhkbyvnbqgictr — local / non-prod only.
--
-- Rollback (non-prod): restore prior function bodies from live dump 2026-09-11
-- (sentinel-verification evidence / pg_get_functiondef). Do not re-grant anon/PUBLIC EXECUTE.

BEGIN;

-- ---------------------------------------------------------------------------
-- accept_household_invite(p_code): live body + email bind AFTER status/expiry,
-- BEFORE membership mutations. Empty invite email ≠ empty caller email.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.accept_household_invite(p_code text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_inv public.household_invites%rowtype;
  v_access text;
  v_existing public.household_memberships%rowtype;
  v_caller_email text;
begin
  if v_uid is null then
    return jsonb_build_object('outcome', 'not_authenticated');
  end if;

  select *
  into v_inv
  from public.household_invites
  where upper(trim(invite_code)) = upper(trim(p_code))
  order by created_at desc
  limit 1;

  if not found then
    return jsonb_build_object('outcome', 'invalid_code');
  end if;

  if lower(coalesce(v_inv.status, '')) = 'cancelled' then
    return jsonb_build_object('outcome', 'cancelled', 'household_id', v_inv.household_id);
  end if;

  if lower(coalesce(v_inv.status, '')) = 'declined' then
    return jsonb_build_object('outcome', 'declined', 'household_id', v_inv.household_id);
  end if;

  if lower(coalesce(v_inv.status, '')) = 'accepted' or v_inv.claimed_by_user_id is not null then
    return jsonb_build_object('outcome', 'already_used', 'household_id', v_inv.household_id);
  end if;

  if lower(coalesce(v_inv.status, '')) <> 'pending' then
    return jsonb_build_object('outcome', 'invalid_code', 'household_id', v_inv.household_id);
  end if;

  if v_inv.expires_at is not null and v_inv.expires_at <= now() then
    update public.household_invites
    set status = 'expired', updated_at = now()
    where id = v_inv.id;
    return jsonb_build_object('outcome', 'expired', 'household_id', v_inv.household_id);
  end if;

  -- B2 fail-closed email bind (AFTER status/expiry, BEFORE membership writes)
  if v_inv.email is null or length(trim(v_inv.email)) = 0 then
    return jsonb_build_object('outcome', 'email_required', 'household_id', v_inv.household_id);
  end if;

  v_caller_email := public.current_auth_email_lower();
  if length(trim(v_inv.email)) = 0
     or length(coalesce(v_caller_email, '')) = 0
     or lower(trim(v_inv.email)) <> v_caller_email then
    return jsonb_build_object('outcome', 'email_mismatch', 'household_id', v_inv.household_id);
  end if;

  v_access := lower(trim(coalesce(v_inv.access_role, 'observer')));
  if v_access not in ('organiser', 'driver', 'observer') then
    v_access := 'observer';
  end if;

  select *
  into v_existing
  from public.household_memberships hm
  where hm.household_id = v_inv.household_id
    and hm.user_id = v_uid
  order by hm.created_at desc
  limit 1;

  if found then
    if lower(coalesce(v_existing.status, 'active')) = 'active' then
      update public.household_invites
      set
        status = 'accepted',
        claimed_by_user_id = v_uid,
        claimed_at = coalesce(claimed_at, now()),
        updated_at = now()
      where id = v_inv.id
        and lower(coalesce(status, '')) = 'pending';

      return jsonb_build_object(
        'outcome', 'already_member',
        'household_id', v_inv.household_id,
        'household_name', (select name from public.households where id = v_inv.household_id)
      );
    elsif lower(coalesce(v_existing.status, '')) = 'pending' then
      update public.household_memberships
      set
        status = 'active',
        access_role = v_access,
        relationship_label = coalesce(nullif(trim(v_inv.relationship), ''), relationship_label),
        invited_by_user_id = coalesce(invited_by_user_id, v_inv.invited_by),
        updated_at = now()
      where id = v_existing.id;

      update public.household_invites
      set
        status = 'accepted',
        claimed_by_user_id = v_uid,
        claimed_at = now(),
        updated_at = now()
      where id = v_inv.id;

      return jsonb_build_object(
        'outcome', 'joined',
        'household_id', v_inv.household_id,
        'household_name', (select name from public.households where id = v_inv.household_id)
      );
    end if;
  end if;

  begin
    insert into public.household_memberships (
      household_id,
      user_id,
      role,
      status,
      access_role,
      relationship_label,
      invited_by_user_id,
      created_at,
      updated_at
    ) values (
      v_inv.household_id,
      v_uid,
      'member',
      'active',
      v_access,
      nullif(trim(v_inv.relationship), ''),
      v_inv.invited_by,
      now(),
      now()
    );
  exception
    when unique_violation then
      update public.household_invites
      set
        status = 'accepted',
        claimed_by_user_id = v_uid,
        claimed_at = coalesce(claimed_at, now()),
        updated_at = now()
      where id = v_inv.id;

      return jsonb_build_object(
        'outcome', 'already_member',
        'household_id', v_inv.household_id,
        'household_name', (select name from public.households where id = v_inv.household_id)
      );
  end;

  update public.household_invites
  set
    status = 'accepted',
    claimed_by_user_id = v_uid,
    claimed_at = now(),
    updated_at = now()
  where id = v_inv.id;

  return jsonb_build_object(
    'outcome', 'joined',
    'household_id', v_inv.household_id,
    'household_name', (select name from public.households where id = v_inv.household_id)
  );
end;
$function$;

-- ---------------------------------------------------------------------------
-- accept_household_invite_by_token: duplicate email bind before any write /
-- delegation so by_id→by_token path cannot skip bind when invite_code is empty.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.accept_household_invite_by_token(p_token text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_token uuid;
  v_inv public.household_invites%rowtype;
  v_code text;
  v_caller_email text;
  v_access text;
  v_existing public.household_memberships%rowtype;
begin
  if v_uid is null then
    return jsonb_build_object('outcome', 'not_authenticated');
  end if;

  begin
    v_token := trim(p_token)::uuid;
  exception
    when invalid_text_representation then
      return jsonb_build_object('outcome', 'invalid_code');
  end;

  select *
  into v_inv
  from public.household_invites
  where invite_token = v_token
  order by created_at desc
  limit 1;

  if not found then
    return jsonb_build_object('outcome', 'invalid_code');
  end if;

  -- Prefer funnel through code path (bind lives in accept_household_invite)
  v_code := trim(coalesce(v_inv.invite_code, ''));
  if v_code <> '' then
    return public.accept_household_invite(v_code);
  end if;

  -- No invite_code: duplicate status/expiry + email bind + membership logic inline
  if lower(coalesce(v_inv.status, '')) = 'cancelled' then
    return jsonb_build_object('outcome', 'cancelled', 'household_id', v_inv.household_id);
  end if;

  if lower(coalesce(v_inv.status, '')) = 'declined' then
    return jsonb_build_object('outcome', 'declined', 'household_id', v_inv.household_id);
  end if;

  if lower(coalesce(v_inv.status, '')) = 'accepted' or v_inv.claimed_by_user_id is not null then
    return jsonb_build_object('outcome', 'already_used', 'household_id', v_inv.household_id);
  end if;

  if lower(coalesce(v_inv.status, '')) <> 'pending' then
    return jsonb_build_object('outcome', 'invalid_code', 'household_id', v_inv.household_id);
  end if;

  if v_inv.expires_at is not null and v_inv.expires_at <= now() then
    update public.household_invites
    set status = 'expired', updated_at = now()
    where id = v_inv.id;
    return jsonb_build_object('outcome', 'expired', 'household_id', v_inv.household_id);
  end if;

  if v_inv.email is null or length(trim(v_inv.email)) = 0 then
    return jsonb_build_object('outcome', 'email_required', 'household_id', v_inv.household_id);
  end if;

  v_caller_email := public.current_auth_email_lower();
  if length(trim(v_inv.email)) = 0
     or length(coalesce(v_caller_email, '')) = 0
     or lower(trim(v_inv.email)) <> v_caller_email then
    return jsonb_build_object('outcome', 'email_mismatch', 'household_id', v_inv.household_id);
  end if;

  v_access := lower(trim(coalesce(v_inv.access_role, 'observer')));
  if v_access not in ('organiser', 'driver', 'observer') then
    v_access := 'observer';
  end if;

  select *
  into v_existing
  from public.household_memberships hm
  where hm.household_id = v_inv.household_id
    and hm.user_id = v_uid
  order by hm.created_at desc
  limit 1;

  if found then
    if lower(coalesce(v_existing.status, 'active')) = 'active' then
      update public.household_invites
      set
        status = 'accepted',
        claimed_by_user_id = v_uid,
        claimed_at = coalesce(claimed_at, now()),
        updated_at = now()
      where id = v_inv.id
        and lower(coalesce(status, '')) = 'pending';

      return jsonb_build_object(
        'outcome', 'already_member',
        'household_id', v_inv.household_id,
        'household_name', (select name from public.households where id = v_inv.household_id)
      );
    elsif lower(coalesce(v_existing.status, '')) = 'pending' then
      update public.household_memberships
      set
        status = 'active',
        access_role = v_access,
        relationship_label = coalesce(nullif(trim(v_inv.relationship), ''), relationship_label),
        invited_by_user_id = coalesce(invited_by_user_id, v_inv.invited_by),
        updated_at = now()
      where id = v_existing.id;

      update public.household_invites
      set
        status = 'accepted',
        claimed_by_user_id = v_uid,
        claimed_at = now(),
        updated_at = now()
      where id = v_inv.id;

      return jsonb_build_object(
        'outcome', 'joined',
        'household_id', v_inv.household_id,
        'household_name', (select name from public.households where id = v_inv.household_id)
      );
    end if;
  end if;

  begin
    insert into public.household_memberships (
      household_id, user_id, role, status, access_role,
      relationship_label, invited_by_user_id, created_at, updated_at
    ) values (
      v_inv.household_id, v_uid, 'member', 'active', v_access,
      nullif(trim(v_inv.relationship), ''), v_inv.invited_by, now(), now()
    );
  exception
    when unique_violation then
      update public.household_invites
      set
        status = 'accepted',
        claimed_by_user_id = v_uid,
        claimed_at = coalesce(claimed_at, now()),
        updated_at = now()
      where id = v_inv.id;

      return jsonb_build_object(
        'outcome', 'already_member',
        'household_id', v_inv.household_id,
        'household_name', (select name from public.households where id = v_inv.household_id)
      );
  end;

  update public.household_invites
  set
    status = 'accepted',
    claimed_by_user_id = v_uid,
    claimed_at = now(),
    updated_at = now()
  where id = v_inv.id;

  return jsonb_build_object(
    'outcome', 'joined',
    'household_id', v_inv.household_id,
    'household_name', (select name from public.households where id = v_inv.household_id)
  );
end;
$function$;

-- ---------------------------------------------------------------------------
-- accept_household_invite_by_id: duplicate bind before delegate so no path skips it.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.accept_household_invite_by_id(p_invite_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_inv public.household_invites%rowtype;
  v_code text;
  v_caller_email text;
begin
  if auth.uid() is null then
    return jsonb_build_object('outcome', 'not_authenticated');
  end if;

  select *
  into v_inv
  from public.household_invites
  where id = p_invite_id
  order by created_at desc
  limit 1;

  if not found then
    return jsonb_build_object('outcome', 'invalid_code');
  end if;

  -- Early fail-closed bind (also re-checked in accept / by_token)
  if v_inv.email is null or length(trim(v_inv.email)) = 0 then
    return jsonb_build_object('outcome', 'email_required', 'household_id', v_inv.household_id);
  end if;

  v_caller_email := public.current_auth_email_lower();
  if length(trim(v_inv.email)) = 0
     or length(coalesce(v_caller_email, '')) = 0
     or lower(trim(v_inv.email)) <> v_caller_email then
    return jsonb_build_object('outcome', 'email_mismatch', 'household_id', v_inv.household_id);
  end if;

  v_code := trim(coalesce(v_inv.invite_code, ''));
  if v_code <> '' then
    return public.accept_household_invite(v_code);
  end if;

  return public.accept_household_invite_by_token(v_inv.invite_token::text);
end;
$function$;

-- ---------------------------------------------------------------------------
-- Preview RPCs: keep column names for iOS compat; always NULL secrets.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_invite_by_code(p_code text)
 RETURNS TABLE(
   invite_id uuid,
   household_id uuid,
   household_name text,
   inviter_display_name text,
   access_role text,
   relationship text,
   status text,
   expires_at timestamp with time zone,
   invite_token text,
   backup_invite_code text
 )
 LANGUAGE sql
 STABLE
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select
    i.id,
    i.household_id,
    h.name,
    coalesce(nullif(trim(p.display_name), ''), nullif(trim(p.email), ''), 'Someone'),
    i.access_role,
    i.relationship,
    i.status,
    i.expires_at,
    NULL::text AS invite_token,
    NULL::text AS backup_invite_code
  from public.household_invites i
  join public.households h on h.id = i.household_id
  left join public.profiles p on p.id = i.invited_by
  where upper(trim(i.invite_code)) = upper(trim(p_code))
  order by i.created_at desc
  limit 1;
$function$;

CREATE OR REPLACE FUNCTION public.get_invite_by_id(p_invite_id uuid)
 RETURNS TABLE(
   invite_id uuid,
   household_id uuid,
   household_name text,
   inviter_display_name text,
   access_role text,
   relationship text,
   status text,
   expires_at timestamp with time zone,
   invite_token text,
   backup_invite_code text
 )
 LANGUAGE sql
 STABLE
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select
    i.id,
    i.household_id,
    h.name,
    coalesce(nullif(trim(p.display_name), ''), nullif(trim(p.email), ''), 'Someone'),
    i.access_role,
    i.relationship,
    i.status,
    i.expires_at,
    NULL::text AS invite_token,
    NULL::text AS backup_invite_code
  from public.household_invites i
  join public.households h on h.id = i.household_id
  left join public.profiles p on p.id = i.invited_by
  where i.id = p_invite_id
  limit 1;
$function$;

CREATE OR REPLACE FUNCTION public.get_invite_by_token(p_token text)
 RETURNS TABLE(
   invite_id uuid,
   household_id uuid,
   household_name text,
   inviter_display_name text,
   access_role text,
   relationship text,
   status text,
   expires_at timestamp with time zone,
   invite_token text,
   backup_invite_code text
 )
 LANGUAGE plpgsql
 STABLE
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_token uuid;
begin
  begin
    v_token := trim(p_token)::uuid;
  exception
    when invalid_text_representation then
      return;
  end;

  return query
  select
    i.id,
    i.household_id,
    h.name,
    coalesce(nullif(trim(p.display_name), ''), nullif(trim(p.email), ''), 'Someone'),
    i.access_role,
    i.relationship,
    i.status,
    i.expires_at,
    NULL::text AS invite_token,
    NULL::text AS backup_invite_code
  from public.household_invites i
  join public.households h on h.id = i.household_id
  left join public.profiles p on p.id = i.invited_by
  where i.invite_token = v_token
  order by i.created_at desc
  limit 1;
end;
$function$;

-- B3: REVOKE ALL FROM PUBLIC, anon; GRANT EXECUTE TO authenticated only
REVOKE ALL ON FUNCTION public.accept_household_invite(text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.accept_household_invite_by_id(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.accept_household_invite_by_token(text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.get_invite_by_code(text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.get_invite_by_id(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.get_invite_by_token(text) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.accept_household_invite(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.accept_household_invite_by_id(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.accept_household_invite_by_token(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_invite_by_code(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_invite_by_id(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_invite_by_token(text) TO authenticated;

COMMIT;
