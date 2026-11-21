# Carl & Mariana Adventskalender

A two-person advent calendar app. Carl and Mariana each have it on their phone.
For every day from 1 to 24 December, each of them fills a pouch on the other's
Christmas tree: a photo, a video, any other file, a message, a link, or a mix.
The recipient can open a pouch only once its day has started; afterwards every
received surprise stays in the gallery.

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

## Supabase setup (once)

1. Create a free project at <https://supabase.com/dashboard> (choose an EU region).
2. **SQL Editor → New query**: paste each file in
   [`supabase/migrations`](supabase/migrations) and run it, in order
   (`001_…`, then `002_…`). Later files are changes; run each new one once.
3. **Authentication → Users → Add user → Create new user**: create one account
   for Carl and one for Mariana (email + password, tick *Auto Confirm User*).
   The display name is taken from the part of the email before `@`; change it in
   **Table Editor → profiles** if needed.
4. **Authentication → Sign In / Providers**: turn off *Allow new users to sign
   up*, so nobody else can create an account.
5. **Project Settings → API Keys**: copy the publishable key. The project URL is
   `https://<project-ref>.supabase.co` (shown under **Project Settings → Data
   API**), not the dashboard address. Copy `supabase.example.json` to
   `supabase.json` and fill in both values. `supabase.json` is ignored by git.

Free-tier notes: files can be at most 50 MB (videos recorded in the app are
limited to 2 minutes), total storage is 1 GB, there are no automatic backups,
and projects without activity for about a week get paused (Supabase emails a
warning first). A paused project can be resumed from the dashboard for up to a
year, with all data.

### Test date

To try the calendar before December, pretend "today" is another day, for both
phones at once and without a new app build. In **SQL Editor**:

```sql
update public.app_config set test_date = '2026-12-05';  -- pretend
update public.app_config set test_date = null;          -- back to the real date
```

(or edit the single row in **Table Editor → app_config**). The server unlocks
doors up to the test date, and the app shows a yellow "Test date" bar. The app
picks the change up when it is reopened or brought back to the foreground, or
on pull-to-refresh. Set it back to `null` before 1 December, and delete test
surprises (**Table Editor → surprises**; their files are in **Storage →
surprises**): a test date late in December reveals every door up to that day.

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
4. For updates, rebuild and drag `build/web` onto the project's **Deploys**
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

CI runs the same checks (`.github/workflows/flutter.yml`). Branch and review
rules are in [`development_guidelines.md`](development_guidelines.md).

Layout:

- `lib/core/models`: calendar rules (`advent.dart`) and surprise data
- `lib/core/data`: repository interfaces with Supabase and in-memory versions
- `lib/core/services`: photo/video/file picking, link previews
- `lib/ui`: riso palette and theme, tree and pouch painters, pouch layout
- `lib/features`: sign-in, my tree, partner's tree and editor, gallery,
  surprise popup
- `supabase/migrations`: tables, grants, row-level security, storage bucket and
  policies, test date

Not built yet: push notifications when a new door opens or a partner fills a
door. The app reloads when it comes back to the foreground, and every list
supports pull-to-refresh.
