# Switch — History

## Seed Context

- **Project:** dotfiles — portable terminal/shell configuration repo
- **Stack:** PowerShell, winget/scoop, bash (delegates to Tank), Git, Python, Node.js
- **Goals:** one-line bootstrap install from the repo (Windows + Unix); extensible system to register the user's own tooling (e.g. gituseswitch); a CLI help/cheat tool for most-used commands. Everything idempotent.
- **Requested by:** Copilot (git user.name)

## Learnings

### 2026-06-01 — Windows Installer + dotfiles CLI

**Files created/updated:**
- `packages/winget.json` — upgraded from string array to object array with `id`, `command`, `scoop`, `description` fields
- `packages/scoop.json` — full fallback list with bucket info
- `bootstrap/install.ps1` — full implementation replacing the placeholder
- `bin/dotfiles.ps1` — new CLI tool (help/list/register/update/edit)
- `docs/cheatsheet.md` — expanded from ~25 to ~100 entries across 8 categories
- `shared/tools.json` — cleaned up _todo comment

**Key idempotency lessons:**
- `$PROFILE` is the right variable to use for the profile path — it resolves OneDrive-redirected Documents automatically. Never hardcode.
- `Get-Command <binary> -ErrorAction SilentlyContinue` is the right guard for CLI tools — it's fast and works regardless of how the tool was installed (winget, scoop, manual).
- winget exit code `-1978335189` means "already installed at requested version" — should be treated as success, not failure.
- `Select-String -Quiet` is the cleanest way to check for a marker string in a file without reading line-by-line.

**CLI design:**
- `fzf` as the interactive backend for `dotfiles help` gives a great UX with zero extra code. The plain-text fallback (coloured ANSI via `Write-Host`) works fine when fzf is absent.
- Using `[System.Collections.Generic.List[object]]` instead of `@()` + `+=` avoids the PowerShell fixed-array gotcha when building tool lists.
- Positional params `$Command` and `$Arg1` plus a named `-Description` param gives a clean CLI API without needing argument parsing libraries.

**Testing approach:**
- `[ScriptBlock]::Create((Get-Content file.ps1 -Raw))` validates parse correctness without executing side effects.
- For integration testing of stub writing, override `$PROFILE` in a wrapper scriptblock that dot-sources the installer — this avoids touching the real profile.
- Idempotency was verified by running the installer twice and confirming "already present" messages on second run.

### 2026-06-01 — Bilingual README + Robust Nerd Font Installer

**Files changed:**
- `README.md` — full rewrite: bilingual (English + Spanish) with language nav, Requirements/font section, corrected one-liner URLs (`jmanuelcorral` + `master`), What You Get, dotfiles register workflow, repo structure tree, Credits/Sources.
- `bootstrap/install.ps1` — replaced minimal oh-my-posh-only font step with idempotent block: checks `%LOCALAPPDATA%\Microsoft\Windows\Fonts` and `C:\Windows\Fonts` for existing Meslo files; tries `oh-my-posh font install Meslo` first (checks exit code), falls back to `scoop bucket add nerd-fonts` + `scoop install Meslo-NF`; both wrapped in try/catch so failure warns and never aborts; corrected font name from `MesloLGM` to `MesloLGS NF` throughout.

**Key decisions:**
- Font idempotency via filesystem glob (`*Meslo*`) against both user and system font dirs — avoids registry complexity and works regardless of install method.
- `$fontDone` flag pattern mirrors the `$installed` flag already used in the package loop — consistent style.
- Font reminder printed unconditionally (outside the skip block) so the user always sees the "set your font" message even on re-runs.

### 2026-06-02 — Self-Bootstrap for `irm … | iex` one-liner

**Bug fixed:** `bootstrap/install.ps1` line 32 (`$RepoRoot = Split-Path $PSScriptRoot -Parent`) crashed when the script was piped via `irm … | iex` because `$PSScriptRoot` is empty in that context — no file on disk.

**Files changed:**
- `bootstrap/install.ps1` — added self-bootstrap block (lines 30–79) between colour helpers and `$RepoRoot` assignment. Detects empty `$PSScriptRoot`, checks for `git`, chooses clone target (`$env:DOTFILES` or `$HOME\dotfiles`), clones or pulls, re-invokes the on-disk installer with `@PSBoundParameters`, then `return`s. Normal on-disk execution is 100% unchanged.
- `README.md` — added "**Prerequisite:** Git must be installed…" callout to both English and Spanish Quick Install sections.

**Key learnings:**
- Place the self-bootstrap block *after* colour helpers so `Write-Header`/`Write-Step`/`Write-Ok`/`Write-Warn` are available inside the bootstrap path — same UX as the rest of the script.
- `[string]::IsNullOrEmpty($PSScriptRoot)` is the correct guard; `$PSScriptRoot` is `[string]` so `-not $PSScriptRoot` also works, but the explicit method is clearer.
- `@PSBoundParameters` transparently forwards named switches (`-NoPackages`, etc.) to the re-invoked on-disk script — no manual parameter forwarding needed.
- Piped-iex simulation for testing (`& { $(Get-Content … -Raw) } -NoPackages`) actually executes side effects on the real machine. For safe testing, patch the git-check to an always-true condition to confirm the error branch fires, rather than letting it clone.
- The `$env:DOTFILES` override for the clone destination makes the one-liner idempotent for users who have already set a custom dotfiles location.

### 2026-06-02 — Upcoming: Local AI Agent Feature

**Context:** Oracle has researched local SLM backends (recommending Ollama + Phi-4-mini-instruct), and Morpheus has architected a 6-phase implementation plan. Once Jose approves, Switch will own Phase 1 (shared agent assets + offline explain) and Phase 4 (installer updates + docs). Phase 1 will involve creating `shared/agent/` directory with prompt templates and the offline-first `dotfiles explain` implementation that reads `shared/aliases.json` and `shared/tools.json` directly. Phase 4 will update bootstrap installers to optionally install Ollama (via `-IncludeAgent` flag) and refresh documentation. Feature parity across shells is ensured in later phases by Trinity (Phase 2) and Tank (Phase 3).

