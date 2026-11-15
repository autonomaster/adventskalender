# Development Guidelines

## Branches

- `main` is protected and must remain releasable.
- Every implementation starts on a feature branch, for example `feature/daily-notifications`.
- Do not commit implementation work directly to `main`.
- Keep branches focused and reasonably short-lived.

## Pull requests

- Merge changes into `main` through a pull request.
- CI must pass before merge.
- At least one reviewer approval is required.
- `@autonomaster` is the default reviewer and should be requested on every PR.
- Resolve review comments before merging.
- The author should not self-approve their own PR.

## Code and tests

- Prefer the smallest maintainable change that completes the behavior.
- Add or update tests for user-visible behavior and important state transitions.
- Run formatting, analysis, and tests locally before opening a PR.
- Do not commit secrets, signing keys, generated local configuration, or credentials.
- Update relevant project documentation when behavior or setup changes.

## Required GitHub repository settings

The repository should protect `main` with:

- Pull request required before merging
- At least one approving review
- Code-owner review enabled
- Required CI status checks
- Force-push and branch deletion restrictions as appropriate

The repository-level `.github/CODEOWNERS` file requests `@autonomaster` as the default code owner.

## Automation identity

- Commit author identity and GitHub PR author identity are separate.
- `@autonomaster` cannot approve their own PR; PRs opened by `@autonomaster` need another reviewer or an automation identity as author.
