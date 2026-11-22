# Development Guidelines

The repository is public. `main` is protected and must remain releasable.

## Branches and pull requests

- Every change goes through a branch and a pull request into `main`; direct
  pushes, force pushes and deleting `main` are blocked. Only the very first
  commit (the initial version of the project) went straight to `main`.
- Name branches by purpose: `feature/…`, `fix/…`, `chore/…`. Keep them focused
  and short-lived.
- CI (`Flutter checks`) must be green before any merge. This applies to
  everyone, including the owner.

### Contributors

- Create a branch (or a fork) and open a pull request.
- The code owner `@autonomaster` must approve it before it can be merged.
- Resolve review comments before merging.

### Owner (`@autonomaster`, including the coding agent working for him)

- Feature branch → pull request → `gh pr checks <n>` shows `flutter` green →
  merge yourself with `gh pr merge <n> --merge --admin`. No approval needed:
  the owner bypasses the review ruleset only; the CI ruleset has no bypass,
  so `--admin` cannot merge while the required check is not passing.
- `--admin` is only for pull requests the owner authored. Never use it on a
  contributor's pull request: approve it first, then merge normally.
- Before merging any owner pull request, the agent hands the PR diff and its
  scope to a review subagent on a cheaper model than its own (currently
  Sonnet). The agent decides what is in scope: in-scope findings are fixed
  before merging; the rest is posted as a PR comment for later.

## Code and tests

- Prefer the smallest maintainable change that completes the behavior.
- Add or update tests for user-visible behavior and important state transitions.
- Run `dart format`, `flutter analyze` and `flutter test` locally before
  opening a pull request.
- Update relevant documentation (README, this file) when behavior or setup
  changes.

## Secrets and personal data

Never commit:

- `.env` (API tokens, Gmail app password, test-account credentials) and
  `supabase.json` (project URL and publishable key); both are git-ignored.
- Passwords, tokens, signing keys, personal email addresses, real user data.

Use placeholders like `${GMAIL_APP_PASSWORD}` where a value is needed in a
committed file; [`.env.example`](.env.example) lists the variable names.
Commits use the GitHub no-reply address
(`git config user.email 337420157+autonomaster@users.noreply.github.com`).

## Supabase and Netlify

- Change production only from merged `main`: run new migrations and deploy
  `build/web` after the pull request is merged. Exceptions (urgent fixes,
  tests) are allowed but are marked as such in the log.
- Schema and policy changes: a new numbered file in `supabase/migrations/`,
  never edit an applied one.
- Auth settings (SMTP, templates, hooks, sign-up rules): update
  `supabase/auth-config.json` in the same pull request. It pins the auth
  settings this project relies on, with `${…}` placeholders for secrets. To
  apply it, replace the placeholders with the values from `.env` (JSON-escaped),
  check that no `${` is left, then send it as the body of
  `PATCH https://api.supabase.com/v1/projects/<ref>/config/auth` with
  `Authorization: Bearer $SUPABASE_ACCESS_TOKEN`. Apply migrations first: the
  sign-up hook calls a function from `004_signup_limit.sql`.
- Log every action on Supabase, Netlify or the GitHub repository settings in
  [`docs/ops-log.md`](docs/ops-log.md), briefly (abbreviations and SQL
  snippets are fine). No secrets in the log. Because `main` only changes via
  pull requests: a row for a change caused by a PR goes into that PR; rows for
  actions after a merge (deploys, settings, tests) are collected on a
  `chore/ops-log` branch and merged as one small PR at the end of the session.

## GitHub repository settings

Two rulesets protect `main`:

1. **main: CI and history** (no bypass): changes only via pull request,
   required status check `flutter`, no force pushes, no deletion.
2. **main: review** (bypass for repository admins, only via pull request):
   one approving review, code-owner review (`.github/CODEOWNERS` →
   `@autonomaster`), stale approvals dismissed on new commits.
