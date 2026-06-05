# Squad Decisions

## Active Decisions

### 1. Architecture Decision: Repository Layout and Load Contract

**Date:** 2026-06-01  
**Author:** Morpheus  
**Status:** ACTIVE — All agents MUST follow

This document defines the authoritative structure for the dotfiles repo. Trinity, Tank, and Switch must implement within this framework.

**Directory Layout (Canonical)**
- `powershell/` (Trinity owns) — profile.ps1, aliases.ps1, psreadline.ps1, prompt.ps1, completions.ps1, modules/
- `shell/` (Tank owns) — common.sh, bash/bashrc.sh, zsh/zshrc.sh
- `shared/` — aliases.json, tools.json (cross-shell data)
- `bin/` — User scripts (Switch manages registration)
- `bootstrap/` — install.ps1, install.sh
- `packages/` — Declarative package lists
- `docs/` — ARCHITECTURE.md, cheatsheet.md

**Load Contract:** PowerShell system `$PROFILE` contains only bootstrap stub; `profile.ps1` loads in order: aliases.ps1, psreadline.ps1, prompt.ps1, completions.ps1, modules/*.ps1 (alphabetical), adds `bin` to PATH. Bash/Zsh: `~/.bashrc` / `~/.zshrc` contain only bootstrap stub; each sources `common.sh`, adds `bin` to PATH, shell-specific setup.

**Idempotency Rules:** All install scripts check before modifying (look for `# dotfiles bootstrap` marker), backup before changing, guard package installs, report actions, never duplicate. Tool registration in `bin/` via `dotfiles register <name>` updates `shared/tools.json`.

---

### 2. Decision: Oracle Recommended Terminal Stack (2026-06-01)

**Status:** Proposed  
**Author:** Oracle  
**Date:** 2026-06-01  

**Prompt Engine:** Keep Oh My Posh on Windows PowerShell (deeper Windows API integration); Add Starship inside WSL only (fastest async prompt, single `starship.toml` shared across all Linux shells).

**CLI Tool Stack (must-have):** eza (ls replacement with icons + Git status), bat (cat replacement with syntax highlighting), fd (find replacement, gitignore-aware), zoxide (smart cd, frecency-based jump), delta (git diff with side-by-side syntax highlighting), jq (JSON processor), yq/mikefarah (YAML processor).

**PowerShell Modules:** PSReadLine with PredictionSource HistoryAndPlugin + ListView; Terminal-Icons; posh-git; PSFzf (Ctrl+T file picker, Ctrl+R history).

**Package Management:** Windows: winget import (declarative, idempotent) + scoop; WSL: apt + cargo for missing tools.

**Font:** CaskaydiaCove Nerd Font Mono via `oh-my-posh font install` (no admin required).

**Dotfiles Management:** chezmoi for one-liner bootstrap from GitHub, per-OS templates, secrets support, idempotent.

---

### 3. Decision: Windows Install Flow, bin/ Registration, and dotfiles CLI

**Date:** 2026-06-01  
**Author:** Switch  
**Status:** ACTIVE

**Repo Root Detection:** `$PSScriptRoot` yields bootstrap/ dir; `Split-Path $PSScriptRoot -Parent` reliably yields repo root. `$env:DOTFILES` set from this value — no hardcoded paths.

**Package Schema:** `packages/winget.json` uses object array with `id` (winget ID), `command` (binary name for guard), `scoop` (fallback), `description`. Makes installer self-documenting and extensible.

**Idempotency Strategy:** Package guard via `Get-Command <binary>`; module guard via `Get-Module -ListAvailable` version check; profile stub guard via `Select-String -Pattern "# dotfiles bootstrap"` on raw `$PROFILE` content; backup with timestamp before touch; exit code `-1978335189` (already installed) treated as success.

**Profile Stub:** Exactly follows architecture contract; written with `Add-Content` (append) or `Set-Content` (create); `$PROFILE` resolves automatically to OneDrive-redirected path.

**bin/ Registration:** `dotfiles register <name> [-Description "..."]` updates `shared/tools.json` with upsert logic (no duplicates). Path uses forward slashes for cross-platform readability.

**dotfiles CLI:** Subcommand dispatch via switch. `dotfiles help` reads `docs/cheatsheet.md` + live-generated "Registered Tools" from `shared/tools.json`; launches fzf interactively if available, falls back to coloured output; with query argument, substring filter (case-insensitive). `dotfiles register` uses mutable `List[object]` to avoid fixed-size array limitation.

---

### 4. Decision: Shell Configuration — bash/zsh + WSL Bootstrap

**Date:** 2026-06-01  
**Author:** Tank  
**Status:** ACTIVE  

**Starship for WSL prompt (not Oh My Posh):** Starship initialised in bash/bashrc.sh and zsh/zshrc.sh; single binary with one shared `starship.toml`; async by default; fastest prompt on large Git repos; zshrc.sh guard `[ -z "$ZSH" ]` prevents fighting oh-my-zsh.

**apt quirks handled:** `bat` → installed as `batcat` on Ubuntu <22.04; `bootstrap/install.sh` creates symlink + `common.sh` wraps as shell function. `fd` → installed as `fd-find`/`fdfind`; same two-layer approach. `eza` → Ubuntu 23.10+ via apt; fallback to gierens.de apt repo, then cargo. `zoxide` → Ubuntu 22.10+ via apt; fallback to official script. `delta` → fetched from GitHub releases (musl static). `yq` → mikefarah/yq from GitHub releases. `starship` → official curl script.

**Shell stub approach (idempotent):** Two-line stub appended to ~/.bashrc and ~/.zshrc, guarded by `# dotfiles bootstrap` marker. Timestamped `.backup.<timestamp>` created before modification. Safe to re-run.

**common.sh is POSIX-first:** Avoids bashisms; uses `[ ]`, `printf`, POSIX parameter expansion; passes `bash -n`. Zsh-specific code stays in zsh/zshrc.sh.

**dotfiles CLI function in bash/zsh:** Implemented in `common.sh` providing `help [query]`, `list`, `update`, `edit`. Uses fzf for interactive search, falls back to rg/grep. Reads `shared/tools.json` (via jq) and `docs/cheatsheet.md`. Behaviour matches PowerShell `dotfiles` command.

**Nerd Font (WSL note):** `bootstrap/install.sh` installs MesloLGS NF to ~/.local/share/fonts for native Linux use. For WSL, note printed reminding user to set in Windows Terminal.

---

### 5. Decision: PowerShell Configuration — OMP Fix, Alias Catalog, Module Choices

**Date:** 2026-06-01  
**Author:** Trinity  
**Status:** ACTIVE

**Problem:** User's existing profile (934 lines) had three issues: (1) Oh My Posh startup error — missing theme file; (2) Hardcoded user path (josecorral); (3) 900-line boilerplate.

**Oh My Posh — repo-local theme, no hardcoded paths:** Custom theme at `powershell/themes/dotfiles.omp.json`, referenced via `$env:DOTFILES`. Fallback chain: repo theme → $env:POSH_THEMES_PATH → plain-text prompt. Theme: Tokyo Night palette, powerline segments: OS icon → path → git → node → python → execution time → status; right segment: clock.

**Alias catalog location — `shared/aliases.json`:** Canonical source of truth for cross-shell aliases. Trinity implements in `powershell/aliases.ps1`; Tank implements in `shell/common.sh`. JSON schema: `{ "alias": { "windows": "...", "unix": "...", "_note": "..." } }`. Single source prevents drift. Strategy: use functions (not `Set-Alias`) for anything that forwards arguments; prefer modern tools when present (eza > Get-ChildItem, rg > Select-String, bat > Get-Content, fd > Get-ChildItem -Recurse); guard every preference with `Get-Command X -ErrorAction SilentlyContinue`.

**PSReadLine — VT console guard:** Wrap `Set-PSReadLineOption -PredictionViewStyle ListView` in `$Host.UI.RawUI.WindowSize.Width -gt 0` guard. ListView requires VT processing; guard degrades gracefully to InlineView without breaking startup.

**Module choices:** PSReadLine (always load, built-in), Terminal-Icons (guarded import), posh-git (guarded import), PSFzf (guarded import + fzf check), zoxide (guarded Invoke-Expression).

**Completers:** Ported winget + dotnet (native completers). Added gh (GitHub CLI), zoxide init, PSFzf key bindings. All guarded.

---

### 6. Decision: One-Liner Installer Bootstrap and Push Account Management

**Date:** 2026-06-02  
**Author:** switch, tank  
**Status:** ACTIVE

**One-liner installers must self-bootstrap:** When piping scripts to `iex` (PowerShell) or `bash` (shell), `$PSScriptRoot` and `BASH_SOURCE` are empty because the script is read from stdin. All one-liner installers (`bootstrap/install.ps1`, `bootstrap/install.sh`) must detect this condition and automatically clone/pull the repo before executing the on-disk installer. PowerShell: check if `$PSScriptRoot` is empty; if so, clone/pull and re-invoke with `@PSBoundParameters`. Bash: check if `BASH_SOURCE` is not a real file; if so, clone/pull and re-exec with original args. This ensures identical behavior for both inline and on-disk execution paths.

**Git account management for pushes:** Use `gh auth switch --user jmanuelcorral` to ensure the active gh account has write permissions to the repository. If a 403 permission denied error occurs and the gh CLI has drifted to a different account (e.g., `josecorral_microsoft`), explicitly switch back to `jmanuelcorral` before `git push`.

---

### 7. Decision: Local AI Agent Backend Recommendation

**Date:** 2026-06-02  
**Author:** Oracle  
**Status:** SUPERSEDED by Decision #10 (2026-06-02)

**Original Proposal: Ollama + Phi-4-mini-instruct**
- Install: `winget install Ollama.Ollama` (Windows) / `curl https://ollama.ai/install.sh | sh` (WSL)
- Model pull: `ollama pull phi4-mini` (~2.3 GB, MIT license)
- Invocation: OpenAI-compatible REST at `localhost:11434/v1/chat/completions`
- Fallback: Qwen2.5-Coder-1.5B (~1.0 GB, Apache 2.0) via `$env:DOTFILES_AGENT_MODEL`
- Offline-first: `dotfiles explain <alias>` works without model via `shared/aliases.json`

Full research: `docs/research/local-agent-2026.md`

**Superseded by:** Decision #10 — Self-Contained Local Agent (No-Daemon) — Oracle Revised Recommendation

---

### 8. Decision: Local Agent Architecture Plan (6-Phase Implementation)

**Date:** 2026-06-02  
**Author:** Morpheus  
**Status:** SUPERSEDED by Decision #11 (2026-06-02)

Architectural plan for `dotfiles agent "<query>"` and `dotfiles explain <cmd>` — Original (Ollama-based):
- **Phase 1 (Switch):** Shared agent assets + offline explain
- **Phase 2 (Trinity):** PowerShell agent wrapper
- **Phase 3 (Tank):** bash/zsh agent parity
- **Phase 4 (Switch):** Installer + docs updates
- **Phase 5 (Trinity/Tank):** AI-enhanced explain
- **Phase 6 (Oracle):** Benchmarking

Full plan: `docs/plans/local-agent-plan.md`

**Superseded by:** Decision #11 — Self-Contained Local Agent Architecture (Supersedes #7/#8)

---

### 9. Decision: User Directive — Reject Ollama, Require Self-Contained Agent

**Date:** 2026-06-02T10:41:57Z  
**Author:** Jose (via Copilot)  
**Status:** ACCEPTED

**Directive:** Reject Ollama as the backend for the `dotfiles agent` feature. Jose requires a **self-contained agent** — no background daemon/server. Preference: dotfiles ships or downloads a self-contained inference binary + a small model file, invoked per-call as a one-shot subprocess, portable across Windows + WSL, offline.

**Rationale:** User preference supersedes Decisions #7 and #8 (Ollama + Phi-4-mini approach). The architecture must be revised to a self-contained approach before any implementation proceeds.

**Outcome:** Triggers immediate revision of #7 and #8 by Oracle and Morpheus.

---

### 10. Decision: Self-Contained Local Agent (No-Daemon) — Oracle Revised Recommendation

**Date:** 2026-06-02T10:41:57Z  
**Author:** Oracle  
**Status:** ACCEPTED — supersedes Decision #7 (Ollama + Phi-4-mini)

**Revised Recommendation:** `llama-cli` (llama.cpp CPU binary) + `Qwen2.5-Coder-1.5B-Instruct Q4_K_M`

| Component | Detail |
|---|---|
| Engine | `llama-cli` prebuilt CPU-only binary from `ggml-org/llama.cpp` GitHub Releases |
| Engine binary size | ~9 MB compressed / ~15 MB extracted (Win: exe + ggml.dll + llama.dll; Linux: single binary) |
| Model | `Qwen2.5-Coder-1.5B-Instruct` Q4_K_M GGUF |
| Model size | ~986 MB |
| Model source | `Qwen/Qwen2.5-Coder-1.5B-Instruct-GGUF` on HuggingFace |
| License | Engine: MIT; Model: Apache 2.0 — no per-machine ToS friction |
| Cold start per call | ~5–8 s on modern laptop CPU with SSD |
| Daemon required | ❌ None — one-shot subprocess, exits when done |
| Python required | ❌ None |
| Portability | Windows x64/arm64 + Linux x64/arm64 + WSL2 |
| Invocation | Identical args from PowerShell and bash (`--no-display-prompt --single-turn --log-disable -n 80 --temp 0`) |
| Offline | ✅ Fully offline after one-time `dotfiles agent --setup` |

**Lighter Fallback:** same engine + `Qwen2.5-Coder-0.5B-Instruct Q4_K_M` (~3–5 s per call, ~572 MB on disk) for ≤4 GB RAM machines.

**Key Implementation Notes:**
- Setup script (`dotfiles agent --setup`): Detect OS + arch, download pinned llama.cpp release ZIP/tar.gz from GitHub Releases with SHA256 verification, extract to `$DOTFILES\cache\bin\`; Windows: run `Unblock-File` on extracted files; Linux: `chmod +x`.
- Invocation pattern (both shells, same args): `llama-cli -m <model.gguf> --no-display-prompt --single-turn --log-disable -n 80 --temp 0 -p "<prompt>"`
- Cache layout (add `cache/` to `.gitignore`): `$env:DOTFILES\cache\bin\` → binaries; `$env:DOTFILES\cache\models\` → GGUF model files.
- Graceful degradation: If `$DOTFILES\cache\bin\llama-cli(.exe)` is absent, fall through to offline JSON-only `dotfiles explain` path.

**Full Research:** `docs/research/local-agent-2026.md` — "Self-Contained (No-Daemon) Options — Revised per Jose" section.

---

### 11. Decision: Self-Contained Local Agent Architecture (Supersedes #7/#8)

**Date:** 2026-06-02T10:41:57Z  
**Author:** Morpheus (Lead / Architect)  
**Status:** ACCEPTED — supersedes Decisions #7 and #8

**Decision:** Replace Ollama + Phi-4-mini with llama-cli + Qwen2.5-Coder-1.5B.

| Component | Original (Ollama) | Revised (Self-Contained) |
|-----------|-------------------|--------------------------|
| Engine | Ollama daemon (always-on) | `llama-cli` binary (one-shot subprocess) |
| Invocation | REST API (`localhost:11434`) | Direct subprocess call |
| Primary model | Phi-4-mini (3.8B, ~2.3 GB) | Qwen2.5-Coder-1.5B Q4_K_M (~986 MB) |
| Fallback model | Qwen2.5-Coder-1.5B (~1 GB) | Qwen2.5-Coder-0.5B Q4_K_M (~572 MB) |
| Cold start | ~1–4 s (warm cache) | ~5–8 s (no warm state) |
| Daemon required | ✅ Yes | ❌ No |
| Offline | After Ollama + model install | After one-time `--setup` |

**Key Changes to Implementation Plan:**
1. **No REST API calls** — PowerShell uses `& llama-cli.exe ...`, bash uses `./llama-cli ...`
2. **New setup phase** — `dotfiles agent --setup` downloads engine + model with SHA256 verification
3. **Cache directory** — `$DOTFILES/cache/bin/` and `$DOTFILES/cache/models/` (gitignored)
4. **Windows SmartScreen** — Setup script calls `Unblock-File` on downloaded executables
5. **Model changed** — Qwen2.5-Coder-1.5B is faster to cold-start than Phi-4-mini
6. **No AI-enhanced explain** — `explain` is 100% offline (registry lookup only)

**Revised Phase-to-Agent Mapping:**
| Phase | Owner | Focus |
|-------|-------|-------|
| 1 | Switch | Shared assets + offline `explain` + config |
| 2 | Switch | First-run bootstrap (downloader) |
| 3 | Trinity | PowerShell `agent` subcommand |
| 4 | Tank | Bash/zsh `agent` parity |
| 5 | Switch | Documentation + DX polish |
| 6 | Oracle + Scribe | Validation + tuning + decisions log |

**References:**
- Full revised plan: `docs/plans/local-agent-plan.md`
- Oracle's research: `docs/research/local-agent-2026.md` → "Self-Contained (No-Daemon) Options"
- Jose's directive: Decision #9

---

### 12. Decision: CLI Documentation Structure — Bilingual Guides under docs/commands/

**Date:** 2026-06-05  
**Author:** Switch  
**Status:** ACTIVE

---

## Context

Jose requested a bilingual (English + Spanish) developer guide covering every `dotfiles` command. The cheatsheet (`docs/cheatsheet.md`) already exists as a quick-reference; we needed a deeper, example-driven teaching guide.

## Decision

### Output location: `docs/commands/`

All CLI documentation lives under `docs/commands/`:

| File | Purpose |
|---|---|
| `docs/commands/README.md` | Bilingual landing page: quick-reference table + language links |
| `docs/commands/commands.en.md` | Full English developer guide |
| `docs/commands/commands.es.md` | Full Spanish developer guide |

Rationale: keeps `docs/` uncluttered; a dedicated subdirectory signals that more per-topic guides can follow the same pattern.

### Mirrored 1:1 structure (EN ↔ ES)

Both language files use **identical section order and heading names** (in their respective languages) so diffs between them are immediately meaningful. A maintainer editing one file can apply the same change to the other by structural analogy without reading prose.

### Ground-truth-first writing rule

Before writing, the author **must** read the actual source files (`bin/dotfiles.ps1`, `shell/common.sh`, `shared/agent-config.json`) and document what the code does — not what it could do or should do. Any behavior that is "Phase N placeholder" must be labelled as such.

### Platform notes pattern

Every command section includes a **Platform notes** table covering: available in PowerShell? available in bash/zsh? any behavioral differences? This is a repeatable pattern for future command additions.

### README pointer pattern

Add **one line** to the repo `README.md` (both languages) pointing to `docs/commands/` — inside an existing section, never as a standalone section. Keep it minimal so it doesn't dominate the install-focused README.

## Consequences

- New commands added to `bin/dotfiles.ps1` + `shell/common.sh` **must** also be documented in both `commands.en.md` and `commands.es.md`, in the same section order.
- The `docs/commands/README.md` quick-reference table must be kept in sync with the command dispatch in both shell files.
- Version references in these docs should always point readers to the root `VERSION` file, never hardcode a version string.

---

### 13. Decision: Console Tools Documentation — Bilingual Hands-On Guide

**Date:** 2026-06-05  
**Author:** Switch  
**Status:** ACTIVE

## Summary

Created a bilingual (English + Spanish) "working in the console" developer guide under `docs/console/`. This complements the existing `docs/commands/` CLI reference, which only documents the `dotfiles` command itself.

## What Was Added

### New files

| File | Purpose |
|---|---|
| `docs/console/README.md` | Bilingual index: tool-inventory quick-reference table + language links |
| `docs/console/console.en.md` | Full English hands-on guide (16 sections, ~25 KB) |
| `docs/console/console.es.md` | Full Spanish guide — structural mirror of EN (same sections, same order, same examples) |

### Modified files

| File | Change |
|---|---|
| `docs/commands/README.md` | Added one-line pointer to `docs/console/` in "See Also" |
| `README.md` | Added one-line pointer in both English and Spanish sections (mirrors existing `docs/commands/` pointer pattern) |

## Tools Covered

Every tool provisioned by `packages/winget.json`, `packages/scoop.json`, and `packages/apt.json`:

- **Modern CLI replacements:** eza, bat, fd, ripgrep (rg), fzf, zoxide, delta, jq, yq (Unix), duf (Unix)
- **Git workflow:** git + all aliases from `shared/aliases.json` (g/ga/gc/gst/gp/gl/gd), delta as pager
- **GitHub:** gh CLI (auth, repo, pr, issue, run)
- **Shell environment:** oh-my-posh (Windows), starship (Unix/WSL), gsudo/sudo, volta
- **Navigation/utility aliases:** all entries from `shared/aliases.json` (../.../..../up/mkcd/cdot/reload/open/env/export/history/head/tail/ps/kill/df/du/top/which/mkdir)

## Conventions Established (for future console docs)

1. **Platform callout style:** `🪟 Windows — ...` / `🐧 Unix/WSL — ...` inline blocks.
2. **Tool section structure:** 1-2 line description + replaces · everyday examples · expected output (where helpful) · power combo.
3. **Alias accuracy:** All alias expansions verified against `shared/aliases.json` before writing. No invented aliases.
4. **Binary quirk sourcing:** `batcat`/`fdfind` notes sourced from `packages/apt.json` `_binary_quirks`.
5. **EN ↔ ES mirror:** Both guides have identical section order and heading structure for parallel maintenance.

## Recommended Follow-up (optional, not blocking)

- If new tools are added to `packages/*.json`, add a section to both `console.en.md` and `console.es.md`.
- Consider linking `docs/console/` from `docs/cheatsheet.md` as a "deeper reading" reference.

---

## Governance

- All meaningful changes require team consensus
- Document architectural decisions here
- Keep history focused on work, decisions focused on direction
