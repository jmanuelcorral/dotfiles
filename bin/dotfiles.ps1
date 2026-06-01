<#
.SYNOPSIS
    dotfiles CLI — manage your dotfiles, tools, and command cheatsheet.
.DESCRIPTION
    Subcommands:
        help    [query]            Show the command cheatsheet + registered tools.
                                   With no arguments, launches fzf (if available)
                                   for interactive fuzzy search; otherwise prints
                                   all entries. With a query, filters to matching lines.
        list                       List all tools registered in shared/tools.json.
        register <name>            Register (or update) a script in bin/ into
                                   shared/tools.json. Use -Description to describe it.
        update                     git pull inside $env:DOTFILES and reload $PROFILE.
        edit                       Open the dotfiles repo in $EDITOR / VS Code / notepad.
.PARAMETER Command
    Subcommand to run. Default: help.
.PARAMETER Arg1
    First positional argument (tool name for 'register', search query for 'help').
.PARAMETER Description
    Description string for 'register'.
.EXAMPLE
    dotfiles help
    dotfiles help git
    dotfiles register gituseswitch -Description "Switch git user identity"
    dotfiles list
    dotfiles update
    dotfiles edit
#>
param(
    [Parameter(Position = 0)] [string]$Command     = 'help',
    [Parameter(Position = 1)] [string]$Arg1        = '',
    [string]$Description = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Resolve the repo root: bin/dotfiles.ps1 → parent is repo root
$DotfilesRoot = if ($env:DOTFILES) { $env:DOTFILES } else { Split-Path $PSScriptRoot -Parent }
$ToolsJson    = Join-Path $DotfilesRoot 'shared\tools.json'
$Cheatsheet   = Join-Path $DotfilesRoot 'docs\cheatsheet.md'

# ── Data helpers ──────────────────────────────────────────────────────────────

function Get-ToolsData {
    if (Test-Path $ToolsJson) {
        $raw = Get-Content $ToolsJson -Raw | ConvertFrom-Json
        # Ensure .tools is always an array (not null)
        if ($null -eq $raw.tools) { $raw | Add-Member -NotePropertyName tools -NotePropertyValue @() -Force }
        $raw
    } else {
        [pscustomobject]@{ tools = @() }
    }
}

function Save-ToolsData([object]$data) {
    $data | ConvertTo-Json -Depth 5 | Set-Content $ToolsJson -Encoding UTF8
}

# ── HELP ─────────────────────────────────────────────────────────────────────

function Invoke-Help {
    param([string]$Query = '')

    # Build content lines from cheatsheet + registered tools
    $lines = [System.Collections.Generic.List[string]]::new()

    if (Test-Path $Cheatsheet) {
        $lines.AddRange([string[]](Get-Content $Cheatsheet))
    }

    # Dynamically append registered tools section
    $toolsData = Get-ToolsData
    if ($toolsData.tools.Count -gt 0) {
        $lines.Add('')
        $lines.Add('## Your Registered Tools')
        $lines.Add('')
        $lines.Add('| Tool | Description |')
        $lines.Add('|------|-------------|')
        foreach ($t in $toolsData.tools) {
            $lines.Add("| ``$($t.name)`` | $($t.description) |")
        }
    }

    # ── Filter by query (substring, case-insensitive) ────────────────────────
    if ($Query) {
        $filtered = $lines | Where-Object { $_ -match [regex]::Escape($Query) }
        if (-not $filtered) {
            Write-Host "No results for '$Query'" -ForegroundColor Yellow
            return
        }
        $lines = [System.Collections.Generic.List[string]]$filtered
    }

    # ── Interactive fzf mode when no query given ─────────────────────────────
    $hasFzf = [bool](Get-Command fzf -ErrorAction SilentlyContinue)
    if (-not $Query -and $hasFzf) {
        $lines | fzf --no-sort --layout=reverse `
            --header='dotfiles help  (type to filter, Enter to select, Esc to quit)' `
            --prompt='Search> '
        return
    }

    # ── Plain coloured output ─────────────────────────────────────────────────
    foreach ($line in $lines) {
        if ($line -match '^# ') {
            Write-Host $line -ForegroundColor Magenta
        } elseif ($line -match '^## ') {
            Write-Host "`n$line" -ForegroundColor Cyan
        } elseif ($line -match '^### ') {
            Write-Host $line -ForegroundColor Yellow
        } elseif ($line -match '^\|[-| ]+\|') {
            # markdown table separator row — skip
        } elseif ($line -match '^\|') {
            Write-Host $line -ForegroundColor White
        } else {
            Write-Host $line
        }
    }
}

# ── LIST ─────────────────────────────────────────────────────────────────────

function Invoke-List {
    $data = Get-ToolsData
    if ($data.tools.Count -eq 0) {
        Write-Host "No tools registered yet." -ForegroundColor Yellow
        Write-Host "Use: dotfiles register <name> -Description '...'" -ForegroundColor DarkGray
        return
    }
    Write-Host "`nRegistered tools in bin/" -ForegroundColor Cyan
    Write-Host ""
    foreach ($t in $data.tools) {
        Write-Host ("  {0}  {1}" -f $t.name.PadRight(22), $t.description) -ForegroundColor White
        Write-Host ("  {0}  → {1}" -f (' ' * 22), $t.path) -ForegroundColor DarkGray
    }
    Write-Host ""
}

# ── REGISTER ─────────────────────────────────────────────────────────────────

function Invoke-Register {
    param([string]$Name, [string]$Desc)

    if (-not $Name) {
        Write-Host "Usage: dotfiles register <name> [-Description '...']" -ForegroundColor Yellow
        return
    }

    $relPath   = "bin/$Name"
    $binScript = Join-Path $DotfilesRoot "bin\$Name"
    $binPs1    = Join-Path $DotfilesRoot "bin\$Name.ps1"

    if (-not (Test-Path $binScript) -and -not (Test-Path $binPs1)) {
        Write-Host "  ⚠ bin/$Name (or bin/$Name.ps1) not found on disk — registering anyway." -ForegroundColor Yellow
    }

    $data      = Get-ToolsData
    $toolsList = [System.Collections.Generic.List[object]]::new()
    foreach ($item in $data.tools) { $toolsList.Add($item) }

    $existing = $toolsList | Where-Object { $_.name -eq $Name } | Select-Object -First 1
    if ($existing) {
        $existing.description = $Desc
        $existing.path        = $relPath
        Write-Host "  ✓ Updated   : $Name" -ForegroundColor Green
    } else {
        $toolsList.Add([pscustomobject]@{
            name        = $Name
            path        = $relPath
            description = $Desc
        })
        Write-Host "  ✓ Registered: $Name" -ForegroundColor Green
    }

    $data.tools = $toolsList.ToArray()
    Save-ToolsData $data
    Write-Host "  → shared/tools.json updated" -ForegroundColor DarkGray
}

# ── UPDATE ────────────────────────────────────────────────────────────────────

function Invoke-Update {
    Write-Host "Pulling latest dotfiles from origin..." -ForegroundColor Cyan
    Push-Location $DotfilesRoot
    try {
        git --no-pager pull --ff-only
        Write-Host "Reloading `$PROFILE..." -ForegroundColor Cyan
        . $PROFILE
        Write-Host "Done." -ForegroundColor Green
    } finally {
        Pop-Location
    }
}

# ── EDIT ─────────────────────────────────────────────────────────────────────

function Invoke-Edit {
    $editor = $env:EDITOR
    if (-not $editor) {
        if   (Get-Command code     -ErrorAction SilentlyContinue) { $editor = 'code'    }
        elseif (Get-Command notepad++ -ErrorAction SilentlyContinue) { $editor = 'notepad++' }
        else { $editor = 'notepad' }
    }
    Write-Host "Opening dotfiles in '$editor'..." -ForegroundColor Cyan
    & $editor $DotfilesRoot
}

# ── Dispatch ─────────────────────────────────────────────────────────────────

switch ($Command.ToLower()) {
    'help'     { Invoke-Help     -Query       $Arg1 }
    'list'     { Invoke-List }
    'register' { Invoke-Register -Name $Arg1 -Desc $Description }
    'update'   { Invoke-Update }
    'edit'     { Invoke-Edit }
    default {
        Write-Host "Unknown subcommand: '$Command'" -ForegroundColor Red
        Write-Host "Usage: dotfiles <help|list|register|update|edit>" -ForegroundColor Yellow
        exit 1
    }
}
