# Switch — History

## Seed Context

- **Project:** dotfiles — portable terminal/shell configuration repo
- **Stack:** PowerShell, winget/scoop, bash (delegates to Tank), Git, Python, Node.js
- **Goals:** one-line bootstrap install from the repo (Windows + Unix); extensible system to register the user's own tooling (e.g. gituseswitch); a CLI help/cheat tool for most-used commands. Everything idempotent.
- **Requested by:** Copilot (git user.name)

## Learnings

### 2026-06-01 — Windows Installer + dotfiles CLI

**Files created/updated:**
- `packages/winget.json` — upgraded from string array to object array with `id`, `command`, `scoop`, `description` fields
- `packages/scoop.json` — full fallback list with bucket info
- `bootstrap/install.ps1` — full implementation replacing the placeholder
- `bin/dotfiles.ps1` — new CLI tool (help/list/register/update/edit)
- `docs/cheatsheet.md` — expanded from ~25 to ~100 entries across 8 categories
- `shared/tools.json` — cleaned up _todo comment

**Key idempotency lessons:**
- `$PROFILE` is the right variable to use for the profile path — it resolves OneDrive-redirected Documents automatically. Never hardcode.
- `Get-Command <binary> -ErrorAction SilentlyContinue` is the right guard for CLI tools — it's fast and works regardless of how the tool was installed (winget, scoop, manual).
- winget exit code `-1978335189` means "already installed at requested version" — should be treated as success, not failure.
- `Select-String -Quiet` is the cleanest way to check for a marker string in a file without reading line-by-line.

**CLI design:**
- `fzf` as the interactive backend for `dotfiles help` gives a great UX with zero extra code. The plain-text fallback (coloured ANSI via `Write-Host`) works fine when fzf is absent.
- Using `[System.Collections.Generic.List[object]]` instead of `@()` + `+=` avoids the PowerShell fixed-array gotcha when building tool lists.
- Positional params `$Command` and `$Arg1` plus a named `-Description` param gives a clean CLI API without needing argument parsing libraries.

**Testing approach:**
- `[ScriptBlock]::Create((Get-Content file.ps1 -Raw))` validates parse correctness without executing side effects.
- For integration testing of stub writing, override `$PROFILE` in a wrapper scriptblock that dot-sources the installer — this avoids touching the real profile.
- Idempotency was verified by running the installer twice and confirming "already present" messages on second run.

