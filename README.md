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
(`supabase/schema.sql`) also refuses to hand out a surprise or its file before
its day has begun anywhere on Earth (UTC+14), so nobody can peek through the API.

Data lives in [Supabase](https://supabase.com): sign-in, database, and a private
file bucket. Files are only accessible to the sender and, once the door is open,
the recipient.

## Supabase setup (once)

1. Create a free project at <https://supabase.com/dashboard> (choose an EU region).
2. **SQL Editor → New query**: paste [`supabase/schema.sql`](supabase/schema.sql)
   and run it.
3. **Authentication → Users → Add user → Create new user**: create one account
   for Carl and one for Mariana (email + password, tick *Auto Confirm User*).
   The display name is taken from the part of the email before `@`; change it in
   **Table Editor → profiles** if needed.
4. **Authentication → Sign In / Providers**: turn off *Allow new users to sign
   up*, so nobody else can create an account.
5. **Project Settings → API Keys**: copy the project URL and the publishable
   (or legacy anon) key. Copy `supabase.example.json` to `supabase.json` and
   fill in both values. `supabase.json` is ignored by git.

Free-tier notes: files can be at most 50 MB (videos recorded in the app are
limited to 2 minutes), total storage is 1 GB, and inactive free projects get
paused after about a week. Open the dashboard and restore the project if the app
cannot connect.

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
puro flutter run -d chrome --dart-define=ADVENT_DEMO=true --dart-define=ADVENT_DEMO_TODAY=2026-12-03T09:00:00
```

## Installing on the phones

- **Android**: `puro flutter build apk --release --dart-define-from-file=supabase.json`,
  then copy `build/app/outputs/flutter-apk/app-release.apk` to the phone and
  install it (allow installing from unknown sources). The release build is
  signed with the debug key, which is fine for installing it yourself.
- **iPhone**: needs a Mac with Xcode. Open `ios/Runner.xcworkspace`, select your
  Apple ID as team, and run on the connected phone with
  `flutter run --release --dart-define-from-file=supabase.json`. With a free
  Apple ID the app has to be reinstalled every 7 days; a paid developer account
  allows TestFlight instead. Minimum iOS version is 14.

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
- `supabase/schema.sql`: tables, row-level security, storage bucket and policies

Not built yet: push notifications when a new door opens or a partner fills a
door. The app reloads when it comes back to the foreground, and every list
supports pull-to-refresh.
