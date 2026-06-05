---
name: "dotfiles-architecture"
description: "Load contract, thin-stub pattern, and module boundaries for the dotfiles repo"
domain: "architecture"
confidence: "high"
source: "manual"
---

## Context

The dotfiles repo is a portable terminal-config system for Windows PowerShell 7+ and Unix/WSL/macOS bash/zsh. The core design principle is a **thin-stub load contract**: system profile files are kept as small as possible (2 lines), and all real configuration lives in the repo. This makes the repo the single source of truth and allows safe re-installation across machines.

Key invariants:
- System `$PROFILE` / `~/.bashrc` / `~/.zshrc` contain **only** the bootstrap stub — never any real config.
- The stub is guarded by the `# dotfiles bootstrap` marker so installers can detect and skip it safely.
- Every install/setup step must be idempotent (safe to re-run with no side-effects).
- Windows PowerShell and Unix shells maintain parity for `dotfiles` CLI subcommands and aliases.

## Patterns

### Thin-Stub Bootstrap (PowerShell)

The system `$PROFILE` contains exactly two lines:
```powershell
# dotfiles bootstrap
$env:DOTFILES = "C:\Users\jose\dotfiles"; . "$env:DOTFILES\powershell\profile.ps1"
```

The installer checks for the marker before writing:
```powershell
$profileContent = if (Test-Path $PROFILE) { Get-Content $PROFILE -Raw } else { "" }
if ($profileContent -notmatch "# dotfiles bootstrap") {
    if (Test-Path $PROFILE) {
        Copy-Item $PROFILE "$PROFILE.backup.$(Get-Date -Format 'yyyyMMddHHmmss')"
    }
    Add-Content $PROFILE "`n# dotfiles bootstrap`n`$env:DOTFILES = `"$RepoRoot`"; . `"`$env:DOTFILES\powershell\profile.ps1`""
}
```

### Thin-Stub Bootstrap (Bash/Zsh)

```sh
# dotfiles bootstrap
export DOTFILES="$HOME/dotfiles"; . "$DOTFILES/shell/bash/bashrc.sh"
```

Shell installer guard:
```sh
if ! grep -q "# dotfiles bootstrap" "$HOME/.bashrc" 2>/dev/null; then
    cp "$HOME/.bashrc" "$HOME/.bashrc.backup.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true
    printf '\n# dotfiles bootstrap\nexport DOTFILES="%s"; . "%s/shell/bash/bashrc.sh"\n' \
        "$DOTFILES" "$DOTFILES" >> "$HOME/.bashrc"
fi
```

### PowerShell Load Order (`powershell/profile.ps1`)

`profile.ps1` dot-sources in strict order:
```powershell
. "$PSScriptRoot\aliases.ps1"
. "$PSScriptRoot\psreadline.ps1"
. "$PSScriptRoot\prompt.ps1"
. "$PSScriptRoot\completions.ps1"

# Drop-in modules — alphabetical
Get-ChildItem "$PSScriptRoot\modules\*.ps1" | Sort-Object Name | ForEach-Object {
    . $_.FullName
}

# Add bin/ to PATH (idempotent)
$binPath = Join-Path $env:DOTFILES "bin"
if ($env:PATH -notlike "*$binPath*") {
    $env:PATH = "$binPath$([IO.Path]::PathSeparator)$env:PATH"
}
```

Order matters: `aliases.ps1` loads first because later modules may call aliases. `completions.ps1` loads last because it may reference functions defined in `prompt.ps1`.

### POSIX-First `common.sh`

`shell/common.sh` is sourced by **both** `bash/bashrc.sh` and `zsh/zshrc.sh`. It must use only POSIX sh syntax:

```sh
# POSIX-compliant guard (not bash-specific [[ ]])
if [ -n "$DOTFILES" ]; then
    # use printf, not echo -e
    printf '%s\n' "dotfiles loaded"
fi

# POSIX parameter expansion (not bashism ${var^^})
alias_value=$(cat "$DOTFILES/shared/aliases.json" | jq -r ".${key}.unix // empty")
```

Zsh-specific code (compinit, zstyle, etc.) stays in `zsh/zshrc.sh`. Bash-specific code (shopt, BASH_COMPLETION) stays in `bash/bashrc.sh`.

### Shared Alias Schema (`shared/aliases.json`)

Aliases are defined **once** and consumed by both shells. Never define an alias in only one shell file.

```json
{
  "ll":  { "windows": "eza -la --icons", "unix": "eza -la --icons", "_note": "long list with icons" },
  "cat": { "windows": "bat --style=plain", "unix": "bat --style=plain", "_note": "syntax-highlighted cat" },
  "gs":  { "windows": "git status", "unix": "git status", "_note": "git shorthand" }
}
```

PowerShell consumes this in `aliases.ps1`:
```powershell
$aliases = Get-Content "$env:DOTFILES\shared\aliases.json" | ConvertFrom-Json -AsHashtable
foreach ($key in $aliases.Keys) {
    $val = $aliases[$key].windows
    if ($val) {
        $tokens = $val -split ' ', 2
        # Use function instead of Set-Alias to support arguments
        $cmd = $tokens[0]; $args = $tokens[1]
        Set-Item -Path "Function:$key" -Value { & $cmd $args @args }.GetNewClosure()
    }
}
```

Shell consumes this in `common.sh`:
```sh
# requires jq
if command -v jq >/dev/null 2>&1; then
    while IFS= read -r line; do
        key=$(printf '%s' "$line" | jq -r '.key')
        val=$(printf '%s' "$line" | jq -r '.val')
        # shellcheck disable=SC2139
        alias "$key=$val"
    done <<EOF
$(jq -r 'to_entries[] | {key: .key, val: .value.unix} | @json' "$DOTFILES/shared/aliases.json")
EOF
fi
```

### Idempotency Pattern

Every action must detect-then-skip. General pattern:
```powershell
# Package install guard
if (-not (Get-Command eza -ErrorAction SilentlyContinue)) {
    winget install eza-community.eza
    # winget exit -1978335189 = already installed — also acceptable
}

# Module import guard
if (Get-Module -ListAvailable Terminal-Icons -ErrorAction SilentlyContinue) {
    Import-Module Terminal-Icons -ErrorAction SilentlyContinue
}

# External tool guard (never throw on missing tool)
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    oh-my-posh init pwsh --config "$env:DOTFILES\powershell\themes\dotfiles.omp.json" | Invoke-Expression
}
```

### Versioning

```powershell
# Read version at runtime — never hardcode
$version = Get-Content "$env:DOTFILES\VERSION" -Raw -ErrorAction SilentlyContinue | ForEach-Object { $_.Trim() }
```

```sh
# Shell equivalent
VERSION=$(cat "$DOTFILES/VERSION" 2>/dev/null | tr -d '[:space:]')
```

`VERSION` file contains a single SemVer string (e.g., `1.2.0`). `CHANGELOG.md` entries use `## [x.y.z] - YYYY-MM-DD`.

## Examples

### Adding a drop-in PowerShell module

Drop `powershell/modules/git-helpers.ps1`. It is loaded alphabetically on next shell start — no changes to `profile.ps1` needed.

### Adding a new alias

1. Add to `shared/aliases.json`:
   ```json
   "glog": { "windows": "git log --oneline --graph", "unix": "git log --oneline --graph", "_note": "compact git log" }
   ```
2. `powershell/aliases.ps1` consumes it automatically if using the JSON loop; or add a manual entry:
   ```powershell
   function glog { git log --oneline --graph @args }
   ```
3. `shell/common.sh` adds the alias:
   ```sh
   alias glog='git log --oneline --graph'
   ```

### Registering a bin/ script

```powershell
dotfiles register my-tool -Description "Does something useful"
# Updates shared/tools.json, makes my-tool available on PATH
```

## Anti-Patterns

| Anti-pattern | Why it's wrong | Correct approach |
|---|---|---|
| Editing system `$PROFILE` directly | Bypasses idempotency guard; changes lost on re-install | Edit repo files; re-run installer if stub is missing |
| Monolith profile (900+ lines in one file) | Unmaintainable; can't be unit-tested; slow to debug | Split into `aliases.ps1`, `psreadline.ps1`, `prompt.ps1`, `completions.ps1`, `modules/` |
| Bashisms in `common.sh` (e.g., `[[`, `${var^^}`, `echo -e`) | Breaks under strict POSIX sh and zsh's `emulate sh` | Use `[`, `printf`, POSIX parameter expansion |
| Hardcoded user paths (`C:\Users\josecorral\...`) | Breaks on any other machine | Use `$env:DOTFILES` (PS) / `$DOTFILES` (sh) with `Join-Path` |
| Duplicate alias definitions (define in both `aliases.ps1` and `common.sh` without `aliases.json`) | Definitions drift; bugs appear in only one shell | Single source in `aliases.json`; both shell files consume it |
| Unconditional `Import-Module` or `oh-my-posh init` | Throws on machines where the tool isn't installed yet | Wrap every external tool call in a `Get-Command`/`command -v` guard |
| `Set-Alias` for aliases that pass arguments | PowerShell `Set-Alias` does not forward arguments | Use `function` wrappers with `@args` |
| Writing to `.squad/decisions.md` directly | Bypasses review; may conflict with parallel writes | Write to `.squad/decisions/inbox/{name}-{slug}.md` |
