# Carl & Mariana Adventskalender

A two-person advent calendar app. Each person has it on their phone and is
connected with exactly one partner. For every day from 1 to 24 December, each
of them fills a pouch on the other's Christmas tree: a photo, a video, any other
file, a message, a link, or a mix. The recipient can open a pouch only once its
day has started; afterwards every received surprise stays in the gallery.

The look is a risograph print: a few overprinted inks (green, blue, red, pink,
yellow) on warm paper, with halftone shading, grain and slight misregistration.
The tree, pouches and star are drawn in code (`lib/ui`), no image assets.

## How it works

- **My tree**: 24 pouches hang on your tree, scattered over the branches, with
  door 24 right under the star. Pale pouches are still locked, bright red ones
  with sparkles are ready to open, open pouches have been opened, and dashed
  outlines mean the day has started but your partner has not filled it yet.
  Today's pouch has a yellow halo. Tapping a ready pouch pops it up as a big
  open pouch with the surprise rising out of it.
- **Partner's tree** ("Prepare" tab): the tree you fill for your partner.
  Dashed pouches with a plus are empty; tap one to add or change its surprise.
  Filled pouches are tied shut, and they show as open once your partner has
  opened them.
- **Gallery**: every received surprise whose pouch has opened, newest first,
  across all years.
- **Links** show a preview card with thumbnail and title (YouTube, Spotify,
  Vimeo and SoundCloud via oEmbed, other sites via their OpenGraph tags). In
  the browser build most sites block this (CORS), so previews there fall back
  to the plain link; on the phones they work.

Doors open at local midnight on the recipient's phone. The server
(`supabase/migrations`) also refuses to hand out a surprise or its file before
its day has begun anywhere on Earth (UTC+14), so nobody can peek through the API.

Data lives in [Supabase](https://supabase.com): sign-in, database, and a private
file bucket. Files are only accessible to the sender and, once the door is open,
the recipient.

## Accounts and partners

Anyone can create an account in the app (name, email, password of at least 8
characters). Supabase emails a 6-digit code (German and English) that is
typed into the app to confirm the address; **Send a new code** resends it.
**Forgot password?** works the same way: a code by email plus the new
password. Codes work identically in the Android app and on the website, no
links to open on the right device.

After the first sign-in, people without a partner see **Connect with your
partner**:

1. Enter your partner's email address. If they have an account and already
   invited you, the two trees are connected right away.
2. Otherwise they get a pending invitation: once they have an account with
   exactly that address, they see "*You* wants to connect" with **Accept** /
   **Decline**, or they can enter your address themselves.
3. **Send invitation email** opens your own mail app with a prefilled
   invitation including the app link (the website address, or `APP_URL` from
   `supabase.json` in the Android app).

Rules, enforced by the database (`supabase/migrations/003_partners.sql`), not
just the app:

- Two people are only connected once **both** have named each other, so nobody
  can attach themselves to someone else's tree.
- Everyone has at most one partner; nobody can change or remove the link from
  the app (only in the dashboard).
- People only see their own and their partner's profile and surprises, can only
  fill their partner's tree, and can only upload files once connected.

Carl and Mariana were connected by the migration; nothing changes for them.

### Account limit

`supabase/migrations/004_signup_limit.sql` refuses new sign-ups once 50
accounts exist ("Anmeldungen sind gerade voll / Sign-ups are full right now").
Accounts count once confirmed, or while their confirmation is pending for less
than a day. Let more people in with:

```sql
update public.signup_settings set max_accounts = 100;
```

Check the current number with `select count(*) from auth.users;`.

Automatic invitation emails sent by the server would need a custom email
provider plus a Supabase Edge Function; the mail-app button avoids both.

## Supabase setup (once)

1. Create a free project at <https://supabase.com/dashboard> (choose an EU region).
2. **SQL Editor → New query**: paste each file in
   [`supabase/migrations`](supabase/migrations) and run it, in order
   (`001_…` to `004_…`). Later files are changes; run each new one once.
3. **Authentication → Auth Hooks → Before User Created**: Postgres function
   `public.hook_limit_signups` (the account limit).
4. Email sending: Supabase's built-in sender only delivers to members of your
   Supabase team and at most 2 emails an hour. This project sends through
   Gmail (**Authentication → Emails → SMTP Settings**: host `smtp.gmail.com`,
   port 465, the Gmail address as user and sender, a Google
   [app password](https://myaccount.google.com/apppasswords) as password,
   sender name "Adventskalender"). Gmail allows about 500 emails a day. The
   address is shown to everyone who signs up; a dedicated Gmail account for
   sending keeps your personal one private.
5. **Authentication → Emails → Templates**: *Confirm signup* and *Reset
   password* show `{{ .Token }}` (the code) instead of a link.
6. **Authentication → Sign In / Providers → Email**: *Allow new users to sign
   up* on, **Confirm email** on (it proves people own their address, so nobody
   can register someone else's email and accept invitations meant for them),
   minimum password length 8, email OTP length 6.
7. **Project Settings → API Keys**: copy the publishable key. The project URL is
   `https://<project-ref>.supabase.co` (shown under **Project Settings → Data
   API**), not the dashboard address. Copy `supabase.example.json` to
   `supabase.json` and fill in the values. `supabase.json` is ignored by git.

Steps 3 to 6 are recorded in [`supabase/auth-config.json`](supabase/auth-config.json)
(the settings this project changes, with `${…}` placeholders for the Gmail
address and app password). It can be applied in one call instead of clicking:
`PATCH https://api.supabase.com/v1/projects/<ref>/config/auth` with a personal
access token, after substituting the placeholders. Every change to the live
project is logged in [`docs/ops-log.md`](docs/ops-log.md).

Accounts can also be created by hand under **Authentication → Users → Add user**
(tick *Auto Confirm User*); they connect in the app like everyone else.

Free-tier notes: files can be at most 50 MB (videos recorded in the app are
limited to 2 minutes), total storage is 1 GB, there are no automatic backups,
and projects without activity for about a week get paused (Supabase emails a
warning first). A paused project can be resumed from the dashboard for up to a
year, with all data.

### Test date

To try the calendar before December, pretend "today" is another day for one
couple, without a new app build. In **SQL Editor** (set it for both partners):

```sql
-- pretend
update public.profiles set test_date = '2026-12-05'
where id in (select id from auth.users
             where email in ('carl@example.com', 'mariana@example.com'));

-- back to the real date
update public.profiles set test_date = null where test_date is not null;
```

(or edit `test_date` in **Table Editor → profiles**). Each person's server-side
unlocking follows their own test date, so other couples are unaffected, and the
app shows a yellow "Test date" bar. The app picks the change up when it is
reopened or brought back to the foreground, or on pull-to-refresh. Set it back
to `null` before 1 December, and delete test surprises (**Table Editor →
surprises**; their files are in **Storage → surprises**): a test date late in
December reveals every door up to that day.

## Running

Requires the Flutter SDK. Like the Casita project, this uses
[Puro](https://puro.dev) with Flutter 3.38.10 (`.puro.json`):

```text
puro flutter pub get
puro flutter run --dart-define-from-file=supabase.json
```

### Demo mode (no Supabase)

Try the app without a backend. Both accounts live in memory; sign out and in
again to switch between Carl (`carl@demo`) and Mariana (`mariana@demo`),
password `advent`. `ADVENT_DEMO_TODAY` pretends it is a given day:

```text
puro flutter run -d chrome --release --dart-define=ADVENT_DEMO=true --dart-define=ADVENT_DEMO_TODAY=2026-12-03T09:00:00
```

Use `--release` to judge speed: debug builds on the web run several times
slower and make taps feel delayed.

## Installing on the phones

### Android (app)

```text
puro flutter build apk --release --dart-define-from-file=supabase.json
```

Copy `build/app/outputs/flutter-apk/app-release.apk` to the phone and open it
(allow installing from unknown sources). The build is signed with this PC's
debug key: updates install over the old version as long as they are built on
the same PC; otherwise uninstall first (data lives in Supabase, nothing is lost).

### iPhone (website)

Without a Mac the iPhone uses the web version, which talks to the same Supabase
project. Build it:

```text
puro flutter build web --release --dart-define-from-file=supabase.json
```

Then publish the folder `build/web` on any static host with HTTPS, for example
[Netlify Drop](https://app.netlify.com/drop):

1. Sign up / log in at netlify.com first (deploys made without an account are
   deleted after an hour).
2. Open <https://app.netlify.com/drop> and drag the `build/web` folder onto it.
3. Under **Project configuration → Change project name** pick a name; the
   site is then at `https://<name>.netlify.app`.
4. Click **Make public**. New Netlify projects start private, and on the free
   plan a private project is visible only to the account owner, so Mariana
   would get a Netlify login page instead of the calendar.
5. For updates, rebuild and drag `build/web` onto the project's **Deploys**
   page.

On the iPhone, open the address in Safari, sign in, then **Share → Add to Home
Screen**: it opens full screen with the tree icon, like an app. Notes:

- The site only contains the publishable key, which is meant to be public;
  without an account it shows nothing but the sign-in screen.
- Browsers block most link previews (CORS), so on the website links mostly
  show as plain cards; YouTube previews work.
- Videos recorded on an iPhone are often HEVC `.mov`, which some Android
  phones cannot play.

A native iPhone app needs a Mac with Xcode: open `ios/Runner.xcworkspace`,
select your Apple ID as team, and run
`flutter run --release --dart-define-from-file=supabase.json`. With a free
Apple ID it has to be reinstalled every 7 days. Minimum iOS version is 14.

## Development

```text
puro dart format .
puro flutter analyze
puro flutter test
```

CI runs the same checks (`.github/workflows/flutter.yml`). Branch, review,
deployment and logging rules are in
[`development_guidelines.md`](development_guidelines.md).

Layout:

- `lib/core/models`: calendar rules (`advent.dart`) and surprise data
- `lib/core/data`: repository interfaces with Supabase and in-memory versions
- `lib/core/services`: photo/video/file picking, link previews
- `lib/ui`: riso palette and theme, tree and pouch painters, pouch layout
- `lib/features`: sign-in, my tree, partner's tree and editor, gallery,
  surprise popup
- `supabase/migrations`: tables, grants, row-level security, storage bucket and
  policies, test date, account limit
- `supabase/auth-config.json`: auth settings (SMTP, email templates, hooks)
- `docs/ops-log.md`: log of changes to Supabase, Netlify and GitHub settings

## TODO

- **Behaviour tests in CI for the database rules.** Today CI only runs the
  Flutter tests against the in-memory backend. The row-level security,
  partner linking (`invite_partner`), storage policies and the account limit
  were only checked with throwaway scripts and live test accounts. Add a CI
  job that applies `supabase/migrations` to a throwaway Supabase stack
  (`supabase start` from the Supabase CLI on the CI runner; plain Postgres or
  PGlite would need stubs for the `auth` and `storage` schemas and roles) and
  asserts: strangers see nothing, only mutual invitations link, linked people
  cannot switch partners or set their test date, uploads only into the own
  folder and only when linked, and `public.hook_limit_signups(jsonb)` (called
  directly) refuses sign-ups at `max_accounts`.
- Push notifications when a new door opens or a partner fills a door. Until
  then the app reloads when it comes back to the foreground, and every list
  supports pull-to-refresh.
