-- 004: cap the number of accounts.
--
-- New sign-ups are refused once `max_accounts` accounts exist. Raise the cap
-- to let more people in:
--
--   update public.signup_settings set max_accounts = 100;
--
-- Accounts count once confirmed, or while their confirmation is pending for
-- less than a day, so unconfirmed junk sign-ups cannot block the cap forever.
--
-- Supabase calls the function below before creating a user (Auth Hooks →
-- Before User Created → Postgres function public.hook_limit_signups).

create table public.signup_settings (
  id boolean primary key default true check (id),
  max_accounts integer not null default 50 check (max_accounts >= 0)
);

insert into public.signup_settings default values;

-- No API access: only the dashboard and the hook function (which runs as its
-- owner) read this table.
alter table public.signup_settings enable row level security;

create or replace function public.hook_limit_signups(event jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  accounts integer;
  allowed integer;
begin
  select max_accounts into allowed from public.signup_settings;
  select count(*) into accounts
  from auth.users
  where email_confirmed_at is not null
     or created_at > now() - interval '1 day';
  if accounts >= coalesce(allowed, 0) then
    return jsonb_build_object(
      'error', jsonb_build_object(
        'http_code', 403,
        'message',
        'Anmeldungen sind gerade voll, bitte versuch es später noch einmal. / '
          || 'Sign-ups are full right now, please try again later.'
      )
    );
  end if;
  return '{}'::jsonb;
end;
$$;

revoke execute on function public.hook_limit_signups(jsonb)
  from public, anon, authenticated;
grant execute on function public.hook_limit_signups(jsonb)
  to supabase_auth_admin;
