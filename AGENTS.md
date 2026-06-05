# AGENTS.md — dotfiles repo

> Concise, actionable guidance for AI coding agents working in this repo.
> Read `.squad/decisions.md` **before** any architectural change.

---

## Project Overview

Portable terminal-config repo — clone once, install once, sync everywhere.

| Platform | Entry point | Installer |
|---|---|---|
| Windows PowerShell 7+ | `powershell/profile.ps1` | `bootstrap/install.ps1` |
| Linux / macOS bash | `shell/bash/bashrc.sh` | `bootstrap/install.sh` |
| Linux / macOS zsh | `shell/zsh/zshrc.sh` | `bootstrap/install.sh` |
| WSL2 | same as Linux above | same |

---

## Architecture / Load Contract

### The thin-stub pattern

System profile files contain **only** a 2-line bootstrap stub (guarded by the `# dotfiles bootstrap` marker). The stub sets `$DOTFILES`/`DOTFILES` and sources the repo entry point. **Never edit the system `$PROFILE` / `~/.bashrc` / `~/.zshrc` directly — edit repo files.**

**PowerShell stub** (written to system `$PROFILE`):
```powershell
# dotfiles bootstrap
$env:DOTFILES = "C:\path\to\dotfiles"; . "$env:DOTFILES\powershell\profile.ps1"
```

**Bash/Zsh stub** (appended to `~/.bashrc` or `~/.zshrc`):
```sh
# dotfiles bootstrap
export DOTFILES="$HOME/dotfiles"; . "$DOTFILES/shell/bash/bashrc.sh"   # or zshrc.sh
```

### PowerShell load order (`powershell/profile.ps1`)

1. `aliases.ps1`
2. `psreadline.ps1`
3. `prompt.ps1`
4. `completions.ps1`
5. `modules/*.ps1` — alphabetical, drop-in

Then adds `bin/` to `$env:PATH`.

### Unix load order

`~/.bashrc` or `~/.zshrc` stub → shell-specific entry (`bash/bashrc.sh` / `zsh/zshrc.sh`) → both source **`shell/common.sh`** (POSIX-first, no bashisms) → add `bin/` to `PATH`.

---

## Repo Layout

```
dotfiles/
├── bootstrap/          # install.ps1 (Windows), install.sh (Unix)
├── bin/                # registered user scripts (dotfiles register <name>)
├── powershell/
│   ├── profile.ps1     # main entry point
│   ├── aliases.ps1
│   ├── psreadline.ps1
│   ├── prompt.ps1
│   ├── completions.ps1
│   ├── modules/        # drop-in .ps1 modules (loaded alphabetically)
│   └── themes/         # Oh My Posh theme JSON(s)
├── shell/
│   ├── common.sh       # POSIX-first, sourced by both bash and zsh
│   ├── bash/
│   │   └── bashrc.sh
│   ├── zsh/
│   │   └── zshrc.sh
│   └── lib/            # shared shell helpers
├── shared/
│   ├── aliases.json    # single source of truth for cross-shell aliases
│   └── tools.json      # registered bin/ scripts metadata
├── packages/
│   ├── winget.json
│   ├── scoop.json
│   └── apt.json
├── docs/               # ARCHITECTURE.md, cheatsheet.md, plans/, research/
├── cache/              # gitignored — llama-cli binary, GGUF models
├── .squad/             # AI team: decisions.md, agent histories, routing
├── .github/            # workflows, issue templates
└── skills/             # portable SKILL.md guides (see skills/README.md)
```

---

## Conventions (MUST-follow)

### Windows + Unix parity
- A change to a `dotfiles` CLI subcommand **must** be mirrored in **both** `bin/dotfiles.ps1` and `shell/common.sh`.
- Aliases are defined **once** in `shared/aliases.json`:
  ```json
  { "ll": { "windows": "eza -la --icons", "unix": "eza -la --icons", "_note": "long list with icons" } }
  ```
  Then consumed by `powershell/aliases.ps1` (PowerShell functions) and `shell/common.sh` (shell aliases/functions).

### Idempotency (non-negotiable)
- Detect-then-skip every step. Guard package installs with `Get-Command`/`command -v`.
- Back up user files with a timestamp before modifying.
- Safe to re-run: re-running `install.ps1` or `install.sh` must produce no side-effects.
- winget exit code `-1978335189` = already installed → treat as success.

### Guard every external tool
Profile startup must **never throw** if a tool is missing. Every `Import-Module`, `oh-my-posh init`, `zoxide init`, etc. must be wrapped in a guard:
```powershell
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) { ... }
```

### Versioning
- Single SemVer line in root `VERSION` file.
- Release notes in `CHANGELOG.md` as `## [x.y.z] - YYYY-MM-DD`.
- Both shells read `VERSION` at runtime — never hardcode a version string.

### Paths
- PowerShell: use `Join-Path` and `$env:DOTFILES`. Never hardcode user paths like `C:\Users\username`.
- Shell: use `$DOTFILES` variable. Never hardcode `$HOME/username/…`.

---

## Common Tasks

| Task | What to do |
|---|---|
| Add a PS module | Drop a `.ps1` file in `powershell/modules/` — loaded alphabetically on next shell start |
| Add an alias | Edit `shared/aliases.json` → mirror in `powershell/aliases.ps1` AND `shell/common.sh` |
| Add a package | Add entry to `packages/winget.json`, `packages/scoop.json`, or `packages/apt.json` |
| Register a bin/ script | Run `dotfiles register <name>` — updates `shared/tools.json` |
| Add a PS completer | Add to `powershell/completions.ps1` (guarded) |
| Add a shell helper | Add to `shell/lib/` and source from `common.sh` |

---

## Build / Test / Run

There is **no formal test suite**. Validate by:

| Check | Command |
|---|---|
| PowerShell stub wiring | `pwsh -NoProfile -File bootstrap/install.ps1 -NoPackages` |
| Shell syntax | `bash -n shell/common.sh && bash -n shell/bash/bashrc.sh` |
| Zsh syntax | `zsh -n shell/zsh/zshrc.sh` |
| Idempotency | Re-run the installer — it must produce no changes on second run |

The installers **are** the build. Re-running them validates the entire load contract.

---

## Reusable Skills

The `skills/` directory contains portable SKILL.md guides that capture architectural knowledge for AI agents:

| Skill | What it teaches |
|---|---|
| `dotfiles-architecture` | Load contract, thin-stub pattern, module boundaries |
| `powershell-config` | PSReadLine, Oh My Posh, alias functions, module guards |
| `shell-parity` | POSIX-first rules, bash/zsh divergence, common.sh patterns |
| `packages-and-tooling` | winget/scoop/apt schemas, idempotent install patterns |
| `bootstrap-idempotency` | Marker guards, backup strategy, re-run safety |
| `dotfiles-cli-extension` | Adding subcommands to `dotfiles` CLI (both shells) |

Skills can be installed into any project with `dotfiles skills install`. See `skills/README.md`.

---

## The Squad AI Team

This repo uses a `.squad/` AI team. The Coordinator routes work; decisions live in `.squad/decisions.md`.

**Agents must read `.squad/decisions.md` before any architectural change.**

Key active decisions:
- **#1** — Repository layout and load contract (Morpheus)
- **#3** — bin/ registration and dotfiles CLI (Switch)
- **#4** — Shell configuration, POSIX-first common.sh (Tank)
- **#5** — PowerShell configuration, alias catalog in `shared/aliases.json` (Trinity)
- **#11** — Self-contained local agent architecture (Morpheus)
