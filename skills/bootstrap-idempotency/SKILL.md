---
name: "bootstrap-idempotency"
description: "Idempotent, self-bootstrapping install scripts for Windows and Unix"
domain: "automation"
confidence: "high"
source: "manual"
---

## Context

Install scripts in this repo (`bootstrap/install.ps1` and `bootstrap/install.sh`) follow a strict **idempotency contract**: every run must be safe, must produce the same end-state, and must never corrupt existing user configuration. They also support a **one-liner pipe-to-shell** install path (`irm … | iex` / `curl … | bash`), which requires self-bootstrap detection because `$PSScriptRoot` / `BASH_SOURCE` are empty in that context.

Decisions #3 and #6 in `.squad/decisions.md` define these rules as hard requirements.

## Patterns

### 1. Self-Bootstrap When Piped (Decision #6)

When a script is piped via `irm | iex` (PowerShell) or `curl | bash`, there is no file on disk — so `$PSScriptRoot` / `BASH_SOURCE` are empty. Detect this and clone-or-pull, then re-invoke the on-disk copy.

**PowerShell:**
```powershell
# Detect pipe-via-iex: $PSScriptRoot is empty
if ([string]::IsNullOrEmpty($PSScriptRoot)) {
    $cloneTarget = if ($env:DOTFILES) { $env:DOTFILES } else { "$HOME\dotfiles" }
    if (-not (Test-Path (Join-Path $cloneTarget '.git'))) {
        git clone https://github.com/jmanuelcorral/dotfiles.git $cloneTarget
    } else {
        git -C $cloneTarget pull --ff-only
    }
    & (Join-Path $cloneTarget 'bootstrap\install.ps1') @PSBoundParameters
    return   # do not fall through; the on-disk copy runs the real install
}
$RepoRoot = Split-Path $PSScriptRoot -Parent
```

`@PSBoundParameters` transparently forwards all named switches (`-NoPackages`, etc.) — no manual parameter forwarding needed.

**Bash:**
```bash
# Detect pipe-via-bash: BASH_SOURCE[0] is not a real file
_self="${BASH_SOURCE[0]:-}"
if [ ! -f "$_self" ]; then
    clone_target="${DOTFILES:-$HOME/dotfiles}"
    if [ ! -d "$clone_target/.git" ]; then
        git clone https://github.com/jmanuelcorral/dotfiles.git "$clone_target"
    else
        git -C "$clone_target" pull --ff-only
    fi
    exec bash "$clone_target/bootstrap/install.sh" "$@"
fi
DOTFILES="$(cd "$(dirname "$_self")/.." && pwd)"
```

### 2. The `# dotfiles bootstrap` Marker Guard

Before appending to `~/.bashrc`, `~/.zshrc`, or `$PROFILE`, check for the marker. This prevents duplicate stubs on every re-run.

**PowerShell:**
```powershell
$profileContent = if (Test-Path $PROFILE) { Get-Content $PROFILE -Raw } else { '' }
if ($profileContent -notmatch '# dotfiles bootstrap') {
    $stub = @"
`n# dotfiles bootstrap
`$env:DOTFILES = '$RepoRoot'
. "`$env:DOTFILES\powershell\profile.ps1"
"@
    Add-Content $PROFILE $stub
    Write-Ok "Profile stub written"
} else {
    Write-Warn "Profile stub already present — skipping"
}
```

**Bash:**
```bash
if ! grep -q '# dotfiles bootstrap' "${HOME}/.bashrc" 2>/dev/null; then
    printf '\n# dotfiles bootstrap\nexport DOTFILES="%s"\n. "$DOTFILES/shell/common.sh"\n' \
        "$DOTFILES" >> "${HOME}/.bashrc"
fi
```

### 3. Timestamped Backup Before Touching User Files

Always back up before modifying any user config file:

```powershell
# PowerShell
$ts = Get-Date -Format 'yyyyMMdd_HHmmss'
Copy-Item $PROFILE "$PROFILE.backup.$ts" -ErrorAction SilentlyContinue
```

```bash
# Bash
ts="$(date +%Y%m%d_%H%M%S)"
cp "${HOME}/.bashrc" "${HOME}/.bashrc.backup.${ts}" 2>/dev/null || true
```

### 4. Package Guards (`Get-Command` / `command -v`)

Never install a package without first checking if the binary is already on PATH:

**PowerShell:**
```powershell
foreach ($pkg in $packages) {
    if (Get-Command $pkg.command -ErrorAction SilentlyContinue) {
        Write-Warn "$($pkg.command) already installed — skipping"
        continue
    }
    winget install --id $pkg.id --accept-source-agreements --accept-package-agreements
    # winget exit -1978335189 = already installed at requested version → treat as success
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne -1978335189) {
        Write-Warn "winget install failed for $($pkg.id) (exit $LASTEXITCODE)"
    }
}
```

**Bash:**
```bash
install_if_missing() {
    local cmd="$1" pkg="$2"
    if command -v "$cmd" >/dev/null 2>&1; then
        echo "  already installed: $cmd — skipping"
        return 0
    fi
    sudo apt-get install -y "$pkg"
}
install_if_missing eza eza
install_if_missing bat bat
```

### 5. winget Exit Code `-1978335189` = Already Installed

winget returns `-1978335189` (0x8A15002B) when the requested package version is already installed. This is **not** an error — treat it as success.

```powershell
$alreadyInstalled = -1978335189
if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $alreadyInstalled) {
    Write-Host "  ⚠ Install failed: exit $LASTEXITCODE" -ForegroundColor Yellow
}
```

### 6. Module Version Guards

Before importing a PowerShell module, check if the minimum required version is already available:

```powershell
$minVersion = [version]'2.3.5'
$installed = Get-Module PSReadLine -ListAvailable |
             Sort-Object Version -Descending |
             Select-Object -First 1
if (-not $installed -or $installed.Version -lt $minVersion) {
    Install-Module PSReadLine -MinimumVersion $minVersion -Scope CurrentUser -Force
}
Import-Module PSReadLine
```

## Examples

### Full idempotent run (PowerShell)

```
> . $env:DOTFILES\bootstrap\install.ps1
[dotfiles] install.ps1 — Windows bootstrap
  ✓ git already present
  ⚠ oh-my-posh already installed — skipping
  ✓ eza already installed — skipping
  ⚠ Profile stub already present — skipping
  Done. Open a new terminal to apply changes.

> . $env:DOTFILES\bootstrap\install.ps1   # second run — identical output
```

### One-liner self-bootstrap (PowerShell)

```powershell
irm https://raw.githubusercontent.com/jmanuelcorral/dotfiles/master/bootstrap/install.ps1 | iex
# → detects empty $PSScriptRoot, clones repo, re-invokes on-disk installer
```

### One-liner self-bootstrap (bash)

```bash
curl -fsSL https://raw.githubusercontent.com/jmanuelcorral/dotfiles/master/bootstrap/install.sh | bash
# → detects BASH_SOURCE not a file, clones repo, exec's on-disk installer
```

## Anti-Patterns

- **Hardcoding `$HOME\dotfiles`** as the repo root — use `$env:DOTFILES` as the primary, derived path as fallback.
- **Skipping the marker check** — leads to duplicate profile stubs on every re-run.
- **No backup before touch** — corrupts the user's config if the script crashes mid-write.
- **Treating winget exit code `-1978335189` as failure** — this is the "already installed" success code; ignoring it produces spurious warnings.
- **Running package installs unconditionally** — wastes time and can break on networks without internet access.
- **Re-invoking with hardcoded params instead of `@PSBoundParameters`** — breaks when new flags are added.
