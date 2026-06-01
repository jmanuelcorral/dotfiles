# Decision: PowerShell Configuration — OMP Fix, Alias Catalog, Module Choices

**Date:** 2026-06-01  
**Author:** Trinity  
**Status:** ACTIVE

---

## Problem

The user's existing `$PROFILE` (934 lines) had three critical issues:

1. **Oh My Posh startup error** — line 16 called `oh-my-posh --init --shell pwsh --config "C:\Users\josecorral\poshv3.json"` but that file does not exist, causing an error on every shell launch.
2. **Hardcoded user path** — the path was tied to `josecorral`'s machine and would break on any other machine.
3. **900-line boilerplate** — the stock PSReadLine sample was 99% comments; non-essential noise.

---

## Decisions

### 1. Oh My Posh — repo-local theme, no hardcoded paths

**Decision:** Ship a custom theme at `powershell/themes/dotfiles.omp.json` and reference it via `$env:DOTFILES`.

**Rationale:**
- Eliminates the missing-file error permanently.
- Works identically on any machine where the repo is cloned.
- User controls the theme by editing one file in the repo.

**Fallback chain in `prompt.ps1`:**
```
repo theme → $env:POSH_THEMES_PATH\jandedobbeleer.omp.json → plain-text prompt
```

**Theme details:** Tokyo Night colour palette, powerline segments: OS icon → path → git → node → python → execution time → status. Right segment: clock.

---

### 2. Alias catalog location — `shared/aliases.json`

**Decision:** `shared/aliases.json` is the **canonical, documented** source of truth for cross-shell aliases. Trinity implements in `powershell/aliases.ps1`; Tank implements in `shell/common.sh`. The JSON uses the schema `{ "alias": { "windows": "...", "unix": "...", "_note": "..." } }`.

**Rationale:** Single source of truth prevents drift between shells. Tank reads the same file. The JSON is human-readable documentation of what each alias does on each OS.

**Alias strategy (PowerShell):**
- Use **functions** (not `Set-Alias`) for anything that forwards arguments.
- Prefer modern tools when present (`eza` > `Get-ChildItem`, `rg` > `Select-String`, `bat` > `Get-Content`, `fd` > `Get-ChildItem -Recurse`).
- Every preference is guarded with `Get-Command X -ErrorAction SilentlyContinue`.

---

### 3. PSReadLine — VT console guard

**Decision:** Wrap `Set-PSReadLineOption -PredictionViewStyle ListView` in a `$Host.UI.RawUI.WindowSize.Width -gt 0` guard.

**Rationale:** ListView requires VT processing. In non-interactive contexts (test runners, CI, `pwsh -NoProfile` pipes), this throws. The guard degrades gracefully to InlineView without breaking startup.

---

### 4. Module choices

| Module | Status | Rationale |
|---|---|---|
| PSReadLine | Always load (built-in) | Essential UX |
| Terminal-Icons | Guarded import | Pretty icons when present |
| posh-git | Guarded import | Git branch in prompt and completions |
| PSFzf | Guarded import + fzf check | Optional; provides Ctrl+T file picker |
| zoxide | Guarded `Invoke-Expression` | Smarter `cd` when installed |

---

### 5. Completers

Ported from old profile: **winget** (native completer) + **dotnet** (native completer).  
Added: **gh** (GitHub CLI), **zoxide init**, **PSFzf** key bindings.  
All guarded.

---

## Files changed

- `shared/aliases.json` — expanded full alias catalog
- `powershell/profile.ps1` — implemented load sequence
- `powershell/aliases.ps1` — full Linux-style alias/function set
- `powershell/psreadline.ps1` — modern config, VT-guarded
- `powershell/prompt.ps1` — OMP init, guarded, no hardcoded paths
- `powershell/completions.ps1` — winget, dotnet, gh, zoxide, PSFzf, posh-git, Terminal-Icons
- `powershell/themes/dotfiles.omp.json` — NEW: repo-local OMP theme
- `powershell/modules/README.md` — updated to Markdown
