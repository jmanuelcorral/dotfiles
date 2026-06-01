# Oracle — History

## Seed Context

- **Project:** dotfiles — portable terminal/shell configuration repo
- **Stack:** PowerShell (latest), Git, Python, Node.js, bash/zsh (WSL), Oh My Posh
- **Goals:** research best-in-class terminal tooling; recommendations must be portable and install cleanly on fresh machines.
- **Requested by:** Copilot (git user.name)

## Learnings

### 2026-06-01 — Terminal Tooling Research

- **Prompt engines:** Oh My Posh wins on Windows/PowerShell (native APIs, richer themes, right-prompt). Starship wins in WSL/Linux (fastest async, single config across all shells). Recommendation: use both — OMP on PowerShell, Starship in WSL.
- **CLI replacements:** All 12 tools researched have winget IDs and scoop names. eza, bat, fd, zoxide are the non-negotiable must-haves. delta, jq, yq are high-value additions. dust/duf/procs/sd are optional quality-of-life.
- **PowerShell modules:** PSReadLine `HistoryAndPlugin` + `ListView` is the key predictive intellisense config. Terminal-Icons requires a Nerd Font. PSFzf provides Ctrl+T / Ctrl+R fuzzy pickers.
- **Package management:** `winget export/import` gives declarative reproducible Windows installs. Scoop covers CLI tools with `scoop install` one-liners. On WSL, apt covers most tools; cargo covers what apt misses.
- **Fonts:** `oh-my-posh font install CaskaydiaCove` installs without admin rights. CaskaydiaCove Nerd Font Mono is the best default for Windows Terminal.
- **Dotfiles management:** chezmoi is the recommended approach for Windows+WSL — native templating, one-liner bootstrap from GitHub, secrets support, idempotent apply. Bare-git is viable for minimalists but requires manual Windows/WSL path handling.
