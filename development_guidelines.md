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

- Feature branch → pull request → wait for green CI → merge yourself. No
  approval needed (the owner bypasses the review rule, not the CI rule).
- Before merging, the agent has the pull request reviewed by a subagent on a
  cheaper model (Sonnet), giving it the PR diff and its scope. Comments that
  are relevant to the PR's scope are fixed before merging; anything else is
  noted on the PR for later.

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
committed file. Commits should use the GitHub no-reply address
(`git config user.email <id>+autonomaster@users.noreply.github.com`).

## Supabase and Netlify

- Change production only from merged `main`: run new migrations and deploy
  `build/web` after the pull request is merged. Exceptions (urgent fixes,
  tests) are allowed but must say so in the log.
- Schema and policy changes: a new numbered file in `supabase/migrations/`,
  never edit an applied one.
- Auth settings (SMTP, templates, hooks, sign-up rules): update
  `supabase/auth-config.json` in the same pull request. It holds exactly the
  settings this project changes from Supabase's defaults, with placeholders
  for secrets; it is applied with the Management API
  (`PATCH /v1/projects/{ref}/config/auth`) after substituting values from
  `.env`.
- Log every action on Supabase, Netlify or the GitHub repository settings in
  [`docs/ops-log.md`](docs/ops-log.md), in the same session, briefly
  (abbreviations and SQL snippets are fine). No secrets in the log.

## GitHub repository settings

Two rulesets protect `main`:

1. **main: CI and history** (no bypass): changes only via pull request,
   required status check `flutter`, no force pushes, no deletion.
2. **main: review** (bypass for repository admins, only via pull request):
   one approving review, code-owner review (`.github/CODEOWNERS` →
   `@autonomaster`), stale approvals dismissed on new commits.
