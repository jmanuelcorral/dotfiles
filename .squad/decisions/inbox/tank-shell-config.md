# Decision: Shell Configuration — bash/zsh + WSL Bootstrap

**Date:** 2026-06-01  
**Author:** Tank  
**Status:** ACTIVE  
**Requested by:** Copilot (josecorral)

---

## Context

Implementing the Unix/WSL shell layer of the dotfiles repo. Target: PowerShell 7.6 on Windows + WSL bash/zsh user who wants muscle-memory parity between Windows Terminal and WSL.

---

## Decisions

### 1. Starship for WSL prompt (not Oh My Posh)

**Decision:** Starship is initialised in `shell/bash/bashrc.sh` and `shell/zsh/zshrc.sh`. Oh My Posh remains on PowerShell only.

**Rationale:**
- Starship is a single binary with one `starship.toml` config shared across bash, zsh, and any future Linux shells.
- Async by default; fastest prompt on large Git repos.
- Oh My Posh has deeper Windows/PowerShell API integration; keeping it there is the best-of-both approach endorsed by Oracle.
- The zshrc.sh guard (`[ -z "$ZSH" ]`) prevents Starship from fighting oh-my-zsh if the user installs it later.

### 2. apt quirks handled in both install.sh and common.sh

**Decisions:**
- `bat` → installed as `batcat` on Ubuntu <22.04. `bootstrap/install.sh` creates `~/.local/bin/bat → batcat`. `common.sh` also wraps `bat()` as a shell function if the symlink is missing.
- `fd` → installed as `fd-find`/binary `fdfind` on all Debian/Ubuntu. Same two-layer approach: symlink + shell function wrapper.
- `eza` → Ubuntu 23.10+ only via standard apt. `install.sh` falls back to the official gierens.de apt repo, then cargo.
- `zoxide` → Ubuntu 22.10+ via apt. `install.sh` falls back to the official `install.sh` script.
- `delta` → not in Ubuntu apt. Fetched from GitHub releases (musl static binary, no libc requirement).
- `yq` → `mikefarah/yq` fetched from GitHub releases (not python-yq which has the same command name but different interface).
- `starship` → installed via the official `curl | sh` script; no apt package.

### 3. Shell stub approach (idempotent)

**Decision:** `bootstrap/install.sh` appends a two-line stub to `~/.bashrc` and `~/.zshrc`, guarded by a `# dotfiles bootstrap` marker. A timestamped `.backup.<timestamp>` is created before any modification. The script is safe to re-run.

**Stub format:**
```bash
# dotfiles bootstrap — DO NOT EDIT BELOW (added 2026-06-01-164312)
export DOTFILES="/path/to/dotfiles"
source "${DOTFILES}/shell/bash/bashrc.sh"
```

This exactly follows the load contract in `morpheus-repo-architecture.md`.

### 4. common.sh is POSIX-first

**Decision:** `shell/common.sh` avoids bashisms (`[[`, `(( ))`, `echo -e`, bash-only `local` with assignment). Uses `[ ]`, `printf`, and POSIX parameter expansion. Passes `bash -n` (Git Bash 5.3 on Windows). Zsh-specific code stays in `shell/zsh/zshrc.sh`.

### 5. dotfiles CLI function in bash/zsh

**Decision:** Implemented as a `dotfiles()` shell function in `common.sh` providing `help [query]`, `list`, `update`, `edit`. Uses fzf for interactive search when present, falls back to rg/grep. Reads `shared/tools.json` (via jq) and `docs/cheatsheet.md`. Behaviour matches the PowerShell `dotfiles` command described in `docs/cheatsheet.md`.

### 6. Nerd Font (WSL note)

**Decision:** `bootstrap/install.sh` installs MesloLGS NF to `~/.local/share/fonts` for native Linux use. For WSL, the font is rendered by Windows Terminal; a note is printed reminding the user to set it in Windows Terminal → Default Profile → Font face.

---

## Files Created/Modified

| File | Action |
|------|--------|
| `shell/common.sh` | Implemented (aliases, functions, dotfiles CLI, fzf, MANPAGER, PATH) |
| `shell/bash/bashrc.sh` | Implemented (history, shopt, bash-completion, zoxide, starship) |
| `shell/zsh/zshrc.sh` | Implemented (history, setopt, compinit, keybinds, zoxide, starship) |
| `packages/apt.json` | Expanded (apt, script_installs, github_releases sections with binary quirks) |
| `bootstrap/install.sh` | Implemented (full idempotent installer, `--no-packages` flag) |

---

## Consequences

- All aliases mirror `shared/aliases.json` unix fields with modern-tool-guards.
- Bootstrap is safe to re-run on a fresh Ubuntu WSL or existing system.
- No hardcoded paths; everything derives from `$DOTFILES` (set in stub) or `BASH_SOURCE[0]` (fallback).
- Syntax validated via Git Bash 5.3 (`bash -n`). Full runtime validation requires Ubuntu WSL.
