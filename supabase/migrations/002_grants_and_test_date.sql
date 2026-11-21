-- 002: explicit Data API grants, and an optional test date.
--
-- Supabase no longer exposes new tables in `public` to the API roles
-- automatically, so the app gets "permission denied for table" without these
-- grants. Row level security still decides which rows each person sees.

grant select on public.profiles to authenticated;
grant select, insert, update, delete on public.surprises to authenticated;
grant all on public.profiles, public.surprises to service_role;

-- ---------------------------------------------------------------------------
-- Test date: pretend "today" is another day, for both phones at once.
--
--   update public.app_config set test_date = '2026-12-05';  -- pretend
--   update public.app_config set test_date = null;          -- real date
--
-- Doors up to the test date open on the server and in the app, which shows a
-- "Test date" banner while it is set. Set it back to null before December:
-- a test date late in December reveals all doors up to that day.
-- ---------------------------------------------------------------------------

create table public.app_config (
  id boolean primary key default true check (id),
  test_date date
);

insert into public.app_config default values;

grant select on public.app_config to authenticated;
grant all on public.app_config to service_role;

alter table public.app_config enable row level security;

create policy "Signed-in users read the config"
  on public.app_config for select to authenticated
  using (true);

-- Latest calendar date that has started anywhere on Earth (UTC+14), or the
-- test date while one is set.
create or replace function public.latest_unlocked_day()
returns date
language sql
stable
as $$
  select coalesce(
    (select test_date from public.app_config),
    ((now() at time zone 'UTC') + interval '14 hours')::date
  );
$$;

revoke execute on function public.latest_unlocked_day() from public, anon;
grant execute on function public.latest_unlocked_day() to authenticated;
