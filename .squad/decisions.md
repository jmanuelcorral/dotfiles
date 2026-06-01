# Squad Decisions

## Active Decisions

### 1. Architecture Decision: Repository Layout and Load Contract

**Date:** 2026-06-01  
**Author:** Morpheus  
**Status:** ACTIVE — All agents MUST follow

This document defines the authoritative structure for the dotfiles repo. Trinity, Tank, and Switch must implement within this framework.

**Directory Layout (Canonical)**
- `powershell/` (Trinity owns) — profile.ps1, aliases.ps1, psreadline.ps1, prompt.ps1, completions.ps1, modules/
- `shell/` (Tank owns) — common.sh, bash/bashrc.sh, zsh/zshrc.sh
- `shared/` — aliases.json, tools.json (cross-shell data)
- `bin/` — User scripts (Switch manages registration)
- `bootstrap/` — install.ps1, install.sh
- `packages/` — Declarative package lists
- `docs/` — ARCHITECTURE.md, cheatsheet.md

**Load Contract:** PowerShell system `$PROFILE` contains only bootstrap stub; `profile.ps1` loads in order: aliases.ps1, psreadline.ps1, prompt.ps1, completions.ps1, modules/*.ps1 (alphabetical), adds `bin` to PATH. Bash/Zsh: `~/.bashrc` / `~/.zshrc` contain only bootstrap stub; each sources `common.sh`, adds `bin` to PATH, shell-specific setup.

**Idempotency Rules:** All install scripts check before modifying (look for `# dotfiles bootstrap` marker), backup before changing, guard package installs, report actions, never duplicate. Tool registration in `bin/` via `dotfiles register <name>` updates `shared/tools.json`.

---

### 2. Decision: Oracle Recommended Terminal Stack (2026-06-01)

**Status:** Proposed  
**Author:** Oracle  
**Date:** 2026-06-01  

**Prompt Engine:** Keep Oh My Posh on Windows PowerShell (deeper Windows API integration); Add Starship inside WSL only (fastest async prompt, single `starship.toml` shared across all Linux shells).

**CLI Tool Stack (must-have):** eza (ls replacement with icons + Git status), bat (cat replacement with syntax highlighting), fd (find replacement, gitignore-aware), zoxide (smart cd, frecency-based jump), delta (git diff with side-by-side syntax highlighting), jq (JSON processor), yq/mikefarah (YAML processor).

**PowerShell Modules:** PSReadLine with PredictionSource HistoryAndPlugin + ListView; Terminal-Icons; posh-git; PSFzf (Ctrl+T file picker, Ctrl+R history).

**Package Management:** Windows: winget import (declarative, idempotent) + scoop; WSL: apt + cargo for missing tools.

**Font:** CaskaydiaCove Nerd Font Mono via `oh-my-posh font install` (no admin required).

**Dotfiles Management:** chezmoi for one-liner bootstrap from GitHub, per-OS templates, secrets support, idempotent.

---

### 3. Decision: Windows Install Flow, bin/ Registration, and dotfiles CLI

**Date:** 2026-06-01  
**Author:** Switch  
**Status:** ACTIVE

**Repo Root Detection:** `$PSScriptRoot` yields bootstrap/ dir; `Split-Path $PSScriptRoot -Parent` reliably yields repo root. `$env:DOTFILES` set from this value — no hardcoded paths.

**Package Schema:** `packages/winget.json` uses object array with `id` (winget ID), `command` (binary name for guard), `scoop` (fallback), `description`. Makes installer self-documenting and extensible.

**Idempotency Strategy:** Package guard via `Get-Command <binary>`; module guard via `Get-Module -ListAvailable` version check; profile stub guard via `Select-String -Pattern "# dotfiles bootstrap"` on raw `$PROFILE` content; backup with timestamp before touch; exit code `-1978335189` (already installed) treated as success.

**Profile Stub:** Exactly follows architecture contract; written with `Add-Content` (append) or `Set-Content` (create); `$PROFILE` resolves automatically to OneDrive-redirected path.

**bin/ Registration:** `dotfiles register <name> [-Description "..."]` updates `shared/tools.json` with upsert logic (no duplicates). Path uses forward slashes for cross-platform readability.

**dotfiles CLI:** Subcommand dispatch via switch. `dotfiles help` reads `docs/cheatsheet.md` + live-generated "Registered Tools" from `shared/tools.json`; launches fzf interactively if available, falls back to coloured output; with query argument, substring filter (case-insensitive). `dotfiles register` uses mutable `List[object]` to avoid fixed-size array limitation.

---

### 4. Decision: Shell Configuration — bash/zsh + WSL Bootstrap

**Date:** 2026-06-01  
**Author:** Tank  
**Status:** ACTIVE  

**Starship for WSL prompt (not Oh My Posh):** Starship initialised in bash/bashrc.sh and zsh/zshrc.sh; single binary with one shared `starship.toml`; async by default; fastest prompt on large Git repos; zshrc.sh guard `[ -z "$ZSH" ]` prevents fighting oh-my-zsh.

**apt quirks handled:** `bat` → installed as `batcat` on Ubuntu <22.04; `bootstrap/install.sh` creates symlink + `common.sh` wraps as shell function. `fd` → installed as `fd-find`/`fdfind`; same two-layer approach. `eza` → Ubuntu 23.10+ via apt; fallback to gierens.de apt repo, then cargo. `zoxide` → Ubuntu 22.10+ via apt; fallback to official script. `delta` → fetched from GitHub releases (musl static). `yq` → mikefarah/yq from GitHub releases. `starship` → official curl script.

**Shell stub approach (idempotent):** Two-line stub appended to ~/.bashrc and ~/.zshrc, guarded by `# dotfiles bootstrap` marker. Timestamped `.backup.<timestamp>` created before modification. Safe to re-run.

**common.sh is POSIX-first:** Avoids bashisms; uses `[ ]`, `printf`, POSIX parameter expansion; passes `bash -n`. Zsh-specific code stays in zsh/zshrc.sh.

**dotfiles CLI function in bash/zsh:** Implemented in `common.sh` providing `help [query]`, `list`, `update`, `edit`. Uses fzf for interactive search, falls back to rg/grep. Reads `shared/tools.json` (via jq) and `docs/cheatsheet.md`. Behaviour matches PowerShell `dotfiles` command.

**Nerd Font (WSL note):** `bootstrap/install.sh` installs MesloLGS NF to ~/.local/share/fonts for native Linux use. For WSL, note printed reminding user to set in Windows Terminal.

---

### 5. Decision: PowerShell Configuration — OMP Fix, Alias Catalog, Module Choices

**Date:** 2026-06-01  
**Author:** Trinity  
**Status:** ACTIVE

**Problem:** User's existing profile (934 lines) had three issues: (1) Oh My Posh startup error — missing theme file; (2) Hardcoded user path (josecorral); (3) 900-line boilerplate.

**Oh My Posh — repo-local theme, no hardcoded paths:** Custom theme at `powershell/themes/dotfiles.omp.json`, referenced via `$env:DOTFILES`. Fallback chain: repo theme → $env:POSH_THEMES_PATH → plain-text prompt. Theme: Tokyo Night palette, powerline segments: OS icon → path → git → node → python → execution time → status; right segment: clock.

**Alias catalog location — `shared/aliases.json`:** Canonical source of truth for cross-shell aliases. Trinity implements in `powershell/aliases.ps1`; Tank implements in `shell/common.sh`. JSON schema: `{ "alias": { "windows": "...", "unix": "...", "_note": "..." } }`. Single source prevents drift. Strategy: use functions (not `Set-Alias`) for anything that forwards arguments; prefer modern tools when present (eza > Get-ChildItem, rg > Select-String, bat > Get-Content, fd > Get-ChildItem -Recurse); guard every preference with `Get-Command X -ErrorAction SilentlyContinue`.

**PSReadLine — VT console guard:** Wrap `Set-PSReadLineOption -PredictionViewStyle ListView` in `$Host.UI.RawUI.WindowSize.Width -gt 0` guard. ListView requires VT processing; guard degrades gracefully to InlineView without breaking startup.

**Module choices:** PSReadLine (always load, built-in), Terminal-Icons (guarded import), posh-git (guarded import), PSFzf (guarded import + fzf check), zoxide (guarded Invoke-Expression).

**Completers:** Ported winget + dotnet (native completers). Added gh (GitHub CLI), zoxide init, PSFzf key bindings. All guarded.

---

## Governance

- All meaningful changes require team consensus
- Document architectural decisions here
- Keep history focused on work, decisions focused on direction
