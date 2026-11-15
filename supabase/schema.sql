-- Carl & Mariana Adventskalender: Supabase schema.
-- Run once in the Supabase dashboard: SQL Editor -> New query -> paste -> Run.

-- ---------------------------------------------------------------------------
-- Profiles: one row per person, created automatically for every auth user.
-- ---------------------------------------------------------------------------

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null
);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(
      nullif(new.raw_user_meta_data ->> 'display_name', ''),
      initcap(split_part(new.email, '@', 1))
    )
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

alter table public.profiles enable row level security;

create policy "Signed-in users read profiles"
  on public.profiles for select to authenticated
  using (true);

-- ---------------------------------------------------------------------------
-- Surprises: one per sender and advent day (December 1-24).
-- ---------------------------------------------------------------------------

-- Latest calendar date that has started anywhere on Earth (UTC+14).
-- The server releases a door once its day has begun in any time zone; the app
-- additionally keeps it closed until the day has begun on the recipient's phone.
create or replace function public.latest_unlocked_day()
returns date
language sql
stable
as $$
  select ((now() at time zone 'UTC') + interval '14 hours')::date;
$$;

create table public.surprises (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  recipient_id uuid not null references public.profiles (id) on delete cascade,
  day date not null,
  note text not null default '',
  link text,
  media_path text unique,
  media_name text,
  media_type text check (media_type in ('image', 'video', 'file')),
  created_at timestamptz not null default now(),
  opened_at timestamptz,
  constraint surprises_not_to_self check (sender_id <> recipient_id),
  constraint surprises_one_per_day unique (sender_id, day),
  constraint surprises_advent_day check (
    extract(month from day) = 12 and extract(day from day) between 1 and 24
  ),
  constraint surprises_has_content check (
    note <> '' or link is not null or media_path is not null
  ),
  constraint surprises_media_complete check (
    (media_path is null) = (media_type is null)
  )
);

create index surprises_recipient_day on public.surprises (recipient_id, day);

alter table public.surprises enable row level security;

create policy "Senders manage their surprises"
  on public.surprises for all to authenticated
  using (sender_id = auth.uid())
  with check (sender_id = auth.uid());

create policy "Recipients read unlocked surprises"
  on public.surprises for select to authenticated
  using (recipient_id = auth.uid() and day <= public.latest_unlocked_day());

-- Recipients may only flip opened_at, so this runs as a narrow RPC instead of
-- an update policy on the whole row.
create or replace function public.mark_surprise_opened(surprise_id uuid)
returns void
language sql
security definer
set search_path = public
as $$
  update public.surprises
  set opened_at = now()
  where id = surprise_id
    and recipient_id = auth.uid()
    and opened_at is null
    and day <= public.latest_unlocked_day();
$$;

revoke execute on function public.mark_surprise_opened(uuid) from public, anon;
grant execute on function public.mark_surprise_opened(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Storage: private bucket, files live under "<sender id>/...".
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit)
values ('surprises', 'surprises', false, 52428800)
on conflict (id) do nothing;

create policy "Senders upload into their folder"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'surprises'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Senders delete their files"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'surprises'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Senders and recipients of unlocked doors read files"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'surprises'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or exists (
        select 1
        from public.surprises s
        where s.media_path = storage.objects.name
          and s.recipient_id = auth.uid()
          and s.day <= public.latest_unlocked_day()
      )
    )
  );
