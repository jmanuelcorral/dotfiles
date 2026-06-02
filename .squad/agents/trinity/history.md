# Trinity — History

## Seed Context

- **Project:** dotfiles — portable terminal/shell configuration repo
- **Stack:** PowerShell (latest), Git, Python, Node.js, Oh My Posh
- **Goals:** modular fast $PROFILE; Linux-style aliases; PSReadLine config; fix Oh My Posh errors. Profile must guard missing tools so it never breaks on a fresh machine.
- **Requested by:** Copilot (git user.name)

## Learnings

### 2026-06-01 — Initial PowerShell config implementation

**Oh My Posh fix**
- Old profile pointed at `C:\Users\josecorral\poshv3.json` which didn't exist → startup error every time.
- Fix: ship the theme inside the repo at `powershell/themes/dotfiles.omp.json`.
- `prompt.ps1` resolves the path via `$env:DOTFILES` — zero hardcoded user paths.
- Fallback chain: repo theme → `$env:POSH_THEMES_PATH\jandedobbeleer.omp.json` → plain-text prompt.

**PSReadLine VT guard**
- `Set-PSReadLineOption -PredictionViewStyle ListView` throws in non-VT consoles (e.g. pwsh -NoProfile in a test runner).
- Guard: check `$Host.UI.RawUI.WindowSize.Width -gt 0` before enabling ListView; always safe to skip in non-interactive.

**Key file paths**
- `powershell/profile.ps1` — main entry, dot-sources everything in order
- `powershell/aliases.ps1` — Linux-style wrappers + git shortcuts
- `powershell/psreadline.ps1` — PSReadLine modern config (VT-guarded)
- `powershell/prompt.ps1` — OMP init, guarded, no hardcoded paths
- `powershell/completions.ps1` — winget, dotnet, gh, posh-git, zoxide, PSFzf
- `powershell/themes/dotfiles.omp.json` — custom clean Nerd Font theme (Tokyo Night palette)
- `shared/aliases.json` — canonical cross-shell alias catalog (Trinity + Tank read this)

**Modules auto-load**
- `powershell/modules/*.ps1` are dot-sourced alphabetically after the 4 core files; safe to add drop-ins.

**All guards**
- Every external tool uses `Get-Command X -ErrorAction SilentlyContinue` before use.
- Profile is safe on a fresh machine with nothing installed.

### 2026-06-02 — Upcoming: Local AI Agent Feature

**Context:** Oracle has researched local SLM backends (recommending Ollama + Phi-4-mini-instruct), and Morpheus has architected a 6-phase implementation plan. Once Jose approves, Trinity will own Phase 2 (PowerShell agent wrapper). The `dotfiles agent "<query>"` command will allow users to ask questions about aliases/tools with AI assistance, and `dotfiles explain <cmd>` will enhance command documentation. Trinity's responsibilities in Phase 2 will include PowerShell bindings to the Ollama localhost:11434 REST API and graceful degradation when the model is unavailable.

