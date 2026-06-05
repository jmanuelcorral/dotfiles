---
name: "powershell-config"
description: "Conventions for the modular, fast-loading PowerShell profile in this dotfiles repo"
domain: "powershell"
confidence: "high"
source: "manual"
---

## Context

The PowerShell profile is split into small, focused dot-sourced files under `powershell/`. The system
`$PROFILE` contains only a two-line bootstrap stub (written once by `bootstrap/install.ps1`):

```powershell
$env:DOTFILES = "<repo-root>"
. "$env:DOTFILES\powershell\profile.ps1"
```

`profile.ps1` is the sole entry point for all real configuration. It is the only file you ever edit
when changing the load order or adding a new top-level concern.

**Load order (profile.ps1):**

1. `aliases.ps1` — Linux-style wrappers and git shortcuts
2. `psreadline.ps1` — PSReadLine options and key bindings
3. `prompt.ps1` — Oh My Posh initialisation with full fallback chain
4. `completions.ps1` — module imports (Terminal-Icons, posh-git, zoxide, PSFzf) and argument completers
5. `modules/*.ps1` — drop-in files, dot-sourced **alphabetically** (auto-discovered, no registration)
6. `bin/` prepended to `$env:PATH` (idempotent — checks for existing entry first)

All temp variables (`$_dot`, `$_modulesDir`, `$_binDir`, `$_vtSupported`, `$_ompTheme`) are cleaned
up with `Remove-Variable … -ErrorAction SilentlyContinue` at the end of each file so they never
pollute the session.

**Alias source of truth:** `shared/aliases.json`. Trinity implements in `powershell/aliases.ps1`;
Tank implements the same catalog in `shell/common.sh`. Every alias visible to the user should have
a matching entry in `shared/aliases.json` before it is implemented in either shell.

---

## Patterns

### 1 — The Guard Pattern (unbreakable startup)

Every external tool call is wrapped in a `Get-Command X -ErrorAction SilentlyContinue` check.
A missing binary must never throw, never warn, and never slow down startup.

```powershell
if (Get-Command eza -ErrorAction SilentlyContinue) {
    function ls { eza --icons --group-directories-first @args }
} else {
    function ls { Get-ChildItem @args }   # built-in fallback
}
```

The same guard applies to module imports:

```powershell
if (Get-Module Terminal-Icons -ListAvailable -ErrorAction SilentlyContinue) {
    Import-Module Terminal-Icons -ErrorAction SilentlyContinue
}
```

And to `Invoke-Expression`-based initialisers:

```powershell
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
}
```

### 2 — Alias-as-Function (argument forwarding)

Use a **function**, never `Set-Alias`, whenever the alias must forward arguments or flags. `@args`
is the splatting idiom that passes all positional and named arguments through transparently.

```powershell
function grep { rg @args }        # forwards -i, -l, --glob, etc.
function cat  { bat --style=plain @args }
```

Use `Set-Alias` only for zero-argument identity mappings (e.g. `Set-Alias vi vim`) — but prefer
functions even there if future argument support is plausible.

### 3 — Oh My Posh fallback chain (no hardcoded paths)

Theme resolution uses `$env:DOTFILES`, not any user-specific path. The chain is:

1. Repo-local theme: `$env:DOTFILES\powershell\themes\dotfiles.omp.json`
2. Built-in OMP theme: `$env:POSH_THEMES_PATH\jandedobbeleer.omp.json`
3. Default OMP initialisation (no theme argument)
4. Plain-text `prompt` function (if `oh-my-posh` is not installed at all)

```powershell
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    $_ompTheme = if ($env:DOTFILES -and (Test-Path "$env:DOTFILES\powershell\themes\dotfiles.omp.json")) {
        "$env:DOTFILES\powershell\themes\dotfiles.omp.json"
    } elseif ($env:POSH_THEMES_PATH -and (Test-Path "$env:POSH_THEMES_PATH\jandedobbeleer.omp.json")) {
        "$env:POSH_THEMES_PATH\jandedobbeleer.omp.json"
    } else { $null }

    if ($_ompTheme) {
        oh-my-posh init pwsh --config $_ompTheme | Invoke-Expression
    } else {
        oh-my-posh init pwsh | Invoke-Expression
    }
    Remove-Variable _ompTheme
} else {
    function prompt {
        $branch = ''
        if (Get-Command git -ErrorAction SilentlyContinue) {
            $ref = git symbolic-ref --short HEAD 2>$null
            if ($ref) { $branch = " [$ref]" }
        }
        "$($executionContext.SessionState.Path.CurrentLocation)$branch`n> "
    }
}
```

### 4 — PSReadLine VT guard (ListView degrades safely)

`ListView` requires a VT-capable console with a known window width. Wrap it in a check so it
degrades to `InlineView` in non-interactive contexts (test runners, `pwsh -NonInteractive`, etc.):

```powershell
if (-not (Get-Module PSReadLine -ErrorAction SilentlyContinue)) { return }
if (-not [System.Environment]::UserInteractive)                  { return }

$_vtSupported = $Host.UI.RawUI -and $Host.UI.RawUI.WindowSize.Width -gt 0
Set-PSReadLineOption -PredictionSource HistoryAndPlugin
if ($_vtSupported) {
    Set-PSReadLineOption -PredictionViewStyle ListView
}
Remove-Variable _vtSupported -ErrorAction SilentlyContinue
```

### 5 — Drop-in module files

To add a self-contained feature (e.g. `dotfiles-agent.psm1` or a new helper script), drop a `.ps1`
file in `powershell\modules\`. It is automatically dot-sourced in **alphabetical** order after the
four core files. No registration or changes to `profile.ps1` are needed.

```powershell
# profile.ps1 — modules loop (do not change this)
$_modulesDir = "$_dot\powershell\modules"
if (Test-Path $_modulesDir) {
    Get-ChildItem -Path $_modulesDir -Filter '*.ps1' |
        Sort-Object Name |
        ForEach-Object { . $_.FullName }
}
```

### 6 — `bin/` PATH prepend (idempotent)

```powershell
$_binDir = "$_dot\bin"
if ((Test-Path $_binDir) -and ($env:PATH -notlike "*$_binDir*")) {
    $env:PATH = "$_binDir$([IO.Path]::PathSeparator)$env:PATH"
}
```

The check `$env:PATH -notlike "*$_binDir*"` prevents duplicates on `reload`.

### 7 — shared/aliases.json schema

When adding a new alias, **add it to `shared/aliases.json` first**, then implement in
`powershell\aliases.ps1` (Trinity) and `shell\common.sh` (Tank).

```json
"myalias": {
  "_note": "Human-readable description of what it does",
  "windows": "preferred-cmdlet | fallback-cmdlet",
  "unix":    "preferred-tool | fallback-tool"
}
```

Omit `windows` or `unix` if the alias is platform-specific. Prefix-only metadata keys with `_`
(e.g. `_comment`, `_owner`) — these are skipped by tooling.

---

## Examples

### Guarded alias with modern-tool preference and fallback

```powershell
# aliases.ps1
if (Get-Command eza -ErrorAction SilentlyContinue) {
    function ls   { eza --icons --group-directories-first @args }
    function ll   { eza -la --icons --group-directories-first @args }
    function la   { eza -a --icons @args }
    function l    { eza --icons @args }
    function lt   { eza --tree --level=2 --icons @args }
} else {
    function ls   { Get-ChildItem @args }
    function ll   { Get-ChildItem -Force @args }
    function la   { Get-ChildItem -Force @args }
    function l    { Get-ChildItem @args }
    function lt   { Get-ChildItem -Recurse @args }
}
```

### Modules auto-load loop (from profile.ps1)

```powershell
$_modulesDir = "$_dot\powershell\modules"
if (Test-Path $_modulesDir) {
    Get-ChildItem -Path $_modulesDir -Filter '*.ps1' |
        Sort-Object Name |
        ForEach-Object { . $_.FullName }
}
```

Drop `powershell\modules\my-feature.ps1` and it loads automatically — no edits to `profile.ps1`.

### Oh My Posh full fallback chain (from prompt.ps1)

```powershell
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    $_ompTheme = if ($env:DOTFILES -and (Test-Path "$env:DOTFILES\powershell\themes\dotfiles.omp.json")) {
        "$env:DOTFILES\powershell\themes\dotfiles.omp.json"
    } elseif ($env:POSH_THEMES_PATH -and (Test-Path "$env:POSH_THEMES_PATH\jandedobbeleer.omp.json")) {
        "$env:POSH_THEMES_PATH\jandedobbeleer.omp.json"
    } else { $null }

    if ($_ompTheme) { oh-my-posh init pwsh --config $_ompTheme | Invoke-Expression }
    else            { oh-my-posh init pwsh | Invoke-Expression }
    Remove-Variable _ompTheme
} else {
    function prompt {
        $branch = ''
        if (Get-Command git -ErrorAction SilentlyContinue) {
            $ref = git symbolic-ref --short HEAD 2>$null
            if ($ref) { $branch = " [$ref]" }
        }
        "$($executionContext.SessionState.Path.CurrentLocation)$branch`n> "
    }
}
```

### PSReadLine VT guard (from psreadline.ps1)

```powershell
if (-not (Get-Module PSReadLine -ErrorAction SilentlyContinue)) { return }
if (-not [System.Environment]::UserInteractive) { return }
$_vtSupported = $Host.UI.RawUI -and $Host.UI.RawUI.WindowSize.Width -gt 0
Set-PSReadLineOption -PredictionSource HistoryAndPlugin
if ($_vtSupported) { Set-PSReadLineOption -PredictionViewStyle ListView }
```

### Dual-tool completer guard (from completions.ps1)

```powershell
if ((Get-Command fzf -ErrorAction SilentlyContinue) -and
    (Get-Module PSFzf -ListAvailable -ErrorAction SilentlyContinue)) {
    Import-Module PSFzf -ErrorAction SilentlyContinue
    Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t'
    Set-PsFzfOption -PSReadlineChordReverseHistory 'Ctrl+r'
}
```

---

## Anti-Patterns

### ❌ Unguarded external tool call

```powershell
# BAD — throws on a fresh machine; breaks every startup
oh-my-posh init pwsh --config "$env:DOTFILES\powershell\themes\dotfiles.omp.json" | Invoke-Expression
```

Always wrap with `Get-Command oh-my-posh -ErrorAction SilentlyContinue` first.

### ❌ Destructive Set-Alias over a built-in

```powershell
# BAD — clobbers the built-in and cannot forward arguments
Set-Alias ls eza
```

Use a function instead so `@args` forwarding works and the built-in can be reached if needed.

### ❌ Hardcoded user or machine paths

```powershell
# BAD — breaks on any machine that is not josecorral's
oh-my-posh init pwsh --config "C:\Users\josecorral\poshv3.json" | Invoke-Expression
```

All paths must be relative to `$env:DOTFILES`. Never embed a username or absolute drive path.

### ❌ Slow or blocking profile additions

```powershell
# BAD — network call during startup; blocks the shell for seconds
$latestRelease = Invoke-RestMethod "https://api.github.com/repos/..."
```

Profile code must be synchronous and local-only. Anything that touches the network or disk
heavily should be a lazy-loaded module or a separate command, not part of the dot-sourced chain.

### ❌ Alias defined only in PowerShell, not mirrored in shared/aliases.json + shell/common.sh

```powershell
# BAD — PowerShell-only alias, no catalog entry, Tank never sees it
function gco { git checkout @args }
```

Add the entry to `shared/aliases.json` with `_note`, `windows`, and `unix` fields. Then implement
in `powershell\aliases.ps1` (Trinity) and `shell\common.sh` (Tank). Single source of truth prevents
catalog drift between shells.

### ❌ Placing new persistent features directly in profile.ps1

```powershell
# BAD — profile.ps1 becomes a dumping ground
# profile.ps1
function my-new-feature { ... }
```

Add a file to `powershell\modules\` instead. `profile.ps1` only ever contains the load-order
skeleton and the bin/ PATH prepend — never feature logic.

### ❌ Re-importing a module without a ListAvailable guard

```powershell
# BAD — Import-Module prints an error if the module is not installed
Import-Module Terminal-Icons
```

Always guard with `Get-Module Terminal-Icons -ListAvailable -ErrorAction SilentlyContinue` first,
then import with `-ErrorAction SilentlyContinue`.
