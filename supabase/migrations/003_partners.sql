-- 003: open sign-up with partner linking.
--
-- Every person is linked to at most one partner, symmetrically
-- (A.partner_id = B and B.partner_id = A). Two people are only linked once
-- both have named each other's email address, so nobody can attach themselves
-- to someone else's tree. Only the security-definer functions below write
-- partner_id; signed-in users have no update rights on profiles.
--
-- If exactly two profiles exist (Carl and Mariana), they are linked here.

-- ---------------------------------------------------------------------------
-- Profiles: partner link and per-person test date
-- ---------------------------------------------------------------------------

alter table public.profiles
  add column partner_id uuid unique references public.profiles (id) on delete set null,
  add column test_date date,
  add constraint profiles_partner_not_self check (partner_id <> id);

do $$
declare
  first_id uuid;
  second_id uuid;
begin
  if (select count(*) from public.profiles) = 2
     and not exists (select 1 from public.profiles where partner_id is not null) then
    select id into first_id from public.profiles order by id limit 1;
    select id into second_id from public.profiles order by id desc limit 1;
    update public.profiles
    set partner_id = case id when first_id then second_id else first_id end;
  end if;
end;
$$;

-- The test date used to be global (app_config); it is now set per person, so
-- one couple's test cannot open another couple's doors.
update public.profiles set test_date = (select test_date from public.app_config);

create or replace function public.my_partner_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select partner_id from public.profiles where id = auth.uid();
$$;

revoke execute on function public.my_partner_id() from public, anon;
grant execute on function public.my_partner_id() to authenticated;

-- Latest calendar date that has started anywhere on Earth (UTC+14), or the
-- signed-in person's test date while one is set.
create or replace function public.latest_unlocked_day()
returns date
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select test_date from public.profiles where id = auth.uid()),
    ((now() at time zone 'UTC') + interval '14 hours')::date
  );
$$;

drop table public.app_config;

-- ---------------------------------------------------------------------------
-- Row level security: only your own and your partner's data
-- ---------------------------------------------------------------------------

drop policy "Signed-in users read profiles" on public.profiles;

create policy "People read their own and their partner's profile"
  on public.profiles for select to authenticated
  using (id = auth.uid() or id = public.my_partner_id());

drop policy "Senders manage their surprises" on public.surprises;

create policy "Senders manage surprises for their partner"
  on public.surprises for all to authenticated
  using (sender_id = auth.uid())
  with check (sender_id = auth.uid() and recipient_id = public.my_partner_id());

drop policy "Recipients read unlocked surprises" on public.surprises;

create policy "Recipients read unlocked surprises from their partner"
  on public.surprises for select to authenticated
  using (
    recipient_id = auth.uid()
    and sender_id = public.my_partner_id()
    and day <= public.latest_unlocked_day()
  );

-- Only people with a partner can upload, so sign-ups cannot fill the bucket.
drop policy "Senders upload into their folder" on storage.objects;

create policy "Linked senders upload into their folder"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'surprises'
    and (storage.foldername(name))[1] = auth.uid()::text
    and public.my_partner_id() is not null
  );

-- ---------------------------------------------------------------------------
-- Invitations: one pending invitation per person
-- ---------------------------------------------------------------------------

create table public.invitations (
  inviter_id uuid primary key references public.profiles (id) on delete cascade,
  invitee_email text not null check (invitee_email = lower(invitee_email)),
  created_at timestamptz not null default now()
);

create index invitations_invitee_email on public.invitations (invitee_email);

grant select on public.invitations to authenticated;
grant all on public.invitations to service_role;

alter table public.invitations enable row level security;

create policy "People read their own invitation"
  on public.invitations for select to authenticated
  using (inviter_id = auth.uid());

-- Invite someone by email, or accept their invitation by naming them back.
-- Returns 'linked' when both have now named each other, else 'invited'.
create or replace function public.invite_partner(partner_email text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  my_email text;
  target text := lower(trim(partner_email));
  other uuid;
  unlinked int;
begin
  if me is null then
    raise exception 'You are signed out.';
  end if;
  if target !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then
    raise exception 'Enter a valid email address.';
  end if;
  select lower(email) into my_email from auth.users where id = me;
  if target = my_email then
    raise exception 'That is your own email address.';
  end if;
  select id into other from auth.users where lower(email) = target;

  -- Lock both rows in a fixed order so concurrent links cannot interleave.
  perform 1 from public.profiles
  where id in (me, other)
  order by id
  for update;

  if (select partner_id from public.profiles where id = me) is not null then
    raise exception 'You are already connected with a partner.';
  end if;

  if other is not null
     and exists (
       select 1 from public.invitations
       where inviter_id = other and invitee_email = my_email
     ) then
    select count(*) into unlinked
    from public.profiles
    where id in (me, other) and partner_id is null;
    if unlinked = 2 then
      update public.profiles
      set partner_id = case id when me then other else me end
      where id in (me, other);
      delete from public.invitations where inviter_id in (me, other);
      return 'linked';
    end if;
  end if;

  insert into public.invitations (inviter_id, invitee_email)
  values (me, target)
  on conflict (inviter_id) do update
    set invitee_email = excluded.invitee_email, created_at = now();
  return 'invited';
end;
$$;

-- Unlinked people who invited the signed-in person.
create or replace function public.incoming_invitations()
returns table (inviter_name text, inviter_email text)
language sql
stable
security definer
set search_path = public
as $$
  select p.display_name, u.email::text
  from public.invitations i
  join auth.users me on me.id = auth.uid()
  join public.profiles p on p.id = i.inviter_id and p.partner_id is null
  join auth.users u on u.id = i.inviter_id
  where i.invitee_email = lower(me.email)
    and public.my_partner_id() is null
  order by i.created_at;
$$;

create or replace function public.decline_invitation(inviter_email text)
returns void
language sql
security definer
set search_path = public
as $$
  delete from public.invitations i
  using auth.users inviter, auth.users me
  where me.id = auth.uid()
    and inviter.id = i.inviter_id
    and lower(inviter.email) = lower(trim(inviter_email))
    and i.invitee_email = lower(me.email);
$$;

revoke execute on function public.invite_partner(text) from public, anon;
revoke execute on function public.incoming_invitations() from public, anon;
revoke execute on function public.decline_invitation(text) from public, anon;
grant execute on function public.invite_partner(text) to authenticated;
grant execute on function public.incoming_invitations() to authenticated;
grant execute on function public.decline_invitation(text) to authenticated;
