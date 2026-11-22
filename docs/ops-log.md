# Ops log

Every change to the live Supabase project, Netlify site and GitHub repository
settings, newest first. Written by whoever makes the change (usually the coding
agent). No secrets, tokens, passwords or personal email addresses here.

Abbreviations: SB = Supabase project, NL = Netlify site `c-m-adventskalender`,
GH = GitHub repo, mig = `supabase/migrations/…`, cfg = `supabase/auth-config.json`
(applied via Management API `PATCH /v1/projects/{ref}/config/auth`),
deploy = upload of `build/web` via Netlify API (built with
`--dart-define-from-file=supabase.json`).

**Open:** Carl & Mariana still have `test_date` = 2026-12-03, reset to `null`
before 2026-12-01. Test accounts Testa/Testb still exist (count toward the
account limit).

| Date | Who | Where | What |
|---|---|---|---|
| 2026-11-22 | agent | GH | rulesets on `main`: "main: CI and history" (PR only, check `flutter`, no force push/deletion, no bypass) + "main: review" (1 approval, code owner, stale dismissal; admin bypass via PR) |
| 2026-11-22 | agent | GH | repo visibility → public (commit author emails accepted as public by Carl) |
| 2026-11-22 | agent | SB | snapshot of deliberately set auth settings committed as cfg |
| 2026-11-22 | agent | NL | deploy `fix/test-findings` build (readable errors, duplicate sign-up msg) — before PR #4 merged |
| 2026-11-22 | agent | SB | cfg: `disable_signup=false` (sign-ups open, email confirm on) |
| 2026-11-22 | agent | SB | test couple Testa/Testb created (mail.tm inboxes, creds in local `.env`): sign-up, link, `profiles.test_date` = 2026-12-05 → 2026-12-24; large test files deleted, accounts kept |
| 2026-11-22 | agent | SB | cfg: SMTP Gmail 465, sender "Adventskalender", `rate_limit_email_sent=30`, DE/EN code templates (confirm, recovery) |
| 2026-11-22 | agent | SB | cfg: `password_min_length=8`, `mailer_otp_length=6`, `uri_allow_list`, before-user-created hook → `public.hook_limit_signups` |
| 2026-11-22 | agent | SB | mig 004 (account cap 50) — before PR #3 merged |
| 2026-11-22 | agent | SB | cfg: `site_url` = NL URL (was localhost) |
| 2026-11-22 | agent | NL | deploy PR #2 build (partner linking) |
| 2026-11-22 | Carl | SB | mig 003 (partners, per-person test date; links Carl↔Mariana) |
| 2026-11-22 | Carl | SB | `profiles.test_date`/`app_config.test_date` = 2026-12-03 for Carl & Mariana |
| ≤2026-11-22 | Carl | NL | site created by drag-and-drop, made public |
| ≤2026-11-22 | Carl | SB | project created (eu-west-1), mig 001 + 002, users Carl & Mariana, sign-ups off |

Current test dates and accounts: `select display_name, partner_id is not null, test_date from public.profiles;`
