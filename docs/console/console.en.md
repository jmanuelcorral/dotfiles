# Working in the Console — Developer Guide (English)

> Date: 2026-06-05  
> [← Back to index](README.md) · [Español](console.es.md)

---

## Table of Contents

1. [Philosophy](#philosophy)
2. [Navigating & Listing Files](#navigating--listing-files)
3. [Viewing & Inspecting Files](#viewing--inspecting-files)
4. [Searching Code & Files](#searching-code--files)
5. [Fuzzy Finding Everything](#fuzzy-finding-everything)
6. [Jumping Around (zoxide)](#jumping-around-zoxide)
7. [Git Day-to-Day](#git-day-to-day)
8. [GitHub from the Terminal](#github-from-the-terminal)
9. [Working with JSON / YAML](#working-with-json--yaml)
10. [System & Processes](#system--processes)
11. [Node Versions (volta)](#node-versions-volta)
12. [Your Prompt](#your-prompt)
13. [Cross-Shell Convenience Aliases](#cross-shell-convenience-aliases)
14. [Recipes — Real Workflows](#recipes--real-workflows)
15. [Cheat-Sheet Table](#cheat-sheet-table)
16. [Learn More](#learn-more)

---

## Philosophy

This dotfiles repo installs a set of **modern CLI tools** that replace the classic Unix utilities you already know — but they are faster, smarter, and friendlier. The key insight is that the same aliases work identically whether you are on **Windows PowerShell 7+** or **bash/zsh on Linux/macOS/WSL2**. The tools are wired so that typing `ll`, `cat`, `find`, `grep`, or `cd` transparently uses the modern replacement when it is installed, and falls back gracefully to the platform default when it is not.

The goal: you should not have to think about which OS you are on. Open a terminal and start working.

> **Platform callouts** appear throughout this guide as:  
> 🪟 **Windows** — PowerShell-specific notes  
> 🐧 **Unix/WSL** — bash/zsh-specific notes

---

## Navigating & Listing Files

### `eza` — modern `ls`

**Replaces:** `ls`, `dir`  
**What it adds:** Icons (Nerd Font), Git status columns, colour-coded file types, tree view, `.gitignore`-aware listing.

The following aliases are defined in `shared/aliases.json` and work on both platforms:

| Alias | Expands to | What it does |
|---|---|---|
| `ls` | `eza --icons --group-directories-first` | Default listing, dirs first |
| `ll` | `eza -la --icons --group-directories-first` | Long listing with hidden files |
| `la` | `eza -a --icons` | All files including dotfiles (compact) |
| `l` | `eza --icons` | Compact listing |
| `lt` | `eza --tree --level=2 --icons` | Tree view, 2 levels deep |

#### Examples

```bash
# Standard listing — dirs grouped first, icons for file types
ls

# Long listing with permissions, size, date, hidden files
ll

# Show all dotfiles in current dir
la

# Tree view of current directory (2 levels)
lt

# Tree view of a specific path, 3 levels deep
eza --tree --level=3 src/

# Sort by file size descending
eza -la --sort=size --reverse

# Show git status column (branch, modified, staged)
eza -la --git
```

#### Expected output (ll)

```
drwxr-xr-x  - user  3 Jun 10:00 📁 src
drwxr-xr-x  - user  3 Jun 09:00 📁 node_modules
.rw-r--r-- 1.2k user  3 Jun 10:05 📄 package.json
.rw-r--r--  432 user  2 Jun 15:00 📄 README.md
```

> 🪟 **Windows:** Falls back to `Get-ChildItem -Force` if eza is not found.  
> 🐧 **Unix:** Falls back to `ls -la` / `ls --color=auto`.

---

## Viewing & Inspecting Files

### `bat` — `cat` with syntax highlighting

**Replaces:** `cat`  
**What it adds:** Syntax highlighting for 200+ languages, line numbers, git diff indicators, paging.

The `cat` alias expands to `bat --style=plain` (clean output, no line numbers or borders — pipe-friendly).

#### Examples

```bash
# View a file (alias: plain output, no decorations)
cat package.json

# View with line numbers and git change markers
bat -n package.json

# View with full UI (line numbers + file header + grid)
bat --style=full README.md

# Choose a theme
bat --theme=TwoDark src/index.ts

# List all available themes
bat --list-themes

# Compare two versions of a file (diff output highlighted)
bat --diff src/utils.ts

# Page through a large file
bat --paging=always server.log

# Highlight a specific range of lines
bat -r 10:30 src/index.ts
```

> 🪟 **Windows:** `bat` is available as `bat`. No binary quirks.  
> 🐧 **Unix:** On Ubuntu < 22.04 the binary is installed as `batcat`; `bootstrap/install.sh` creates a `~/.local/bin/bat` symlink so the alias just works.

#### Power combo — bat as fzf previewer

```bash
# Preview files interactively (see also: fzf section)
fzf --preview 'bat --color=always --style=numbers {}'
```

---

## Searching Code & Files

### `ripgrep` (`rg`) — fast `grep`

**Replaces:** `grep`  
**What it adds:** Dramatically faster searches, respects `.gitignore` by default, coloured matches, file-type filters.

The `grep` alias expands to `rg` on both platforms.

#### Examples

```bash
# Basic search — all files in current directory tree
grep "TODO"

# Case-insensitive
grep -i "fixme"

# Search in specific file types only
rg "useState" -g "*.tsx"
rg "import" -g "*.{ts,tsx}"

# Show 2 lines of context before and after each match
rg "error" -C 2

# Only before / only after
rg "throw" -B 3
rg "catch" -A 5

# Search for a regex pattern
rg "fn\s+\w+\(" --type rust

# List only file names that contain the pattern
rg -l "TODO"

# Count matches per file
rg -c "import"

# Invert match — lines that do NOT contain the pattern
rg -v "test" src/

# Search including files normally ignored by .gitignore
rg --no-ignore "secret"

# Output raw string, no colour (useful in scripts)
rg -N --no-heading "version" package.json
```

#### Power combo — rg into fzf

```bash
# Interactively search results and jump to file:line
rg --line-number "" | fzf --delimiter ':' --preview 'bat --color=always {1} -r {2}:'
```

---

### `fd` — fast `find`

**Replaces:** `find`  
**What it adds:** Intuitive syntax, `.gitignore`-aware, parallel execution, regex/glob patterns.

The `find` alias expands to `fd`.

#### Examples

```bash
# Find all TypeScript files
find -e ts

# Find files by name pattern
find "config"

# Find in a specific directory
find -e json packages/

# Find directories only
find -t d src

# Find files modified in the last 2 days
find --changed-within 2d

# Find and execute a command on each result
find -e log --exec rm {}

# Case-sensitive search
find -s "README"

# Include hidden files and ignored files
find -HI ".env"
```

> 🐧 **Unix:** On Debian/Ubuntu the apt package installs the binary as `fdfind`; `bootstrap/install.sh` creates a `~/.local/bin/fd` symlink so the `find` alias works transparently.

#### Power combo — fd into fzf

```bash
# Interactively pick a TypeScript file and open it
fd -e ts | fzf --preview 'bat --color=always {}'
```

---

## Fuzzy Finding Everything

### `fzf` — interactive fuzzy finder

**What it is:** A universal fuzzy-search interface for anything that outputs lines of text.  
**Shell integration:** Automatically wired by the profiles — no configuration needed after install.

#### Key bindings (wired automatically)

| Key | Action |
|---|---|
| `Ctrl+R` | Interactive fuzzy search over command history |
| `Ctrl+T` | Fuzzy file picker — inserts selected path at cursor |
| `Alt+C` | Fuzzy `cd` into a subdirectory |

#### Standalone usage

```bash
# Pick from a list of files
fzf

# Pick with bat preview
fzf --preview 'bat --color=always --style=numbers {}'

# Pipe any list into fzf
echo -e "option1\noption2\noption3" | fzf

# Multi-select (Tab to mark, Enter to confirm)
fd -e ts | fzf -m

# Pass selected file to an editor
code $(fzf --preview 'bat --color=always {}')
```

#### History search (`Ctrl+R`)

Press `Ctrl+R` in your shell. A full-screen fuzzy list of your command history appears. Type to filter; press Enter to execute the selected command.

```
> git push
  git push origin main
  git push --force-with-lease
  git push --set-upstream origin feature/my-branch
```

#### Power combos

```bash
# Search code with rg, preview matches with bat
rg --line-number "TODO" | fzf \
  --delimiter ':' \
  --preview 'bat --color=always --highlight-line {2} {1}'

# Kill a process interactively
ps aux | fzf | awk '{print $2}' | xargs kill

# Checkout a git branch interactively
git branch | fzf | xargs git checkout

# Pick and open a recently modified file
fd --changed-within 7d | fzf --preview 'bat --color=always {}'
```

---

## Jumping Around (zoxide)

### `zoxide` — smart `cd`

**Replaces:** `cd` for frequent directories  
**What it adds:** Frecency-based directory jumping — it learns which directories you visit most and lets you jump there with a partial name.

Shell integration is wired automatically by the profiles (`zoxide init` runs on startup).

#### Commands

```bash
# Jump to the most frecent directory matching "dotfiles"
z dotfiles

# Jump to the most frecent directory matching "src" under "myproject"
z myproject src

# Interactive jump with fzf (zi = zoxide interactive)
zi

# Add current directory manually to the database
zoxide add .

# Show the database (all tracked directories + scores)
zoxide query --list

# Remove a directory from the database
zoxide remove /path/to/old/dir
```

#### Workflow

The first time you `cd` into a directory, zoxide starts tracking it. After a few visits, `z <partial>` will jump directly there:

```bash
cd ~/projects/my-awesome-app      # first visit — tracked
# ... work for a few days ...
z awesome                          # → jumps to ~/projects/my-awesome-app
```

> 🐧 **Unix:** Available in Ubuntu 22.10+ via apt; older systems get zoxide via the official install script (handled automatically by `bootstrap/install.sh`).

---

## Git Day-to-Day

### Git shortcuts (from `shared/aliases.json`)

All git aliases work identically on Windows and Unix:

| Alias | Expands to | When to use |
|---|---|---|
| `g` | `git` | Short git prefix |
| `gst` | `git status` | Check what's changed |
| `ga` | `git add` | Stage files |
| `gc` | `git commit` | Commit (add `-m "msg"` or open editor) |
| `gp` | `git push` | Push to remote |
| `gl` | `git log --oneline --graph --decorate` | Visual history |
| `gd` | `git diff` | Unstaged changes |

#### Examples

```bash
# Full daily workflow
gst                          # what changed?
ga src/feature.ts            # stage specific file
ga .                         # stage everything
gc -m "feat: add widget"     # commit with message
gp                           # push

# Pretty history graph
gl

# Diff staged changes
gd --staged

# Diff against main branch
gd main

# Stash and restore
g stash
g stash pop
```

### `delta` — better git diffs

**Replaces:** The built-in git pager  
**What it adds:** Syntax highlighting, line numbers, side-by-side view, improved merge-conflict display.

Delta is configured as git's pager automatically. You don't invoke it directly — it powers every `git diff`, `git log -p`, and `git show`.

```bash
# These all use delta automatically:
gd                           # unstaged diff
gd --staged                  # staged diff
git log -p                   # commit history with patches
git show HEAD                # last commit
git show abc1234             # specific commit

# Side-by-side diff (if not already configured)
git diff --word-diff
```

#### Expected output

```diff
───────────────────────────────────────────
File: src/index.ts
───────────────────────────────────────────
  10 │  10 │  const greeting = "hello";
  11 │     │- console.log(greeting)
     │  11 │+ console.log(greeting + "!");
  12 │  12 │
```

---

## GitHub from the Terminal

### `gh` — GitHub CLI

**What it is:** The official GitHub CLI. Manage repos, pull requests, issues, Actions runs, and more without opening a browser.

#### Authentication

```bash
# First time: authenticate
gh auth login

# Check current auth status
gh auth status
```

#### Repositories

```bash
# Clone a repo
gh repo clone owner/repo

# Create a new repo from current directory
gh repo create my-project --public

# View repo in browser
gh repo view --web
```

#### Pull Requests

```bash
# Create a PR from current branch
gh pr create --title "feat: add search" --body "Adds fuzzy search to the UI"

# Create a draft PR
gh pr create --draft

# List open PRs
gh pr list

# View a PR (current branch)
gh pr view

# Open PR in browser
gh pr view --web

# Check out a PR locally
gh pr checkout 42

# Merge a PR
gh pr merge 42 --squash
```

#### Issues

```bash
# Create an issue
gh issue create --title "Bug: login fails" --body "Steps to reproduce..."

# List issues
gh issue list
gh issue list --assignee @me

# View an issue
gh issue view 15
```

#### Actions / Workflow runs

```bash
# List recent workflow runs
gh run list

# Watch a run in real time
gh run watch

# View run logs
gh run view --log

# Re-run failed jobs
gh run rerun --failed
```

#### Power combo — gh + jq

```bash
# List PRs as JSON and extract title + number
gh pr list --json number,title | jq '.[] | "\(.number): \(.title)"' -r

# Find all open issues assigned to you
gh issue list --assignee @me --json number,title,labels | jq '.[] | .title'
```

---

## Working with JSON / YAML

### `jq` — JSON processor

**What it is:** A lightweight, flexible command-line JSON processor.

#### Examples

```bash
# Pretty-print a JSON file
jq '.' package.json

# Extract a specific field
jq '.name' package.json

# Extract nested field
jq '.scripts.build' package.json

# Get all keys at top level
jq 'keys' package.json

# Filter array elements
jq '.dependencies | keys[]' package.json

# Raw string output (no quotes)
jq -r '.version' package.json

# Build a new object from fields
jq '{name: .name, ver: .version}' package.json

# Filter array by condition
echo '[{"name":"a","active":true},{"name":"b","active":false}]' \
  | jq '[.[] | select(.active == true)]'

# Process API response
curl -s https://api.github.com/repos/sharkdp/bat/releases/latest \
  | jq '{tag: .tag_name, date: .published_at, url: .html_url}'
```

#### Power combo — gh + jq

```bash
# Show only PR titles from JSON output
gh pr list --json number,title,headRefName \
  | jq -r '.[] | "#\(.number) \(.headRefName): \(.title)"'
```

---

### `yq` — YAML / JSON / TOML processor

**What it is:** Like `jq` but works natively with YAML, JSON, and TOML (mikefarah fork).

> 🐧 **Unix/WSL only.** `yq` is installed via GitHub releases on Linux by `bootstrap/install.sh`. Not available in the Windows winget package list.

```bash
# Read a YAML field
yq '.services.web.image' docker-compose.yml

# Read multiple fields
yq '.name, .version' Chart.yaml

# Update a field in place
yq -i '.version = "2.0.0"' Chart.yaml

# Convert YAML to JSON
yq -o=json '.' docker-compose.yml | jq '.'

# Convert JSON to YAML
cat data.json | yq -P '.'

# Merge two YAML files
yq '. * load("override.yml")' base.yml
```

---

## System & Processes

### `duf` — graphical disk usage

**Replaces:** `df`  
**What it adds:** Coloured table with usage bars, mount-point grouping.

> 🐧 **Unix/WSL only.** Installed via apt on Linux. Use `df` on Windows (falls back to `Get-PSDrive`).

```bash
# Show all mount points
duf

# Show only local disks
duf --only local
```

### Disk, process, and system aliases

These aliases work on both platforms (PowerShell implementation vs Unix implementation):

| Alias | Unix command | Windows equivalent |
|---|---|---|
| `df` | `df -h` | `Get-PSDrive` |
| `du` | `du -sh` | `Get-ChildItem -Recurse \| Measure-Object -Sum Length` |
| `top` | `htop` (or `top`) | `Get-Process \| Sort-Object CPU -Descending \| Select -First 20` |
| `ps` | `ps aux` | `Get-Process` |
| `kill` | `kill <pid>` | `Stop-Process <pid>` |
| `env` | `env` | `Get-ChildItem Env:` |
| `export` | `export NAME=VALUE` | `$env:NAME = "VALUE"` |

#### Examples

```bash
# Check disk usage of current directory
du .

# Show all environment variables
env

# List running processes
ps

# Kill process by PID
kill 12345

# Set an environment variable (current session)
export NODE_ENV=production    # Unix
```

```powershell
# Windows equivalent
$env:NODE_ENV = "production"
```

### `gsudo` / `sudo` — elevation

**What it is:** Run a command with elevated privileges without leaving the terminal.

> 🪟 **Windows:** `gsudo` (alias `sudo`) elevates inline — no separate window, UAC prompt in-place.  
> 🐧 **Unix:** Standard `sudo`.

```bash
# Elevate a single command
sudo apt update          # Unix
sudo choco install ...   # Windows (via gsudo)

# Open an elevated shell
sudo -s               # Unix: root shell
sudo pwsh             # Windows: elevated PowerShell
```

---

## Node Versions (volta)

### `volta` — Node.js version manager

**Replaces:** `nvm`, `n`, `fnm`  
**What it adds:** Per-project pinning via `package.json`, no shell shims needed, works with npm/yarn/pnpm.

> 🪟 **Windows:** Installed via winget. Works in PowerShell.  
> 🐧 **Unix/WSL:** Not in `apt.json` — install separately from [volta.sh](https://volta.sh) if needed.

```bash
# Install the latest LTS Node
volta install node

# Install a specific version
volta install node@20

# Install a specific npm version
volta install npm@10

# Pin the Node version for the current project (writes to package.json)
volta pin node@20
volta pin npm@10

# Check what's installed
volta list

# Run a one-off command with a specific version
volta run --node 18 node --version
```

After `volta pin node@20`, the `package.json` will contain:

```json
{
  "volta": {
    "node": "20.x.x",
    "npm": "10.x.x"
  }
}
```

Anyone who clones the repo and has Volta installed will automatically use the pinned version — no `.nvmrc` sync dance.

---

## Your Prompt

Your shell prompt is powered by a **theme engine** that displays git status, language versions, execution time, and exit code at a glance.

> 🪟 **Windows PowerShell:** [Oh My Posh](https://ohmyposh.dev) — configured via `powershell/themes/dotfiles.omp.json`. Theme: Tokyo Night.  
> 🐧 **Unix/WSL bash/zsh:** [Starship](https://starship.rs) — installed via the official script, configured via `~/.config/starship.toml`.

Both are initialized by the profiles automatically. You don't need to do anything — just open a terminal and you'll see the styled prompt.

What your prompt shows:
- Current directory (shortened)
- Git branch + status (staged / unstaged / untracked)
- Node.js version (when inside a Node project)
- Python version (when in a venv)
- Command execution time (for commands > 2 s)
- Exit code indicator (green ✔ / red ✘)

> 🔧 Prompt theme customization is owned by the prompt config files — not covered in this guide. See `powershell/themes/` and `powershell/prompt.ps1` for the Windows side.

---

## Cross-Shell Convenience Aliases

These are all wired by `shared/aliases.json` and work on both platforms:

### Navigation

| Alias | What it does |
|---|---|
| `..` | Go up one directory |
| `...` | Go up two directories |
| `....` | Go up three directories |
| `up N` | Go up N directories (function: `up 4`) |
| `cdot` | `cd` to the dotfiles repo root (`$DOTFILES`) |
| `z <partial>` | Jump to a frecent directory (zoxide) |
| `zi` | Interactive zoxide jump (fzf) |

```bash
# Quick navigation
..              # cd ..
...             # cd ../..
....            # cd ../../..
up 4            # cd ../../../../
cdot            # cd to ~/dotfiles (or wherever $DOTFILES points)
```

### File operations

| Alias | What it does |
|---|---|
| `mkdir <path>` | Create directory including all parents (`-p` behaviour) |
| `mkcd <path>` | Create directory and `cd` into it |
| `touch <file>` | Create file or update modification time |
| `open <path>` | Open file or URL with the default application |

```bash
# Create a nested directory structure and cd into it
mkcd src/components/ui

# Open current directory in GUI file manager / Finder
open .

# Open a URL in the browser
open https://github.com
```

### Shell management

| Alias | What it does |
|---|---|
| `reload` | Reload your shell profile (picks up alias changes) |
| `which <cmd>` | Locate an executable on PATH |
| `history` | Show command history |
| `export NAME=VALUE` | Set an environment variable (Unix style) |
| `env` | List all environment variables |

```bash
# After editing shared/aliases.json and rebuilding aliases:
reload

# Find where a binary lives
which git
which node

# Search history
history | grep "docker"
```

### Text utilities

| Alias | What it does |
|---|---|
| `head -n N <file>` | Show first N lines |
| `tail -n N <file>` | Show last N lines |

```bash
# Show first 20 lines of a log
head -n 20 app.log

# Follow a log in real time (Unix)
tail -f app.log
```

---

## Recipes — Real Workflows

### 🔍 Find and edit a file fast

```bash
# 1. Use fd to list TypeScript files, fzf to pick one, open in VS Code
code $(fd -e ts | fzf --preview 'bat --color=always {}')

# 2. Alternatively — search by content, then pick match
rg -l "useEffect" | fzf --preview 'bat --color=always {}'
```

### 📜 Interactively search git history

```bash
# Search commit messages with fzf, show diff with delta
git log --oneline | fzf --preview 'git show --color=always {1}' | awk '{print $1}' | xargs git show
```

### 🌐 Explore a JSON API response

```bash
# Fetch, pretty-print, explore interactively
curl -s https://api.github.com/repos/sharkdp/bat/releases \
  | jq '.[0:5] | .[] | {tag: .tag_name, date: .published_at}' \
  | bat --language=json
```

### 🌿 Clean up merged git branches

```bash
# List merged branches, pick ones to delete interactively
git branch --merged main \
  | grep -v "^\* " \
  | fzf -m \
  | xargs git branch -d
```

### 🚀 Jump into a project and start working

```bash
# 1. Jump to the project directory via zoxide
z myapp

# 2. Check git status
gst

# 3. View recent history
gl

# 4. Start a feature
ga .
gc -m "feat: initial scaffold"
gp
```

### 🔎 Find large files in the repo

```bash
# Find files > 1MB, sorted by size
fd --size +1mb | xargs du -sh | sort -rh | head -20
```

### 📦 Inspect a package.json dependency tree

```bash
# List all direct dependencies as a table
jq -r '.dependencies | to_entries[] | "\(.key)\t\(.value)"' package.json \
  | column -t

# Check if a specific package is in devDependencies
jq '.devDependencies | has("typescript")' package.json
```

### 🏃 Watch a GitHub Actions run live

```bash
# Push and immediately watch the run
gp
gh run watch
```

---

## Cheat-Sheet Table

| Tool | Top command | What it does |
|---|---|---|
| `eza` | `ll` | Long listing with icons and hidden files |
| `bat` | `cat <file>` | Syntax-highlighted file view |
| `fd` | `find -e ts` | Find TypeScript files |
| `rg` | `grep "pattern"` | Search code fast |
| `fzf` | `Ctrl+R` | Fuzzy history search |
| `zoxide` | `z <partial>` | Jump to frecent directory |
| `delta` | *(auto, powers git diff)* | Syntax-highlighted diffs |
| `jq` | `jq '.name' file.json` | Extract JSON field |
| `yq` | `yq '.key' file.yml` | Extract YAML field (Unix) |
| `duf` | `duf` | Graphical disk usage (Unix) |
| `git`+aliases | `gl` / `gst` / `gd` | Pretty log, status, diff |
| `gh` | `gh pr create` | Create a pull request |
| `volta` | `volta install node` | Install Node.js version |
| `gsudo`/`sudo` | `sudo <cmd>` | Elevate a command |
| `oh-my-posh` | *(auto)* | Styled prompt on Windows |
| `starship` | *(auto)* | Styled prompt on Unix/WSL |

---

## Learn More

| Tool | Homepage / Docs |
|---|---|
| eza | <https://github.com/eza-community/eza> |
| bat | <https://github.com/sharkdp/bat> |
| fd | <https://github.com/sharkdp/fd> |
| ripgrep | <https://github.com/BurntSushi/ripgrep> |
| fzf | <https://github.com/junegunn/fzf> |
| zoxide | <https://github.com/ajeetdsouza/zoxide> |
| delta | <https://github.com/dandavison/delta> |
| jq | <https://stedolan.github.io/jq/manual/> |
| yq (mikefarah) | <https://github.com/mikefarah/yq> |
| duf | <https://github.com/muesli/duf> |
| Oh My Posh | <https://ohmyposh.dev> |
| Starship | <https://starship.rs> |
| gsudo | <https://github.com/gerardog/gsudo> |
| volta | <https://volta.sh> |
| gh CLI | <https://cli.github.com/manual/> |
