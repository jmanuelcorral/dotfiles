# Decision: Windows Install Flow, bin/ Registration, and dotfiles CLI

**Date:** 2026-06-01
**Author:** Switch
**Status:** ACTIVE

---

## Context

The dotfiles repo needs a one-shot Windows bootstrap and a daily-driver CLI tool (`dotfiles`). This decision records the design choices made during implementation.

---

## Install Flow (`bootstrap/install.ps1`)

### Repo Root Detection
`$PSScriptRoot` gives the directory of the script (`bootstrap/`). `Split-Path $PSScriptRoot -Parent` reliably yields the repo root regardless of clone path. `$env:DOTFILES` is set from this value — no hardcoded paths.

### Package Schema
`packages/winget.json` uses an object array (not a string array):
```json
{ "id": "...", "command": "...", "scoop": "...", "description": "..." }
```
- `command` is the binary name used for the guard (`Get-Command <command> -ErrorAction SilentlyContinue`).
- `scoop` is the fallback name when winget is unavailable or fails.
- `id` is the winget package ID.

This schema makes the installer self-documenting and trivially extensible.

### Idempotency Strategy
1. **Package guard:** `Get-Command <binary>` — skips if already on PATH, regardless of how it was installed.
2. **Module guard:** `Get-Module -ListAvailable -Name X | Where-Object { $_.Version -ge <min> }` — skips if already installed with a sufficient version.
3. **Profile stub guard:** `Select-String -Pattern "# dotfiles bootstrap"` on `$PROFILE` raw content. If found, skip entirely; never duplicate.
4. **Backup before touch:** If the profile exists and lacks the marker, a timestamped backup is created (`$PROFILE.backup.yyyy-MM-dd-HHmmss`) before appending. No data loss.
5. **Exit code tolerance:** winget exit code `-1978335189` (0x8A150011) means "already installed" — treated as success.

### Profile Stub
Exactly follows the architecture contract:
```powershell
# dotfiles bootstrap — DO NOT EDIT BELOW
$env:DOTFILES = "<repo-root>"
. "$env:DOTFILES\powershell\profile.ps1"
```
Written with `Add-Content` (append) if profile exists, or `Set-Content` if creating from scratch. `$PROFILE` is used as-is (resolves to OneDrive-redirected path correctly since it's a built-in variable).

### OneDrive-Redirected Documents
`$PROFILE` resolves automatically to the correct path (e.g. OneDrive\Documents\PowerShell\...). The installer creates the parent directory if it doesn't exist (`New-Item -ItemType Directory -Force`). No hardcoded paths.

### `-NoPackages` Switch
Allows wiring only the `$PROFILE` stub — useful for re-running after manual package installs or for CI/testing.

---

## bin/ Registration System

### Design
`dotfiles register <name> [-Description "..."]` updates `shared/tools.json`:
```json
{
  "tools": [
    { "name": "gituseswitch", "path": "bin/gituseswitch", "description": "Switch git user identity" }
  ]
}
```
- The command checks whether `bin/<name>` or `bin/<name>.ps1` exists, warns if not, but registers anyway (allows registering before creating the script).
- Re-running with the same name updates the existing entry (upsert) — no duplicates.
- `path` always uses forward slashes for cross-platform readability.

### Why tools.json instead of a separate registry
Single source of truth, readable by both PowerShell and bash scripts, trivially parseable with `ConvertFrom-Json` / `jq`.

---

## dotfiles CLI (`bin/dotfiles.ps1`)

### Subcommand Dispatch
Standard `switch ($Command.ToLower())` pattern — clean and extensible.

### `dotfiles help`
- Reads `docs/cheatsheet.md` and appends a live-generated "Registered Tools" section from `shared/tools.json`.
- With **no argument**: launches `fzf` interactively (if available) — the intended daily-driver UX. Falls back to plain coloured output.
- With **a query argument**: substring filter (case-insensitive via `-match [regex]::Escape($Query)`), no fzf dependency.

### `dotfiles register`
Upsert into `shared/tools.json` using a mutable `List[object]` to avoid PowerShell's fixed-size array limitation with `+=`.

### PATH wiring
`powershell/profile.ps1` adds `$env:DOTFILES/bin` to `$env:PATH` (per architecture contract). This makes `dotfiles` available as a command after sourcing the profile — no separate install step.

---

## Install Instructions (for README)

```
# Clone the repo
git clone https://github.com/<you>/dotfiles.git $HOME\dotfiles

# Run the installer (installs packages + wires profile)
pwsh -File $HOME\dotfiles\bootstrap\install.ps1

# Optional: profile only, no packages
pwsh -File $HOME\dotfiles\bootstrap\install.ps1 -NoPackages
```

For a fresh PC with PowerShell 7 already present:
```
git clone <repo> && pwsh ./bootstrap/install.ps1
```

---

## Open Questions

- Should `dotfiles register` also accept a `-Path` override (for tools not in `bin/`)?
- Should `dotfiles help` support paging (e.g. pipe through `bat --language=md`) when fzf is absent?
- Cross-shell: Tank should expose a `dotfiles` wrapper in `shell/common.sh` that calls `pwsh -File $DOTFILES/bin/dotfiles.ps1`.
