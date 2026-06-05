<#
.SYNOPSIS
    dotfiles CLI — manage your versioned dotfiles, tools, aliases, and local AI agent.
.DESCRIPTION
    Subcommands:
        help    [query]            Show the command cheatsheet + registered tools.
                                   With no arguments, launches fzf (if available)
                                   for interactive fuzzy search; otherwise prints
                                   all entries. With a query, filters to matching lines.
        list                       List all tools registered in shared/tools.json.
        version                    Show the current VERSION and git commit.
        register <name>            Register (or update) a script in bin/ into
                                   shared/tools.json. Use -Description to describe it.
        update                     Fast-forward pull, report version changes, rerun install,
                                   and reload $PROFILE.
        edit                       Open the dotfiles repo in $EDITOR / VS Code / notepad.
        explain <alias-or-tool>    Show the definition and both-shell forms of an alias
                                   or registered tool — fully offline, no model needed.
                                   Falls back to running '<cmd> --help' when not found.
        agent --setup [--fallback] Download the llama-cli engine and Qwen2.5-Coder model
                                   into cache/. Use --fallback for the smaller 0.5B model.
        agent "<query>"            Generate a shell command via local inference.
        agent "<query>" --run      Generate and prompt to execute.
        skills list                List available skills in skills/ with their descriptions.
        skills path                Print the absolute path of the skills/ directory.
        skills install [target]    Copy all skills into <target>\.copilot\skills\.
                                   Default target = current directory. Idempotent.
.PARAMETER Command
    Subcommand to run. Default: help.
.PARAMETER Arg1
    First positional argument (tool name for 'register'/'explain', query for 'help',
    or flag like '--setup' for 'agent').
.PARAMETER Description
    Description string for 'register'.
.EXAMPLE
    dotfiles help
    dotfiles help git
    dotfiles explain ll
    dotfiles explain gst
    dotfiles register gituseswitch -Description "Switch git user identity"
    dotfiles list
    dotfiles version
    dotfiles update
    dotfiles edit
    dotfiles agent --setup
    dotfiles agent --setup --fallback
    dotfiles skills list
    dotfiles skills path
    dotfiles skills install
    dotfiles skills install C:\Projects\myapp
#>
param(
    [Parameter(Position = 0)] [string]$Command     = 'help',
    [Parameter(Position = 1)] [string]$Arg1        = '',
    [Parameter(Position = 2)] [string]$Arg2        = '',
    [string]$Description = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Resolve the repo root: bin/dotfiles.ps1 → parent is repo root
$DotfilesRoot = if ($env:DOTFILES) { $env:DOTFILES } else { Split-Path $PSScriptRoot -Parent }
$ToolsJson    = Join-Path $DotfilesRoot 'shared\tools.json'
$AliasesJson  = Join-Path $DotfilesRoot 'shared\aliases.json'
$Cheatsheet   = Join-Path $DotfilesRoot 'docs\cheatsheet.md'
$VersionFile  = Join-Path $DotfilesRoot 'VERSION'
$Changelog    = Join-Path $DotfilesRoot 'CHANGELOG.md'

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

function Get-DotfilesVersion {
    if (Test-Path $VersionFile) {
        $version = (Get-Content $VersionFile -TotalCount 1).Trim()
        if ($version) { return $version }
    }
    '0.0.0'
}

function Get-DotfilesGitSha {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { return '' }

    Push-Location $DotfilesRoot
    try {
        $sha = git rev-parse --short HEAD 2>$null
        if ($LASTEXITCODE -eq 0 -and $sha) { return $sha.Trim() }
    } finally {
        Pop-Location
    }
    ''
}

function Write-ChangelogSection {
    param([string]$Version)

    if (-not (Test-Path $Changelog)) { return }

    $lines = Get-Content $Changelog
    $pattern = '^\#\#\s+\[?' + [regex]::Escape($Version) + '\]?(\s+-\s+.*)?$'
    $start = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match $pattern) {
            $start = $i
            break
        }
    }
    if ($start -lt 0) { return }

    $section = [System.Collections.Generic.List[string]]::new()
    for ($i = $start; $i -lt $lines.Count; $i++) {
        if ($i -gt $start -and $lines[$i] -match '^##\s+') { break }
        $section.Add($lines[$i])
    }

    if ($section.Count -gt 0) {
        Write-Host ""
        Write-Host "Changelog for v$Version" -ForegroundColor Cyan
        $section | Select-Object -Skip 1 | ForEach-Object { Write-Host $_ }
    }
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

# ── VERSION ──────────────────────────────────────────────────────────────────

function Invoke-Version {
    $version = Get-DotfilesVersion
    $sha = Get-DotfilesGitSha
    if ($sha) {
        Write-Host "dotfiles v$version ($sha)"
    } else {
        Write-Host "dotfiles v$version"
    }
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
    $oldVersion = Get-DotfilesVersion

    Write-Host "Pulling latest dotfiles from origin..." -ForegroundColor Cyan
    Push-Location $DotfilesRoot
    try {
        $branch = git rev-parse --abbrev-ref HEAD 2>$null
        if ($LASTEXITCODE -eq 0 -and $branch -and $branch.Trim() -ne 'HEAD') {
            git --no-pager pull --ff-only origin $branch.Trim()
        } else {
            git --no-pager pull --ff-only
        }
        if ($LASTEXITCODE -ne 0) {
            throw "git pull --ff-only failed with exit code $LASTEXITCODE"
        }
    } finally {
        Pop-Location
    }

    $newVersion = Get-DotfilesVersion
    if ($oldVersion -eq $newVersion) {
        Write-Host "dotfiles: v$newVersion (already up to date)" -ForegroundColor Green
    } else {
        Write-Host "dotfiles: v$oldVersion → v$newVersion" -ForegroundColor Green
        Write-ChangelogSection -Version $newVersion
    }

    $installer = Join-Path $DotfilesRoot 'bootstrap\install.ps1'
    if (Test-Path $installer) {
        Write-Host "Re-running installer to apply updates..." -ForegroundColor Cyan
        & $installer
    } else {
        Write-Host "Installer not found at $installer — skipping bootstrap." -ForegroundColor Yellow
    }

    if (Test-Path $PROFILE) {
        Write-Host "Reloading `$PROFILE..." -ForegroundColor Cyan
        . $PROFILE
    }
    Write-Host "Done." -ForegroundColor Green
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

# ── EXPLAIN (offline) ────────────────────────────────────────────────────────

function Invoke-Explain {
    param([string]$Name)

    if (-not $Name) {
        Write-Host "Usage: dotfiles explain <alias-or-tool>" -ForegroundColor Yellow
        return
    }

    # 1. Look up in aliases.json
    if (Test-Path $AliasesJson) {
        $aliases = (Get-Content $AliasesJson -Raw | ConvertFrom-Json).aliases
        # PSCustomObject property lookup — use Get-Member to check existence
        $aliasEntry = $null
        if ($null -ne $aliases -and ($aliases | Get-Member -Name $Name -ErrorAction SilentlyContinue)) {
            $aliasEntry = $aliases.$Name
        }
        if ($null -ne $aliasEntry) {
            $note    = if ($aliasEntry | Get-Member -Name '_note'   -ErrorAction SilentlyContinue) { $aliasEntry.'_note'   } else { '' }
            $winForm = if ($aliasEntry | Get-Member -Name 'windows' -ErrorAction SilentlyContinue) { $aliasEntry.windows } else { '(not defined)' }
            $nixForm = if ($aliasEntry | Get-Member -Name 'unix'    -ErrorAction SilentlyContinue) { $aliasEntry.unix    } else { '(not defined)' }

            Write-Host ""
            Write-Host "  $Name — $note" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "  Windows (PowerShell):" -ForegroundColor Yellow
            Write-Host "    $winForm" -ForegroundColor White
            Write-Host ""
            Write-Host "  Unix (bash/zsh):" -ForegroundColor Yellow
            Write-Host "    $nixForm" -ForegroundColor White
            Write-Host ""
            return
        }
    }

    # 2. Look up in tools.json
    $data = Get-ToolsData
    $tool = $data.tools | Where-Object { $_.name -eq $Name } | Select-Object -First 1
    if ($null -ne $tool) {
        Write-Host ""
        Write-Host "  $Name — $($tool.description)" -ForegroundColor Cyan
        Write-Host "  Path: $($tool.path)" -ForegroundColor DarkGray
        Write-Host ""
        return
    }

    # 3. Fall back to --help (first 20 lines) if the command exists
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($null -ne $cmd) {
        Write-Host "  '$Name' not in registry — showing --help output:" -ForegroundColor DarkGray
        Write-Host ""
        try {
            & $Name --help 2>&1 | Select-Object -First 20 | ForEach-Object { Write-Host "  $_" }
        } catch {
            Write-Host "  (could not run '$Name --help')" -ForegroundColor DarkGray
        }
        Write-Host ""
        return
    }

    # 4. Nothing found
    Write-Host "  '$Name' not found in aliases.json, tools.json, or PATH." -ForegroundColor Yellow
    Write-Host "  Try: dotfiles help $Name" -ForegroundColor DarkGray
}

# ── AGENT ─────────────────────────────────────────────────────────────────────

function Invoke-Agent {
    param([string]$Subarg, [string]$ExtraFlag)

    $psm1Path = Join-Path $DotfilesRoot 'powershell\modules\dotfiles-agent.psm1'

    if ($Subarg -eq '--setup') {
        if (-not (Test-Path $psm1Path)) {
            Write-Host "Agent module not found at: $psm1Path" -ForegroundColor Red
            exit 1
        }
        Import-Module $psm1Path -Force
        $useFallback = ($ExtraFlag -eq '--fallback')
        Install-AgentEngine -Fallback:$useFallback
        return
    }

    # ── Query inference (Phase 3) ─────────────────────────────────────────────
    # A non-empty $Subarg that doesn't start with '--' is the natural-language query.
    # $ExtraFlag == '--run' → pass -Run to Invoke-AgentQuery (prompt before execute).
    if ($Subarg -and -not $Subarg.StartsWith('--')) {
        if (-not (Test-Path $psm1Path)) {
            Write-Host "Agent module not found at: $psm1Path" -ForegroundColor Red
            exit 2
        }
        Import-Module $psm1Path -Force
        $runFlag = ($ExtraFlag -eq '--run')
        $result  = Invoke-AgentQuery -Query $Subarg -Run:$runFlag
        # Map result exit codes: 0=ok, 1=cannot-build, 2=engine missing,
        #                        3=model missing, 4=timeout
        exit $result.ExitCode
    }

    # Unknown flag or bare 'agent' with no args
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  dotfiles agent --setup             Download engine + primary model" -ForegroundColor White
    Write-Host "  dotfiles agent --setup --fallback  Download engine + 0.5B model" -ForegroundColor White
    Write-Host "  dotfiles agent ""<query>""           Generate a shell command" -ForegroundColor White
    Write-Host "  dotfiles agent ""<query>"" --run     Generate and prompt to execute" -ForegroundColor White
}



# ── SKILLS ────────────────────────────────────────────────────────────────────

function Invoke-Skills {
    param([string]$Action, [string]$Target)

    $SkillsRoot = Join-Path $DotfilesRoot 'skills'

    if (-not (Test-Path $SkillsRoot)) {
        Write-Host "  ⚠ skills/ directory not found at: $SkillsRoot" -ForegroundColor Yellow
        return
    }

    switch ($Action.ToLower()) {
        'list' {
            $skillDirs = Get-ChildItem $SkillsRoot -Directory
            if ($skillDirs.Count -eq 0) {
                Write-Host "No skills found in $SkillsRoot" -ForegroundColor Yellow
                return
            }
            Write-Host "`nAvailable skills in skills/" -ForegroundColor Cyan
            Write-Host ""
            foreach ($dir in $skillDirs) {
                $skillFile = Join-Path $dir.FullName 'SKILL.md'
                $desc = ''
                if (Test-Path $skillFile) {
                    $raw = Get-Content $skillFile -Raw
                    if ($raw -match '(?m)^description:\s*"?([^"\r\n]+)"?') {
                        $desc = $Matches[1].Trim()
                    }
                }
                Write-Host ("  {0}  {1}" -f $dir.Name.PadRight(30), $desc) -ForegroundColor White
            }
            Write-Host ""
        }
        'path' {
            Write-Host $SkillsRoot
        }
        'install' {
            $destBase = if ($Target) { $Target } else { $PWD.Path }
            $destSkills = Join-Path $destBase '.copilot\skills'

            $skillDirs = Get-ChildItem $SkillsRoot -Directory
            if ($skillDirs.Count -eq 0) {
                Write-Host "No skills to install (skills/ is empty)." -ForegroundColor Yellow
                return
            }

            New-Item -ItemType Directory -Path $destSkills -Force | Out-Null

            $count = 0
            foreach ($dir in $skillDirs) {
                $destSkill = Join-Path $destSkills $dir.Name
                Copy-Item -Path $dir.FullName -Destination $destSkill -Recurse -Force
                Write-Host "  ✓ $($dir.Name)" -ForegroundColor Green
                $count++
            }
            Write-Host ""
            Write-Host "  $count skill(s) installed → $destSkills" -ForegroundColor Cyan
        }
        default {
            Write-Host "Usage:" -ForegroundColor Yellow
            Write-Host "  dotfiles skills list                List available skills with descriptions" -ForegroundColor White
            Write-Host "  dotfiles skills path                Print the skills/ directory path" -ForegroundColor White
            Write-Host "  dotfiles skills install [target]    Copy skills into <target>\.copilot\skills\" -ForegroundColor White
        }
    }
}




switch ($Command.ToLower()) {
    'help'     { Invoke-Help     -Query       $Arg1 }
    'list'     { Invoke-List }
    'version'  { Invoke-Version }
    'register' { Invoke-Register -Name $Arg1 -Desc $Description }
    'update'   { Invoke-Update }
    'edit'     { Invoke-Edit }
    'explain'  { Invoke-Explain  -Name        $Arg1 }
    'agent'    { Invoke-Agent    -Subarg $Arg1 -ExtraFlag $Arg2 }
    'skills'   { Invoke-Skills   -Action $Arg1 -Target $Arg2 }
    default {
        Write-Host "Unknown subcommand: '$Command'" -ForegroundColor Red
        Write-Host "Usage: dotfiles <help|list|version|register|update|edit|explain|agent|skills>" -ForegroundColor Yellow
        exit 1
    }
}
