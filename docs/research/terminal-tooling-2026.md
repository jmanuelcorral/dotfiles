# Terminal Tooling Report — 2026 Edition

> **Author:** Oracle (Research / Tooling Scout)  
> **Date:** 2026-06-01  
> **Requested by:** Copilot (josecorral)  
> **Scope:** Windows (PowerShell 7.6) + WSL (bash/zsh) portable setup  

---

## TL;DR — Recommended Stack

**Keep Oh My Posh** on Windows PowerShell. Install the 12 modern CLI replacements. Add 4 PowerShell modules. Use `chezmoi` for dotfiles management and `winget import` for declarative package installs. Total setup time on a fresh machine: ~10 minutes.

---

## 1. Prompt Engines: Oh My Posh vs Starship

### Comparison

| Criterion | Oh My Posh | Starship |
|-----------|-----------|----------|
| Language | Go | Rust |
| Windows / PowerShell integration | ⭐⭐⭐ Native APIs, deepest integration | ⭐⭐ Very good |
| Cross-shell portability | ⭐⭐ Bash, Zsh, Fish, PS | ⭐⭐⭐ All above + Nushell, Elvish |
| Single config across all shells | ❌ Per-shell init | ✅ One `starship.toml` |
| Startup speed (large Git repo) | Fast (async optional) | Fastest (async by default) |
| Theme ecosystem | 100+ built-in themes | Fewer built-in, highly modular |
| Right-prompt / secondary prompt | ✅ | Limited |
| Config format | JSON / YAML | TOML |
| WSL config sharing with Windows | ❌ Separate install, separate config | ✅ Same binary + same config |
| Maintenance status (2026) | Active, weekly releases | Active, large community |

### Recommendation

**Stay with Oh My Posh on Windows PowerShell.** You are already invested, the themes are richer, and Windows integration is best-in-class.

**Add Starship inside WSL only** (where "one config everywhere" matters more than Windows-specific features). This gives you:
- Oh My Posh on PowerShell 7.6 (Windows) — richer prompt, right-aligned segments, deep Windows API hooks
- Starship on bash/zsh (WSL) — lightning fast, zero extra config when moving between Linux machines

> ⚠️ **Don't run both in the same shell.** Pick one per environment.

```powershell
# Windows — Oh My Posh (already installed, keep as-is)
oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\jandedobbeleer.omp.json" | Invoke-Expression
```

```bash
# WSL — install Starship
curl -sS https://starship.rs/install.sh | sh
# Add to ~/.bashrc or ~/.zshrc:
eval "$(starship init bash)"
```

---

## 2. Modern CLI Replacements

### Quick Reference

| Tool | Replaces | Priority | Windows (winget) | Windows (scoop) | Linux/WSL |
|------|----------|----------|-----------------|-----------------|-----------|
| **eza** | `ls` | 🔴 Must-have | `winget install eza-community.eza` | `scoop install eza` | `apt install eza` / `cargo install eza` |
| **bat** | `cat` | 🔴 Must-have | `winget install Sharkdp.bat` | `scoop install bat` | `apt install bat` |
| **fd** | `find` | 🔴 Must-have | `winget install Sharkdp.fd` | `scoop install fd` | `apt install fd-find` |
| **ripgrep (rg)** | `grep` | 🔴 Must-have | ✅ Already installed | ✅ Already installed | `apt install ripgrep` |
| **zoxide** | `cd` | 🔴 Must-have | `winget install ajeetdsouza.zoxide` | `scoop install zoxide` | `apt install zoxide` / `cargo install zoxide` |
| **fzf** | interactive filter | 🔴 Must-have | ✅ Already installed | ✅ Already installed | `apt install fzf` |
| **delta** | `git diff` | 🟡 Nice | `winget install dandavison.delta` | `scoop install delta` | `cargo install git-delta` |
| **jq** | JSON processor | 🟡 Nice | `winget install jqlang.jq` | `scoop install jq` | `apt install jq` |
| **yq** | YAML processor | 🟡 Nice | `winget install mikefarah.yq` | `scoop install yq` | `snap install yq` / `brew install yq` |
| **dust** | `du` | 🟢 Optional | `winget install Bootandy.dust` | `scoop install dust` | `cargo install du-dust` |
| **duf** | `df` | 🟢 Optional | `winget install muesli.duf` | `scoop install duf` | `apt install duf` |
| **procs** | `ps` | 🟢 Optional | `winget install dalance.procs` | `scoop install procs` | `cargo install procs` |
| **sd** | `sed` | 🟢 Optional | `winget install chmln.sd` | `scoop install sd` | `cargo install sd` |

### Tool Details

#### eza — ls replacement ⭐ Must-have
```powershell
# After install, add to $PROFILE:
Set-Alias ls eza
function ll { eza --long --icons --git @args }
function la { eza --long --all --icons --git @args }
function lt { eza --tree --icons --git @args }
```
- Git status columns, file icons (requires Nerd Font), color coding by type
- Fast even on huge directories; actively maintained

#### bat — cat replacement ⭐ Must-have
```powershell
# After install, add to $PROFILE:
Set-Alias cat bat
# bat auto-detects language for syntax highlighting
```
- Syntax highlighting, line numbers, Git diff markers, pager integration
- Works as `MANPAGER` in WSL: `export MANPAGER="sh -c 'col -bx | bat -l man -p'"`

#### fd — find replacement ⭐ Must-have
```powershell
# Usage examples:
fd *.ps1            # find all PowerShell files
fd -e py src/       # find .py files in src/
fd --hidden .git    # find hidden files
```
- Respects `.gitignore` by default, 5–10× faster than `find`

#### zoxide — smart cd ⭐ Must-have
```powershell
# Add to $PROFILE (after installing zoxide):
Invoke-Expression (& { (zoxide init powershell | Out-String) })
# Usage: z dotfiles  (jumps to last-visited dir matching "dotfiles")
```
```bash
# WSL — add to .bashrc/.zshrc:
eval "$(zoxide init bash)"
```

#### delta — git diff viewer 🟡 Nice
```gitconfig
# Add to ~/.gitconfig:
[core]
    pager = delta
[interactive]
    diffFilter = delta --color-only
[delta]
    navigate = true
    side-by-side = true
    line-numbers = true
```
- Side-by-side diffs, syntax-highlighted, works with `git log -p`, `git show`, `git blame`

#### jq / yq — JSON/YAML processors 🟡 Nice
```bash
# Query JSON:  jq '.users[].name' data.json
# Query YAML:  yq '.services.web.image' docker-compose.yml
# Convert JSON → YAML:  cat file.json | yq -P
```

---

## 3. PowerShell Modules

### Recommended Module Set

| Module | Purpose | Priority | Install |
|--------|---------|----------|---------|
| **PSReadLine** | Predictive intellisense, history search | 🔴 Must-have | `Install-Module PSReadLine -Force` |
| **Terminal-Icons** | File/folder icons in `ls`/`dir` output | 🔴 Must-have | `Install-Module Terminal-Icons` |
| **posh-git** | Git status in prompt + tab completions | 🔴 Must-have | `Install-Module posh-git` |
| **PSFzf** | fzf integration (Ctrl+T, Ctrl+R) | 🟡 Nice | `Install-Module PSFzf` |
| **CompletionPredictor** | Plugin-based predictions (PSReadLine) | 🟢 Optional | via `Az.Tools.Predictor` for Azure |

### Recommended $PROFILE snippet

```powershell
# ── Modules ──────────────────────────────────────────────────────────────────
Import-Module PSReadLine
Import-Module Terminal-Icons
Import-Module posh-git

# ── PSReadLine: predictive intellisense ──────────────────────────────────────
Set-PSReadLineOption -PredictionSource HistoryAndPlugin
Set-PSReadLineOption -PredictionViewStyle ListView
Set-PSReadLineKeyHandler -Key UpArrow   -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
Set-PSReadLineKeyHandler -Key Tab       -Function MenuComplete

# ── PSFzf ────────────────────────────────────────────────────────────────────
Import-Module PSFzf
Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t'   # fuzzy file picker
Set-PsFzfOption -PSReadlineChordReverseHistory 'Ctrl+r'  # fuzzy history

# ── zoxide ────────────────────────────────────────────────────────────────────
Invoke-Expression (& { (zoxide init powershell | Out-String) })

# ── Oh My Posh ───────────────────────────────────────────────────────────────
oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\jandedobbeleer.omp.json" | Invoke-Expression

# ── Aliases (Linux-style) ─────────────────────────────────────────────────────
Set-Alias ls  eza
Set-Alias cat bat
function ll { eza --long --icons --git @args }
function la { eza --long --all --icons --git @args }
function lt { eza --tree --icons @args }
function grep { rg @args }
function find { fd @args }
```

> **Note:** `PSReadLine` ships with PowerShell 7. Run `Update-Module PSReadLine` to get latest predictive features. The `HistoryAndPlugin` source uses both history and any installed predictor plugins (e.g. `Az.Tools.Predictor`).

---

## 4. Package Management for Portability

### Windows: winget declarative installs

```powershell
# Export current installs (run once on a configured machine):
winget export -o "$HOME\dotfiles\windows\winget-packages.json" --include-versions

# Import on a fresh machine (idempotent — skips already-installed):
winget import -i "$HOME\dotfiles\windows\winget-packages.json" --ignore-unavailable
```

**Scoop** complements winget for CLI tools not in the winget catalog:
```powershell
# Add buckets once:
scoop bucket add extras
scoop bucket add nerd-fonts

# Install a curated list:
scoop install eza bat fd zoxide delta dust duf procs sd jq yq
```

Store `winget-packages.json` and a `scoop-install.ps1` script in your dotfiles repo.

### WSL / Linux: apt + cargo + brew

```bash
# Debian/Ubuntu apt (fast, most tools available):
sudo apt update && sudo apt install -y \
  bat fd-find ripgrep fzf zoxide jq duf eza

# Note: on older Ubuntu, bat is installed as batcat — create alias:
mkdir -p ~/.local/bin && ln -s $(which batcat) ~/.local/bin/bat

# Tools missing from apt — use cargo (Rust) or brew:
cargo install git-delta du-dust procs sd
# OR with Homebrew on Linux:
brew install git-delta dust procs sd yq
```

### One-command bootstrap pattern

```powershell
# Windows — run from any machine after cloning dotfiles:
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
irm https://raw.githubusercontent.com/josecorral/dotfiles/main/bootstrap.ps1 | iex
```

```bash
# WSL/Linux — same repo:
bash <(curl -fsSL https://raw.githubusercontent.com/josecorral/dotfiles/main/bootstrap.sh)
```

---

## 5. Windows Terminal & Fonts

### Why Nerd Fonts are Required

Oh My Posh themes and `eza --icons` / `Terminal-Icons` all render glyphs from Nerd Fonts. Without them you see boxes/question marks.

### Recommended Font

**CaskaydiaCove Nerd Font** (based on Cascadia Code, Microsoft's own font — best Windows Terminal default):

```powershell
# Install via oh-my-posh built-in font installer (easiest, admin not required for user fonts):
oh-my-posh font install CaskaydiaCove

# OR via Scoop (requires admin for system-wide):
scoop bucket add nerd-fonts
scoop install nerd-fonts/CaskaydiaCove-NF
```

### Windows Terminal settings.json snippet

```json
{
  "profiles": {
    "defaults": {
      "font": {
        "face": "CaskaydiaCove Nerd Font Mono",
        "size": 11
      }
    }
  }
}
```

> **Tip:** Store `settings.json` in your dotfiles and symlink/copy it during bootstrap:  
> `$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json`

### Reproducible font install in bootstrap script

```powershell
# bootstrap.ps1
oh-my-posh font install CaskaydiaCove   # installs to user fonts, no admin needed
```

---

## 6. Dotfiles Management Patterns

### Approaches Compared

| Approach | Portability | Complexity | Windows+WSL | Secrets | Verdict |
|----------|------------|-----------|------------|---------|---------|
| **chezmoi** | ⭐⭐⭐ | Medium | ✅ Native | ✅ Built-in | **Recommended** |
| Bare git repo | ⭐⭐ | Low (if Git-literate) | ⚠️ Manual | ❌ None | Good for minimalists |
| Symlink farm (stow) | ⭐⭐ | Medium | ❌ Windows hostile | ❌ None | Avoid on Windows |
| Simple clone + script | ⭐ | Low | ⚠️ Fragile | ❌ None | OK for single-OS |

### Recommendation: chezmoi

**chezmoi** is the clear winner for a Windows + WSL developer:
- Single binary (Go), installs anywhere with one command
- Templates let you write OS-conditional config (e.g. different `$PROFILE` paths on Windows vs WSL)
- `chezmoi apply` is idempotent — safe to re-run
- One-liner bootstrap from GitHub:

```bash
# WSL / Linux bootstrap:
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply josecorral

# Windows bootstrap (PowerShell):
(irm -Uri https://get.chezmoi.io/ps1) | powershell -c -
chezmoi init --apply josecorral
```

### chezmoi repo structure for Windows+WSL

```
dotfiles/
├── dot_gitconfig           → ~/.gitconfig (both)
├── dot_config/
│   └── starship.toml       → ~/.config/starship.toml (WSL)
├── windows/
│   ├── winget-packages.json
│   └── Microsoft.PowerShell_profile.ps1   → $PROFILE
├── bootstrap.ps1           → Windows one-liner setup
├── bootstrap.sh            → WSL/Linux one-liner setup
└── .chezmoi.toml.tmpl      → per-machine config template
```

### Minimal bootstrap without chezmoi (backup option)

```powershell
# bootstrap.ps1 — pure git + script, no extra tools
git clone https://github.com/josecorral/dotfiles "$HOME\.dotfiles"
winget import -i "$HOME\.dotfiles\windows\winget-packages.json" --ignore-unavailable
scoop bucket add extras nerd-fonts
scoop install eza bat fd zoxide delta jq yq
oh-my-posh font install CaskaydiaCove
Copy-Item "$HOME\.dotfiles\windows\Microsoft.PowerShell_profile.ps1" $PROFILE
```

---

## Recommended Stack — Final Summary

### Priority Tiers

| Tier | Tools |
|------|-------|
| 🔴 **Install immediately** | eza, bat, fd, zoxide, PSReadLine (update), Terminal-Icons, posh-git |
| 🟡 **Install this week** | delta, jq, yq, PSFzf |
| 🟢 **Install when needed** | dust, duf, procs, sd, CompletionPredictor/Az predictor |

### Windows — Full Install Commands

```powershell
# 1. CLI tools via winget
winget install eza-community.eza Sharkdp.bat Sharkdp.fd ajeetdsouza.zoxide `
              dandavison.delta jqlang.jq mikefarah.yq Bootandy.dust `
              muesli.duf dalance.procs chmln.sd

# 2. PowerShell modules
Install-Module PSReadLine -Force -Scope CurrentUser
Install-Module Terminal-Icons -Force -Scope CurrentUser
Install-Module posh-git -Force -Scope CurrentUser
Install-Module PSFzf -Force -Scope CurrentUser

# 3. Nerd Font
oh-my-posh font install CaskaydiaCove
```

### WSL / Linux — Full Install Commands

```bash
# 1. apt packages
sudo apt update && sudo apt install -y bat fd-find ripgrep fzf zoxide eza jq duf

# 2. cargo packages (tools not in apt)
cargo install git-delta du-dust procs sd

# 3. yq (mikefarah)
wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
chmod +x /usr/local/bin/yq

# 4. Starship prompt
curl -sS https://starship.rs/install.sh | sh

# 5. chezmoi (to manage dotfiles)
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply josecorral
```

### WSL Shell Config (~/.zshrc or ~/.bashrc)

```bash
# zoxide
eval "$(zoxide init zsh)"    # or bash

# Starship
eval "$(starship init zsh)"  # or bash

# Aliases
alias ls='eza --icons'
alias ll='eza -l --icons --git'
alias la='eza -la --icons --git'
alias lt='eza --tree --icons'
alias cat='bat'
alias find='fd'
alias grep='rg'
alias cd='z'   # zoxide
```

---

*Report generated by Oracle (Research / Tooling Scout) · 2026-06-01*
