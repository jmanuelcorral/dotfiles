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

### 2026-06-05 — Bilingual Console Tools Documentation

**Task:** Create hands-on developer guide covering every tool provisioned by dotfiles (winget/scoop/apt packages + aliases).

**Files created:**
- `docs/console/README.md` — bilingual landing page with tool inventory table
- `docs/console/console.en.md` — 16 sections, English hands-on guide
- `docs/console/console.es.md` — 16 sections, Spanish structural mirror

**Files updated:**
- `docs/commands/README.md` — added pointer to docs/console/
- `README.md` (root) — added pointers in EN and ES sections

**Verification:** EN ↔ ES structural parity confirmed (16–17 sections each). All aliases verified against `shared/aliases.json`. Platform callouts (🪟 Windows / 🐧 Unix/WSL) applied consistently.

**Decision:** Filed as Decision #13 in `.squad/decisions.md`.

---

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

### 2026-06-02 — Phase 1 + Phase 2: Local Agent Shared Assets + Bootstrap

**Files created:**
- `shared/agent/system-prompt.txt` — shell-agnostic prompt template with `{{SHELL_TYPE}}`, `{{TOOLS_BLOCK}}`, `{{ALIASES_BLOCK}}` placeholders
- `shared/agent/few-shot.json` — 6 example pairs grounded in real aliases (ll, gl, gst, fd, rg)
- `shared/agent-config.json` — pinned engine tag `b9469`, real HuggingFace model URLs, null SHA256 with documented verification strategy
- `shell/lib/agent.sh` — POSIX-compatible install_agent_engine(), agent_paths(), agent_ready(); Phase 4 placeholder for Tank
- `powershell/modules/dotfiles-agent.psm1` — Install-AgentEngine, Get-AgentPaths, Test-AgentReady; Phase 3 placeholder for Trinity

**Files modified:**
- `bin/dotfiles.ps1` — added Invoke-Explain (offline: aliases.json → tools.json → --help), Invoke-Agent (--setup wiring + Phase 3 stub), updated help/usage text, added `$Arg2` param, added explain + agent dispatch cases
- `shell/common.sh` — added explain) and agent) cases to dotfiles() function; updated usage string
- `.gitignore` — added `cache/` and `cache/*`

**Key decisions:**
- Engine tag `b9469` (latest as of 2026-06-02). Windows asset: `llama-b9469-bin-win-cpu-x64.zip`; Linux: `llama-b9469-bin-ubuntu-x64.tar.gz`
- SHA256 pinning is `null` across all entries — impractical to compute without downloading multi-hundred-MB files. Integrity verified by: (1) file size within ±10% of `size_mb`, (2) `llama-cli --version` succeeding. Document in config + code.
- `curl.exe -L -C -` preferred for resumable downloads on Windows; `Invoke-WebRequest` as fallback. Same `curl -L -C -` on bash.
- `Unblock-File` applied to all extracted files on Windows (removes Zone.Identifier = 3 SmartScreen mark).
- Inference logic (prompt build + subprocess + post-process) NOT implemented — Trinity owns Phase 3 (PS), Tank owns Phase 4 (bash). Clearly marked placeholders left in both modules.

### 2026-06-02 — Dotfiles Versioning + Version-Aware Update

**Design chosen:**
- Root `VERSION` is the single source of truth; initial version is `1.0.0`.
- Root `CHANGELOG.md` uses Keep a Changelog-style SemVer sections.
- `dotfiles version` exists in both `bin/dotfiles.ps1` and `shell/common.sh`, reading `VERSION` and appending the short git SHA when available.
- `dotfiles update` captures old/new versions around `git pull --ff-only`, reports `dotfiles: vOLD → vNEW` or already up to date, prints the new changelog section when present, and reruns the platform installer idempotently.

**Files touched:**
- `VERSION`, `CHANGELOG.md`
- `bin/dotfiles.ps1`, `shell/common.sh`
- `bootstrap/install.ps1`, `bootstrap/install.sh`
- `README.md`, `docs/cheatsheet.md`
- `.squad/decisions/inbox/switch-versioning.md`
- `.squad/skills/dotfiles-versioning/SKILL.md`

**Gotchas:**
- Keep the version out of shell constants; always read from `VERSION`.
- Use `git pull --ff-only` for update, not rebase, to make the version transition deterministic and avoid unexpected history rewrites.
- Full installer rerun is intentional because install scripts are idempotent and bootstrap/package registration may change between versions.

### 2026-06-05 — Bilingual Console Productivity Guide

**Files created:**
- `docs/console/README.md` — bilingual index with tool-inventory quick-reference table (tool · replaces · one-liner · platform) and links to both language guides.
- `docs/console/console.en.md` — full English guide covering every tool provisioned by the dotfiles repo across 16 sections.
- `docs/console/console.es.md` — natural castellano translation, structurally identical to the English guide.

**Files modified:**
- `docs/commands/README.md` — added one-line pointer to `docs/console/` in the "See Also" section.
- `README.md` — added one-line pointer to `docs/console/` in both English and Spanish "Re-installing / Updating" sections, mirroring the existing `docs/commands/` pointer pattern.

**Tools documented:** eza (ls aliases), bat (cat alias), fd (find alias), ripgrep/rg (grep alias), fzf (shell integration + key bindings), zoxide (z/zi), delta (git pager), jq, yq (Unix), duf (Unix), git + all aliases from shared/aliases.json (g/ga/gc/gst/gp/gl/gd), gh CLI, oh-my-posh (Windows), starship (Unix), gsudo/sudo, volta (Windows), and all navigation/utility aliases (../.../..../up/mkcd/cdot/reload/open/env/export/history/head/tail/ps/kill/df/du/top/which/mkdir).

**Conventions established:**
- `docs/console/` follows the same pattern as `docs/commands/` — one README index plus EN and ES guide files.
- Platform notes use `🪟 Windows` / `🐧 Unix/WSL` inline callouts.
- Each tool section: what it is / what it replaces · everyday invocations with example output · at least one power combo chaining tools.
- "Recipes" section near end combines multiple tools for real tasks.
- Ground-truth aliases sourced exclusively from `shared/aliases.json` — no invented aliases.
- Binary quirks (fdfind, batcat) sourced from `packages/apt.json` `_binary_quirks`.


**Files created:**
- `docs/commands/README.md` — bilingual landing page: quick-reference table, language links, tips on `dotfiles help` and `dotfiles explain`.
- `docs/commands/commands.en.md` — full English developer guide (all 9 subcommands, deep-dives for `agent` and `skills`, 6 workflow recipes).
- `docs/commands/commands.es.md` — faithful Spanish translation, structurally identical to EN for parallel maintenance.

**Files modified:**
- `README.md` — added one-line pointer to `docs/commands/` in both English and Spanish "Re-install / Update" sections.

**Key decisions:**
- Ground truth sourced by reading `bin/dotfiles.ps1` (full), `shell/common.sh` (full), and `shared/agent-config.json` before writing a single word. No behavior invented.
- `register` is explicitly documented as PowerShell-only on Unix — the Unix function returns an error directing users to PowerShell or manual JSON editing, which is exactly what the code does.
- `explain` documented as 100% offline (no model required) — important distinction from `agent`.
- Each guide section uses a Platform notes table; agent section includes a full component table (engine, model sizes, licenses, cold-start times) sourced from `agent-config.json` and `decisions.md` #10/#11.
- EN and ES are structurally mirrored (same headings, same example blocks, same section order) so future updates can be done in parallel.
- README pointers kept intentionally minimal — one callout line each, inside existing "update" sections.
