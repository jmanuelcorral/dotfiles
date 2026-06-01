# dotfiles Architecture

> Last updated: 2026-06-01  
> Author: Morpheus (Lead Architect)

## Overview

This repo is the **single source of truth** for shell configuration across Windows (PowerShell 7+) and Unix (bash/zsh via WSL or native Linux/macOS). Your system's profile files become thin stubs that source this repo—meaning you clone once, run install, and you're done.

---

## Directory Layout

```
dotfiles/
├── powershell/           # PowerShell configuration
│   ├── profile.ps1       # ENTRY POINT (system $PROFILE sources this)
│   ├── aliases.ps1       # Linux-style aliases (ls, grep, cat, etc.)
│   ├── prompt.ps1        # Oh-My-Posh / Starship setup
│   ├── psreadline.ps1    # PSReadLine customization
│   ├── completions.ps1   # Tab-completion registrations
│   └── modules/          # Drop-in *.ps1 modules (auto-loaded)
│
├── shell/                # Unix shell configuration
│   ├── common.sh         # POSIX-compatible aliases/functions (shared)
│   ├── bash/
│   │   └── bashrc.sh     # Bash-specific config (sources common.sh)
│   └── zsh/
│       └── zshrc.sh      # Zsh-specific config (sources common.sh)
│
├── shared/               # Cross-shell data (not code)
│   ├── aliases.json      # Alias definitions consumed by both shells
│   └── tools.json        # Registered user tools metadata
│
├── bin/                  # User's own scripts/tools (added to PATH)
│   └── README.md         # How to register a new tool
│
├── bootstrap/            # One-line install scripts
│   ├── install.ps1       # Windows: sets up profile stub, links, deps
│   └── install.sh        # Unix: sets up bashrc/zshrc stub, deps
│
├── packages/             # Declarative package lists
│   ├── winget.json       # Windows packages (winget)
│   ├── scoop.json        # Windows packages (scoop)
│   └── apt.json          # Debian/Ubuntu packages
│
├── docs/                 # Documentation
│   ├── ARCHITECTURE.md   # This file
│   └── cheatsheet.md     # CLI quick-reference (powers the help tool)
│
└── README.md             # Quick start + one-liners
```

---

## Load Contract

### Principle: Repo Is Truth, Profile Is Stub

Your **system profile** (`$PROFILE` on Windows, `~/.bashrc` or `~/.zshrc` on Unix) should contain **only a stub** that sources this repo. This keeps the system clean and all logic versioned.

### PowerShell Load Contract

The bootstrap installer writes this to `$PROFILE`:

```powershell
# dotfiles bootstrap — DO NOT EDIT BELOW
$env:DOTFILES = "D:\gitrepos\personal\dotfiles"   # or wherever cloned
. "$env:DOTFILES\powershell\profile.ps1"
```

`powershell/profile.ps1` then:
1. Dot-sources each module in order: `aliases.ps1`, `psreadline.ps1`, `prompt.ps1`, `completions.ps1`
2. Auto-loads any `*.ps1` in `powershell/modules/`
3. Adds `$env:DOTFILES/bin` to `$env:PATH`

### Bash/Zsh Load Contract

The bootstrap installer appends this to `~/.bashrc` or `~/.zshrc`:

```bash
# dotfiles bootstrap — DO NOT EDIT BELOW
export DOTFILES="$HOME/dotfiles"   # or wherever cloned
source "$DOTFILES/shell/bash/bashrc.sh"   # or zsh/zshrc.sh
```

Each shell-specific file:
1. Sources `shell/common.sh` for shared aliases/functions
2. Adds `$DOTFILES/bin` to `PATH`
3. Runs shell-specific setup (prompt, completions)

---

## Idempotency Rules

**Every script must be safe to run multiple times.** This is non-negotiable.

### Rules for `bootstrap/install.ps1` and `install.sh`:

| Requirement | Implementation |
|-------------|----------------|
| Don't duplicate stub | Check for marker comment before appending |
| Don't reinstall packages | Check if package/command exists first |
| Don't clobber user edits | Backup profile with timestamp before modifying |
| Support re-runs | Use `if ! command -v X` / `if (-not (Get-Command X))` guards |
| Report actions | Print what's being done; skip silently if already done |

### Guard Patterns

**PowerShell:**
```powershell
if (-not (Get-Content $PROFILE -Raw | Select-String "dotfiles bootstrap")) {
    # safe to append stub
}
```

**Bash:**
```bash
if ! grep -q "dotfiles bootstrap" ~/.bashrc; then
    # safe to append stub
fi
```

---

## Portability Strategy

| Concern | Solution |
|---------|----------|
| Different clone paths | `$env:DOTFILES` / `$DOTFILES` env var set by stub |
| Windows vs Unix paths | Scripts detect OS and adjust |
| Package managers vary | Separate package lists per manager in `packages/` |
| Shell differences | `shared/` for data, shell-specific dirs for code |

### Cross-Platform Aliases

Define aliases once in `shared/aliases.json`:
```json
{
  "ll": { "windows": "Get-ChildItem -Force", "unix": "ls -la" },
  "grep": { "windows": "Select-String", "unix": "grep" }
}
```

Each shell reads this and creates native aliases.

---

## Registering Your Own Tools

### Adding a Script to `bin/`

1. Place your script (e.g., `gituseswitch`, `mybackup.ps1`) in `bin/`
2. Ensure it has a shebang (Unix) or `.ps1` extension (Windows)
3. Run the registration command (implemented by Switch):
   ```
   dotfiles register gituseswitch --description "Switch git user configs"
   ```
4. This updates `shared/tools.json` and makes it available to the help system

### `shared/tools.json` Schema

```json
{
  "tools": [
    {
      "name": "gituseswitch",
      "path": "bin/gituseswitch",
      "description": "Switch between git user identities",
      "usage": "gituseswitch work|personal"
    }
  ]
}
```

The CLI helper (`dotfiles help`) reads this to show available commands.

---

## Module Loading Order (PowerShell)

`profile.ps1` loads in this explicit order:

1. **aliases.ps1** — aliases available immediately
2. **psreadline.ps1** — keybindings before prompt renders
3. **prompt.ps1** — Oh-My-Posh / Starship
4. **completions.ps1** — tab completions for tools
5. **modules/*.ps1** — user's drop-in extensions (alphabetical)

This order matters: aliases should exist before completions reference them.

---

## Adding New Functionality

### New PowerShell Module
Drop a `*.ps1` file in `powershell/modules/`. It auto-loads on next shell.

### New Shared Alias
Add to `shared/aliases.json`. Both shells pick it up.

### New Package Requirement
Add to the appropriate file in `packages/`. Re-run install.

### New Personal Tool
See "Registering Your Own Tools" above.

---

## Design Principles

1. **Single source of truth** — all config lives in this repo, not scattered across machines
2. **Idempotent everything** — re-running install is always safe
3. **Symmetric where sensible** — PowerShell and bash/zsh share concepts (aliases, tools, help)
4. **Composable modules** — small focused files, not one giant profile
5. **User-extensible** — `modules/` and `bin/` are escape hatches for custom needs
