# dotfiles CLI — Developer Guide (English)

> Version reference: **v1.0.0** (see root `VERSION` file)  
> Date: 2026-06-05  
> [← Back to index](README.md) · [Español](commands.es.md)

---

## Table of Contents

1. [Introduction](#introduction)
2. [Getting Started & Discoverability](#getting-started--discoverability)
3. [Commands](#commands)
   - [help](#help)
   - [list](#list)
   - [version](#version)
   - [register](#register)
   - [update](#update)
   - [edit](#edit)
   - [explain](#explain)
   - [agent](#agent)
   - [skills](#skills)
4. [Workflows / Recipes](#workflows--recipes)
5. [Cross-references](#cross-references)

---

## Introduction

The `dotfiles` command is the single entry point to manage your terminal environment after the repo is installed. It is available in **both** shells:

| Shell | Location | How it is loaded |
|---|---|---|
| PowerShell 7+ | `bin/dotfiles.ps1` | `bin/` is on `$env:PATH` (added by `powershell/profile.ps1`) |
| bash / zsh | `shell/common.sh` — function `dotfiles()` | `common.sh` is sourced by `bash/bashrc.sh` and `zsh/zshrc.sh` |

### Parity principle

Every subcommand is available in **both** PowerShell and bash/zsh with identical syntax and the same general behavior. The only exception is `register`, which is a PowerShell-only operation on Unix (see [register](#register)).

Platform differences are highlighted in each command section with a **Platform notes** block.

---

## Getting Started & Discoverability

### `dotfiles help` — your built-in manual

```powershell
dotfiles help
```

With no arguments and **fzf installed**, this launches an interactive fuzzy browser over the full cheatsheet plus your registered tools. Type to filter; press Enter to select a line; press Esc to quit.

```powershell
dotfiles help git       # filter to lines matching "git"
dotfiles help stash     # find all stash-related entries instantly
```

Without fzf, the full cheatsheet is printed with syntax-highlighted headings.

### `dotfiles explain` — offline alias/tool lookup

```powershell
dotfiles explain ll     # what does `ll` expand to on Windows vs Unix?
dotfiles explain gst    # explain the `gst` git alias
```

This is **fully offline** — no model required. It reads `shared/aliases.json` and `shared/tools.json` directly. If the name is not in either registry, it falls back to running `<cmd> --help` and showing the first 20 lines.

---

## Commands

---

### `help`

**One-line summary:** Browse and search the command cheatsheet and registered tools.

#### Syntax

```
dotfiles help
dotfiles help <query>
```

#### What it does

Combines `docs/cheatsheet.md` with a live-generated **"Your Registered Tools"** section built from `shared/tools.json`, then:

- **With `<query>`** — filters the combined content to lines matching the query (case-insensitive substring match in PowerShell, `rg`/`grep -i` in bash/zsh).
- **No query + fzf present** — pipes all lines into `fzf` for interactive fuzzy search.
- **No query, no fzf** — prints the full content with coloured headings (PowerShell) or via `bat`/`cat` (bash/zsh).

#### Examples

```powershell
# Interactive fuzzy browse (requires fzf)
dotfiles help

# Filter to git-related entries
dotfiles help git

# Find all entries containing "stash"
dotfiles help stash
```

Expected output (filtered):

```
| `git stash`          | Stash uncommitted changes       |
| `git stash pop`      | Restore last stash              |
| `git stash list`     | Show all stashes                |
```

#### Platform notes

| Feature | PowerShell | bash/zsh |
|---|---|---|
| Fallback renderer | Coloured `Write-Host` | `bat` (if installed) or `cat` |
| Grep engine | PowerShell `-match` | `rg` (preferred) or `grep -i` |
| fzf binding | same | same |

#### Tips

- Install `fzf` for the best experience — it turns `dotfiles help` into a searchable command palette.
- `dotfiles help <topic>` is faster than grep-ing the cheatsheet manually.

---

### `list`

**One-line summary:** List all tools you have registered in `bin/`.

#### Syntax

```
dotfiles list
```

#### What it does

Reads `shared/tools.json` and prints every registered tool with its name, description, and `bin/` path.

- On **PowerShell**: formatted with padded columns and colour (name in white, path in dark grey).
- On **bash/zsh**: uses `jq` + `column` for aligned output; falls back to `grep` when jq is absent.

If no tools are registered yet, it prints a hint to use `dotfiles register`.

#### Examples

```powershell
dotfiles list
```

Expected output (PowerShell):

```
Registered tools in bin/

  gituseswitch            Switch git user identity
                          → bin/gituseswitch
```

```bash
# bash/zsh
dotfiles list
```

Expected output (bash):

```
gituseswitch    Switch git user identity
```

#### Platform notes

- On bash/zsh, output alignment requires `column` (standard on most Linux/macOS). If both `jq` and `column` are missing, names are shown one per line.
- An empty tools list is a normal state after a fresh install before any `register` commands.

---

### `version`

**One-line summary:** Show the current dotfiles version and git commit hash.

#### Syntax

```
dotfiles version
```

#### What it does

Reads the version from the root `VERSION` file (single SemVer line) and appends the short git SHA when the repo is available. Never hardcodes a version string — always reads from disk.

#### Examples

```powershell
dotfiles version
# dotfiles v1.0.0 (abc1234)
```

```bash
dotfiles version
# dotfiles v1.0.0 (abc1234)
```

If the repo is a zip extract without git history:

```
dotfiles v1.0.0
```

#### Platform notes

Identical behavior on both shells.

---

### `register`

**One-line summary:** Register (or update) a script in `bin/` by recording its metadata in `shared/tools.json`.

#### Syntax

```powershell
# PowerShell only
dotfiles register <name>
dotfiles register <name> -Description "Short description"
```

#### What it does

1. Checks whether `bin/<name>` or `bin/<name>.ps1` exists on disk (warns but proceeds if not found).
2. Looks up the tool name in `shared/tools.json`.
3. **Upserts**: if the name already exists, updates its description and path; if not, appends a new entry.
4. Saves the updated JSON back to `shared/tools.json` (UTF-8).

After registration, the tool appears in `dotfiles list`, in `dotfiles help` (under "Your Registered Tools"), and is resolvable with `dotfiles explain`.

#### Examples

```powershell
# Register a new script (file must be in bin/)
dotfiles register gituseswitch -Description "Switch git user identity"
#   ✓ Registered: gituseswitch
#   → shared/tools.json updated

# Re-register to update the description (idempotent)
dotfiles register gituseswitch -Description "Switch git identity (updated)"
#   ✓ Updated   : gituseswitch
#   → shared/tools.json updated

# Register without a description (description field will be empty)
dotfiles register myscript
```

#### Platform notes

| | PowerShell | bash/zsh |
|---|---|---|
| `register` available | ✅ Yes | ❌ No |
| Unix behavior | — | Prints error; suggests PowerShell CLI or editing `shared/tools.json` directly |

On Unix:

```bash
dotfiles register myscript
# dotfiles register: use the PowerShell CLI on Windows or edit shared/tools.json directly.
```

**Why?** Registration writes JSON with upsert logic that is implemented in the PowerShell module. On Unix, edit `shared/tools.json` directly and follow the schema:

```json
{
  "tools": [
    {
      "name": "myscript",
      "path": "bin/myscript",
      "description": "What it does"
    }
  ]
}
```

#### Tips

- The `-Description` flag is optional, but providing it makes `dotfiles help`, `dotfiles list`, and `dotfiles explain` far more useful.
- Use `dotfiles explain <name>` immediately after registering to confirm the entry looks right.

---

### `update`

**One-line summary:** Pull the latest commits, report version changes, re-run the installer, and reload the profile.

#### Syntax

```
dotfiles update
```

#### What it does

1. Records the **old version** from `VERSION`.
2. Runs `git pull --ff-only origin <current-branch>` inside the repo root (fast-forward only — no rebase, no unexpected history rewrites).
3. Reads the **new version** from `VERSION`.
4. Reports: `dotfiles: vOLD → vNEW` if upgraded, or `dotfiles: vNEW (already up to date)` if nothing changed.
5. If the version changed, prints the matching section from `CHANGELOG.md`.
6. Re-runs the platform installer (`bootstrap/install.ps1` or `bootstrap/install.sh`) — idempotent, so safe to always re-run.
7. Reloads the shell profile (`$PROFILE` on PowerShell; `exec bash`/`exec zsh` on Unix).

#### Examples

```powershell
dotfiles update
# Pulling latest dotfiles from origin...
# dotfiles: v1.0.0 → v1.1.0
#
# Changelog for v1.1.0
# ### Added
# - dotfiles skills install command
# Re-running installer to apply updates...
# Reloading $PROFILE...
# Done.
```

Already up to date:

```powershell
dotfiles update
# Pulling latest dotfiles from origin...
# dotfiles: v1.0.0 (already up to date)
```

#### Platform notes

| Step | PowerShell | bash/zsh |
|---|---|---|
| Installer | `bootstrap/install.ps1` | `bootstrap/install.sh` |
| Profile reload | `. $PROFILE` (dot-source) | `exec bash` or `exec zsh` |

#### Common pitfalls

- If the pull fails (diverged history, merge conflicts), `update` aborts — the installer and reload steps are skipped. Fix the conflict manually with `git status` inside `$DOTFILES`.
- `--ff-only` means your local commits must not conflict with upstream. If you have local commits, rebase or merge manually first.

---

### `edit`

**One-line summary:** Open the entire dotfiles repo in your editor.

#### Syntax

```
dotfiles edit
```

#### What it does

Detects an editor in this priority order and opens the repo root directory:

**PowerShell:**

1. `$env:EDITOR` (if set)
2. `code` (VS Code, if on PATH)
3. `notepad++` (if on PATH)
4. `notepad` (always available on Windows)

**bash/zsh:**

1. `$EDITOR` (if set)
2. `$VISUAL` (if set)
3. `vi` (fallback)

#### Examples

```powershell
dotfiles edit
# Opening dotfiles in 'code'...
```

```bash
dotfiles edit
# (opens $EDITOR with $DOTFILES path)
```

#### Platform notes

| | PowerShell | bash/zsh |
|---|---|---|
| Preferred editor | VS Code (`code`) | `$EDITOR` / `$VISUAL` |
| Fallback | `notepad` | `vi` |

#### Tips

- Set `$env:EDITOR = 'code'` (PowerShell) or `export EDITOR=nvim` (bash/zsh) in your profile to control which editor opens.
- `dotfiles edit` opens the repo **root** — perfect for browsing all config files at once in a tree view.

---

### `explain`

**One-line summary:** Show the definition and both-shell forms of any alias or registered tool — fully offline.

#### Syntax

```
dotfiles explain <alias-or-tool>
```

#### What it does

Searches three sources in order, stopping at the first match:

1. **`shared/aliases.json`** — if the name is a key in the `aliases` object, prints the `_note`, `windows` value, and `unix` value side by side.
2. **`shared/tools.json`** — if the name matches a registered tool, prints its description and `bin/` path.
3. **`<cmd> --help`** — if the name is found in PATH but not in either registry, runs `<name> --help` and shows the first 20 lines.

If nothing is found at all, suggests trying `dotfiles help <name>`.

> **No model required.** `explain` is 100% offline — it never invokes the AI agent.

#### Examples

```powershell
# Explain an alias from aliases.json
dotfiles explain ll

#   ll — Long listing with hidden files
#
#   Windows (PowerShell):
#     eza -la --icons --group-directories-first | Get-ChildItem -Force
#
#   Unix (bash/zsh):
#     eza -la --icons --group-directories-first | ls -la
```

```powershell
# Explain a git alias
dotfiles explain gst

#   gst — (alias detail from aliases.json)
#
#   Windows (PowerShell):
#     git status
#
#   Unix (bash/zsh):
#     git status
```

```powershell
# Explain a registered tool
dotfiles explain gituseswitch

#   gituseswitch — Switch git user identity
#   Path: bin/gituseswitch
```

```powershell
# Falls back to --help for unregistered commands
dotfiles explain rg

#   'rg' not in registry — showing --help output:
#
#   ripgrep 14.x.x ...
#   ...
```

#### Platform notes

| Feature | PowerShell | bash/zsh |
|---|---|---|
| JSON parsing | `ConvertFrom-Json` | `jq` (preferred) or `grep`/`sed` fallback |
| Output | Coloured `Write-Host` | `echo` / `printf` |

Without `jq` on Unix, the grep/sed fallback for aliases.json is heuristic — install `jq` for reliable output.

#### Tips

- `dotfiles explain <alias>` is the fastest way to remember what a short alias like `gl` or `gd` expands to.
- It also works for any alias name defined in `shared/aliases.json`, even if you are on the opposite platform.

---

### `agent`

**One-line summary:** Local AI assistant that generates shell commands from natural language — fully offline after setup.

#### Syntax

```
dotfiles agent --setup
dotfiles agent --setup --fallback
dotfiles agent "<query>"
dotfiles agent "<query>" --run
```

#### What it does

The `agent` subcommand uses a **self-contained local inference engine** — no daemon, no cloud API, no Python required. It runs `llama-cli` as a one-shot subprocess (exits when done).

##### `--setup` — first-time download

Downloads and installs:
- The `llama-cli` CPU binary from `ggml-org/llama.cpp` GitHub Releases (tag `b9469`).
- The `Qwen2.5-Coder-1.5B-Instruct Q4_K_M` model (~1 GB) from HuggingFace.

Everything is stored under `cache/` inside the repo root (gitignored):

```
cache/
  bin/
    llama-cli.exe       (Windows x64)
    ggml.dll
    llama.dll
  models/
    qwen2.5-coder-1.5b-instruct-q4_k_m.gguf
```

On **Windows**, the setup script calls `Unblock-File` on the extracted executables to remove the SmartScreen zone mark.

##### `--setup --fallback` — lighter model

Same as `--setup` but downloads the smaller **Qwen2.5-Coder-0.5B** model (~469 MB) instead. Useful on machines with ≤4 GB RAM or slow storage. Cold-start time drops to ~3–5 s.

##### `"<query>"` — generate a command

Builds a prompt from your query plus context from `shared/aliases.json` and `shared/tools.json`, then invokes `llama-cli` as a subprocess. The generated shell command is printed to stdout.

**Cold start:** ~5–8 s on a modern laptop CPU (no warm cache — the process starts fresh each call).

##### `"<query>" --run` — generate and optionally execute

Same as above, but after generating the command, asks for confirmation before running it. You can review the suggested command before it executes.

#### Examples

```powershell
# First-time setup (primary model, ~1 GB download)
dotfiles agent --setup

# Lighter model for low-RAM machines
dotfiles agent --setup --fallback

# Generate a command
dotfiles agent "list all .ps1 files modified in the last 7 days"
# Suggested: Get-ChildItem -Recurse -Filter *.ps1 | Where-Object LastWriteTime -gt (Get-Date).AddDays(-7)

# Generate and optionally run
dotfiles agent "find all TODO comments in this repo" --run
# Suggested: rg "TODO" .
# Run this command? [y/N]
```

```bash
# bash/zsh — same syntax
dotfiles agent --setup
dotfiles agent "find large files over 100MB" --run
# Suggested: find . -size +100M -type f
# Run this command? [y/N]
```

#### Agent deep-dive

| Property | Value |
|---|---|
| Engine | `llama-cli` (`ggml-org/llama.cpp`, tag `b9469`) |
| Primary model | Qwen2.5-Coder-1.5B-Instruct Q4_K_M (~1,066 MB) |
| Fallback model | Qwen2.5-Coder-0.5B-Instruct Q4_K_M (~469 MB) |
| Engine license | MIT |
| Model license | Apache 2.0 |
| Daemon required | ❌ No — one-shot subprocess |
| Python required | ❌ No |
| Network after setup | ❌ Fully offline |
| Cold start | ~5–8 s (primary), ~3–5 s (fallback) |
| Output tokens | 80 (configurable in `shared/agent-config.json`) |

Cache layout (all gitignored under `cache/`):

```
cache/bin/      → llama-cli binary + shared libraries
cache/models/   → GGUF model file(s)
```

#### Platform notes

| | Windows PowerShell | bash/zsh (Linux/WSL/macOS) |
|---|---|---|
| Engine asset | `llama-b9469-bin-win-cpu-x64.zip` | `llama-b9469-bin-ubuntu-x64.tar.gz` |
| Binary name | `llama-cli.exe` | `llama-cli` |
| SmartScreen | `Unblock-File` called automatically | N/A |
| Agent module | `powershell/modules/dotfiles-agent.psm1` | `shell/lib/agent.sh` |
| ARM64 support | ✅ (`win-cpu-arm64` asset) | ❌ (linux-arm64 not pinned yet) |

#### Common pitfalls

- **"Agent module not found"** — run `dotfiles agent --setup` first; it must complete successfully.
- **Slow first call** — 5–8 s is normal for cold start. Subsequent calls in the same session are not cached (one-shot).
- **`explain` vs `agent`** — use `dotfiles explain` for alias/tool lookups (instant, offline, no model). Use `dotfiles agent` for free-form shell command generation.

---

### `skills`

**One-line summary:** List, locate, and install portable SKILL.md guides into any project.

#### Syntax

```
dotfiles skills list
dotfiles skills path
dotfiles skills install
dotfiles skills install <target>
```

#### What it does

Skills are portable Markdown guides (each in a `SKILL.md` file inside a named directory under `skills/`) that teach AI agents architectural knowledge about the repo. They can be copied into any project so that Copilot and other AI tools pick them up.

#### Subcommands

##### `skills list`

Scans `skills/*/SKILL.md`, extracts the `description:` front-matter field from each, and prints a formatted table.

```powershell
dotfiles skills list
```

```
Available skills in skills/

  bootstrap-idempotency          Marker guards, backup strategy, re-run safety
  dotfiles-architecture          Load contract, thin-stub pattern, module boundaries
  dotfiles-cli-extension         Adding subcommands to dotfiles CLI (both shells)
  packages-and-tooling           winget/scoop/apt schemas, idempotent install patterns
  powershell-config              PSReadLine, Oh My Posh, alias functions, module guards
  shell-parity                   POSIX-first rules, bash/zsh divergence, common.sh patterns
```

##### `skills path`

Prints the absolute path of the `skills/` directory.

```powershell
dotfiles skills path
# C:\Users\you\dotfiles\skills
```

Useful for scripts that need to reference skill files directly.

##### `skills install [target]`

Copies **all** skills into `<target>/.copilot/skills/`, creating the directory if it does not exist. Each skill directory is copied recursively. The operation is safe to re-run (overwrites with `-Force`/`cp -R`).

- **Default `target`** = current working directory.
- **Custom `target`** = any directory path.

```powershell
# Install into the current project
dotfiles skills install

# Install into a specific project
dotfiles skills install C:\Projects\myapp
#   ✓ bootstrap-idempotency
#   ✓ dotfiles-architecture
#   ✓ dotfiles-cli-extension
#   ✓ packages-and-tooling
#   ✓ powershell-config
#   ✓ shell-parity
#
#   6 skill(s) installed → C:\Projects\myapp\.copilot\skills
```

```bash
# bash/zsh
dotfiles skills install
dotfiles skills install ~/projects/myapp
```

#### Platform notes

| | PowerShell | bash/zsh |
|---|---|---|
| Destination separator | `\` | `/` |
| Directory creation | `New-Item -Force` | `mkdir -p` |
| Copy | `Copy-Item -Recurse -Force` | `cp -R` |

The destination path format (`<target>/.copilot/skills/`) is the same on both platforms.

---

## Workflows / Recipes

### Recipe 1: Set up a fresh machine

```powershell
# Windows — one-liner bootstrap
irm https://raw.githubusercontent.com/jmanuelcorral/dotfiles/master/bootstrap/install.ps1 | iex

# Verify everything is wired
dotfiles version
dotfiles help
```

```bash
# Linux/WSL/macOS
curl -fsSL https://raw.githubusercontent.com/jmanuelcorral/dotfiles/master/bootstrap/install.sh | bash

dotfiles version
dotfiles help
```

---

### Recipe 2: Add and register a personal script

```powershell
# 1. Create your script in bin/
New-Item bin\gituseswitch.ps1
# (edit the file)

# 2. Register it
dotfiles register gituseswitch -Description "Switch git user identity"

# 3. Confirm it's visible
dotfiles list
dotfiles explain gituseswitch
```

On Unix, after running the PowerShell register step (or editing `shared/tools.json` manually), the Unix `dotfiles list` and `dotfiles explain` commands will pick up the entry automatically — they share the same `shared/tools.json`.

---

### Recipe 3: Find a command you forgot

```powershell
# Option A: Interactive fuzzy search
dotfiles help
# Type "stash" → see all stash entries instantly

# Option B: Keyword filter
dotfiles help rebase

# Option C: Look up a specific alias
dotfiles explain gl
#   gl — git log --oneline --graph --decorate
```

---

### Recipe 4: Set up the local AI agent

```powershell
# Windows
dotfiles agent --setup
# Downloads ~1 GB model to cache/models/

# Low-RAM machine? Use the 0.5B fallback (~469 MB)
dotfiles agent --setup --fallback

# Try it
dotfiles agent "show git log for the last 5 commits as a graph"
```

```bash
# Linux/WSL/macOS — identical syntax
dotfiles agent --setup
dotfiles agent "list all docker containers including stopped ones"
```

---

### Recipe 5: Install skills into another project

```powershell
# cd into your target project first, then:
dotfiles skills install
# All skills copied to ./.copilot/skills/

# Or pass an absolute path
dotfiles skills install C:\Projects\myapp
```

---

### Recipe 6: Update dotfiles to the latest version

```powershell
dotfiles update
# Reports old → new version, shows changelog, reruns installer, reloads profile.
```

---

## Cross-references

- [Command index / README](README.md) — quick-reference table and guide links
- [Cheatsheet](../cheatsheet.md) — the content that powers `dotfiles help`
- [Repository README](../../README.md) — installation one-liners and overview
- [Architecture](../ARCHITECTURE.md) — load contract, stub pattern, directory layout
- `shared/aliases.json` — cross-shell alias source of truth (read by `explain`)
- `shared/tools.json` — registered tool registry (read by `list`, `help`, `explain`)
- `shared/agent-config.json` — agent engine + model configuration
- `skills/README.md` — how to author and publish skills
