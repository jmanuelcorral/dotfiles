#Requires -Version 7
<#
.SYNOPSIS
    One-shot Windows installer for the dotfiles repo.
.DESCRIPTION
    Installs CLI packages (via winget, fallback scoop), PowerShell modules,
    a Nerd Font for Oh My Posh, and wires the thin $PROFILE stub — all
    idempotently. Safe to re-run at any time.
.PARAMETER NoPackages
    Skip all package/module installation. Only wire the $PROFILE stub.
.EXAMPLE
    pwsh -File bootstrap/install.ps1
    pwsh -File bootstrap/install.ps1 -NoPackages
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$NoPackages
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── Colour helpers ────────────────────────────────────────────────────────────
function Write-Header { param($msg) Write-Host "`n─── $msg " -ForegroundColor Magenta }
function Write-Step   { param($msg) Write-Host "  → $msg"   -ForegroundColor Cyan }
function Write-Ok     { param($msg) Write-Host "  ✓ $msg"   -ForegroundColor Green }
function Write-Skip   { param($msg) Write-Host "  · $msg"   -ForegroundColor DarkGray }
function Write-Warn   { param($msg) Write-Host "  ⚠ $msg"   -ForegroundColor Yellow }

# ── Self-bootstrap (piped / iex mode) ─────────────────────────────────────────
# When piped via `irm ... | iex`, $PSScriptRoot is empty — there is no backing
# file on disk. In that case: clone (or update) the repo, then re-invoke the
# on-disk installer so all subsequent paths resolve correctly.
if ([string]::IsNullOrEmpty($PSScriptRoot)) {
    Write-Header "Self-Bootstrap  (irm | iex mode)"

    # Git is the ONLY prerequisite we cannot self-install
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Host ""
        Write-Host "  ✗ Git is required but was not found on PATH." -ForegroundColor Red
        Write-Host "    Install Git first:  https://git-scm.com/download/win" -ForegroundColor Red
        Write-Host "    Then re-run the one-liner." -ForegroundColor Red
        Write-Host ""
        exit 1
    }

    # Choose clone destination: honour $env:DOTFILES if set, else $HOME\dotfiles
    $cloneTarget = if (-not [string]::IsNullOrEmpty($env:DOTFILES)) {
        $env:DOTFILES
    } else {
        Join-Path $HOME 'dotfiles'
    }

    $repoUrl = 'https://github.com/jmanuelcorral/dotfiles.git'

    if ((Test-Path $cloneTarget) -and (Test-Path (Join-Path $cloneTarget '.git'))) {
        Write-Step "Repo already exists at $cloneTarget — running git pull --ff-only"
        git -C $cloneTarget pull --ff-only
        if ($LASTEXITCODE -ne 0) {
            Write-Warn "git pull failed (exit $LASTEXITCODE) — continuing with existing clone"
        } else {
            Write-Ok "Repo up to date"
        }
    } else {
        Write-Step "Cloning $repoUrl  →  $cloneTarget"
        git clone $repoUrl $cloneTarget
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  ✗ git clone failed — cannot continue." -ForegroundColor Red
            exit 1
        }
        Write-Ok "Cloned to $cloneTarget"
    }

    # Re-invoke the on-disk script; pass through any switches (e.g. -NoPackages)
    Write-Step "Re-invoking on-disk installer…"
    $onDiskScript = Join-Path $cloneTarget 'bootstrap\install.ps1'
    & $onDiskScript @PSBoundParameters
    return
}

# ── Repo root (works from any clone path) ────────────────────────────────────
# bootstrap/install.ps1 lives one level below the repo root.
$RepoRoot        = Split-Path $PSScriptRoot -Parent
$env:DOTFILES    = $RepoRoot

Write-Host ""
Write-Host "  dotfiles installer" -ForegroundColor Magenta
Write-Host "  Repo root : $RepoRoot"
Write-Host "  Profile   : $PROFILE"
Write-Host ""

# ── Package installation ──────────────────────────────────────────────────────
if (-not $NoPackages) {

    # ── CLI tools via winget / scoop ──────────────────────────────────────────
    Write-Header "CLI Packages"
    $wingetJson = Join-Path $RepoRoot 'packages\winget.json'

    if (Test-Path $wingetJson) {
        $pkgData  = Get-Content $wingetJson -Raw | ConvertFrom-Json
        $hasWinget = [bool](Get-Command winget -ErrorAction SilentlyContinue)
        $hasScoop  = [bool](Get-Command scoop  -ErrorAction SilentlyContinue)

        foreach ($pkg in $pkgData.packages) {
            # Guard: already on PATH?
            if (Get-Command $pkg.command -ErrorAction SilentlyContinue) {
                Write-Skip "already present : $($pkg.command.PadRight(12))  # $($pkg.description)"
                continue
            }

            $installed = $false

            # Try winget first
            if ($hasWinget -and $pkg.id) {
                Write-Step "winget install $($pkg.id)  # $($pkg.description)"
                $result = winget install --id $pkg.id --silent `
                    --accept-package-agreements --accept-source-agreements 2>&1
                # Exit codes: 0 = success, -1978335189 (0x8A150011) = already installed
                if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq -1978335189) {
                    Write-Ok    "installed       : $($pkg.command)"
                    $installed = $true
                } else {
                    Write-Warn  "winget failed (exit $LASTEXITCODE) for $($pkg.id)"
                }
            }

            # Fallback to scoop
            if (-not $installed -and $hasScoop -and $pkg.scoop) {
                Write-Step "scoop install $($pkg.scoop)"
                scoop install $pkg.scoop 2>&1 | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    Write-Ok "installed via scoop : $($pkg.scoop)"
                    $installed = $true
                } else {
                    Write-Warn "scoop also failed for $($pkg.scoop)"
                }
            }

            if (-not $installed -and -not $hasWinget -and -not $hasScoop) {
                Write-Warn "no package manager found — install $($pkg.command) manually"
            }
        }
    } else {
        Write-Warn "packages/winget.json not found — skipping CLI tools"
    }

    # ── PowerShell modules ────────────────────────────────────────────────────
    Write-Header "PowerShell Modules"

    $psModules = @(
        @{ Name = 'PSReadLine';     MinVer = '2.3.0' },
        @{ Name = 'Terminal-Icons'; MinVer = '0.0.1' },
        @{ Name = 'posh-git';       MinVer = '1.0.0' },
        @{ Name = 'PSFzf';          MinVer = '2.0.0' }
    )

    foreach ($mod in $psModules) {
        $found = Get-Module -ListAvailable -Name $mod.Name |
                 Where-Object { $_.Version -ge [version]$mod.MinVer }
        if ($found) {
            Write-Skip "already installed : $($mod.Name)"
        } else {
            Write-Step "Install-Module $($mod.Name) -Scope CurrentUser"
            try {
                Install-Module -Name $mod.Name -Scope CurrentUser `
                    -Force -AllowClobber -Repository PSGallery -ErrorAction Stop
                Write-Ok "installed : $($mod.Name)"
            } catch {
                Write-Warn "failed to install $($mod.Name) : $_"
            }
        }
    }

    # ── Nerd Font (Meslo) ─────────────────────────────────────────────────────
    Write-Header "Nerd Font (Meslo)"

    # Idempotency: check if Meslo font files already exist in user or system fonts
    $userFontsDir   = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
    $systemFontsDir = 'C:\Windows\Fonts'
    $mesloAlreadyInstalled =
        (Get-ChildItem $userFontsDir   -Filter '*Meslo*' -ErrorAction SilentlyContinue) -or
        (Get-ChildItem $systemFontsDir -Filter '*Meslo*' -ErrorAction SilentlyContinue)

    if ($mesloAlreadyInstalled) {
        Write-Skip "Meslo Nerd Font already installed — skipping"
    } else {
        $fontDone = $false

        # Preferred: oh-my-posh font install Meslo (non-interactive)
        if (-not $fontDone -and (Get-Command oh-my-posh -ErrorAction SilentlyContinue)) {
            try {
                Write-Step "oh-my-posh font install Meslo"
                oh-my-posh font install Meslo 2>&1 | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    Write-Ok "Meslo Nerd Font installed via oh-my-posh"
                    $fontDone = $true
                } else {
                    Write-Warn "oh-my-posh font install exited $LASTEXITCODE — trying fallback"
                }
            } catch {
                Write-Warn "oh-my-posh font install failed: $_"
            }
        }

        # Fallback: scoop nerd-fonts bucket
        if (-not $fontDone -and (Get-Command scoop -ErrorAction SilentlyContinue)) {
            try {
                Write-Step "scoop bucket add nerd-fonts"
                scoop bucket add nerd-fonts 2>&1 | Out-Null
                Write-Step "scoop install Meslo-NF"
                scoop install Meslo-NF 2>&1 | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    Write-Ok "Meslo Nerd Font installed via scoop"
                    $fontDone = $true
                } else {
                    Write-Warn "scoop install Meslo-NF failed (exit $LASTEXITCODE)"
                }
            } catch {
                Write-Warn "scoop font install failed: $_"
            }
        }

        if (-not $fontDone) {
            Write-Warn "Could not install Meslo Nerd Font automatically"
            Write-Warn "Install it manually from https://www.nerdfonts.com"
        }
    }

    Write-Warn "ACTION REQUIRED: set 'MesloLGS NF' as your terminal font after install"
    Write-Warn "  Windows Terminal → Settings → Profile → Appearance → Font face → MesloLGS NF"
}

# ── $PROFILE stub (idempotent) ────────────────────────────────────────────────
Write-Header 'PowerShell Profile Stub'

$marker     = '# dotfiles bootstrap'
$profileDir = Split-Path $PROFILE -Parent

# Ensure the profile directory exists (OneDrive-redirected paths may not exist yet)
if (-not (Test-Path $profileDir)) {
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    Write-Step "Created profile directory : $profileDir"
}

# The stub: two lines only, as per architecture contract
$stub = @"

# dotfiles bootstrap — DO NOT EDIT BELOW
`$env:DOTFILES = "$RepoRoot"
. "`$env:DOTFILES\powershell\profile.ps1"
"@

if (Test-Path $PROFILE) {
    $existingContent = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue
    if ($existingContent -and ($existingContent | Select-String -Pattern $marker -Quiet)) {
        Write-Skip "stub already present in `$PROFILE — nothing to do"
    } else {
        # Back up existing profile with timestamp before touching it
        $ts         = Get-Date -Format 'yyyy-MM-dd-HHmmss'
        $backupPath = "$PROFILE.backup.$ts"
        Copy-Item $PROFILE $backupPath
        Write-Step "Backed up existing profile → $backupPath"
        Add-Content -Path $PROFILE -Value $stub -Encoding UTF8
        Write-Ok   "Stub appended to `$PROFILE"
    }
} else {
    Set-Content -Path $PROFILE -Value $stub.TrimStart() -Encoding UTF8
    Write-Ok "Created `$PROFILE with stub"
}

# ── Summary ───────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  ✔  dotfiles bootstrap complete!" -ForegroundColor Green
Write-Host ""
Write-Host "  Next steps:" -ForegroundColor Cyan
Write-Host "    1. Restart PowerShell (or run:  . `$PROFILE)"
Write-Host "    2. Set 'MesloLGS NF' as your font: Windows Terminal → Settings → Profile → Appearance → Font face"
Write-Host "    3. Try: dotfiles help"
Write-Host ""

