# Dotfiles Versioning

Use this pattern when adding release/version behavior to this repo.

## Pattern

- Store the current version only in root `VERSION` as a single SemVer line.
- Keep release notes in root `CHANGELOG.md` with `## [x.y.z] - YYYY-MM-DD` sections.
- Read `VERSION` from both shell implementations instead of duplicating constants.
- Report git context separately with `git rev-parse --short HEAD` when available.
- Make `update` safe to rerun: capture old version, `git pull --ff-only`, read new version, report the transition, optionally print changelog, then rerun the idempotent platform bootstrap.

## Files to check

- `bin\dotfiles.ps1`
- `shell\common.sh`
- `bootstrap\install.ps1`
- `bootstrap\install.sh`
- `README.md`
- `docs\cheatsheet.md`
