# powershell/aliases.ps1 — Linux-style aliases and quality-of-life functions
# Owner: Trinity  |  Load order: 1st
# Source of truth for what each alias does: shared/aliases.json
# Functions are used instead of Set-Alias where arguments must be forwarded.

# ── Listing ──────────────────────────────────────────────────────────────────
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

# ── Search ────────────────────────────────────────────────────────────────────
if (Get-Command rg -ErrorAction SilentlyContinue) {
    function grep { rg @args }
} else {
    function grep { Select-String @args }
}

# ── File viewing ──────────────────────────────────────────────────────────────
if (Get-Command bat -ErrorAction SilentlyContinue) {
    function cat { bat --style=plain @args }
} else {
    function cat { Get-Content @args }
}

# ── File finding ──────────────────────────────────────────────────────────────
if (Get-Command fd -ErrorAction SilentlyContinue) {
    function find { fd @args }
} else {
    function find { Get-ChildItem -Recurse @args }
}

# ── Navigation ────────────────────────────────────────────────────────────────
function .. { Set-Location .. }
function ... { Set-Location ..\.. }
function .... { Set-Location ..\..\.. }

function up {
    <#
    .SYNOPSIS
      Go up N parent directories.  E.g. `up 3`
    #>
    param([int]$n = 1)
    $path = '..'
    for ($i = 1; $i -lt $n; $i++) { $path = Join-Path $path '..' }
    Set-Location $path
}

function mkcd {
    <#
    .SYNOPSIS
      Create a directory (including parents) and cd into it.
    #>
    param([Parameter(Mandatory)][string]$path)
    New-Item -ItemType Directory -Force -Path $path | Out-Null
    Set-Location $path
}

function cdot {
    if ($env:DOTFILES) { Set-Location $env:DOTFILES }
    else { Write-Warning '$env:DOTFILES is not set' }
}

# ── File / system helpers ─────────────────────────────────────────────────────
function touch {
    <#
    .SYNOPSIS
      Create file if it doesn't exist; update its LastWriteTime if it does.
    #>
    param([Parameter(Mandatory, ValueFromRemainingArguments)][string[]]$paths)
    foreach ($p in $paths) {
        if (Test-Path $p) {
            (Get-Item $p).LastWriteTime = [datetime]::Now
        } else {
            New-Item -ItemType File -Path $p | Out-Null
        }
    }
}

function which {
    param([Parameter(Mandatory)][string]$name)
    Get-Command $name -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
}

function mkdir {
    <#
    .SYNOPSIS
      mkdir -p behaviour: create directory and all parents, silently.
    #>
    param([Parameter(Mandatory, ValueFromRemainingArguments)][string[]]$paths)
    foreach ($p in $paths) {
        New-Item -ItemType Directory -Force -Path $p | Out-Null
    }
}

function df  { Get-PSDrive -PSProvider FileSystem @args }
function du  {
    param([string]$path = '.')
    $size = (Get-ChildItem -Recurse -Force -ErrorAction SilentlyContinue $path |
             Measure-Object -Property Length -Sum).Sum
    "{0:N2} MB  {1}" -f ($size / 1MB), (Resolve-Path $path)
}

function head {
    param([int]$n = 10, [Parameter(ValueFromRemainingArguments)][string[]]$rest)
    Get-Content @rest | Select-Object -First $n
}
function tail {
    param([int]$n = 10, [Parameter(ValueFromRemainingArguments)][string[]]$rest)
    Get-Content @rest | Select-Object -Last $n
}

function top  { Get-Process | Sort-Object CPU -Descending | Select-Object -First 20 | Format-Table -AutoSize }
function psg  { param([string]$name) Get-Process | Where-Object { $_.Name -like "*$name*" } }

# ── Environment ───────────────────────────────────────────────────────────────
function env   { Get-ChildItem Env: | Sort-Object Name }

function export {
    <#
    .SYNOPSIS
      Linux-style  export NAME=VALUE  →  $env:NAME = 'VALUE'
    #>
    param([Parameter(Mandatory)][string]$assignment)
    $parts = $assignment -split '=', 2
    if ($parts.Count -ne 2) { Write-Error "Usage: export NAME=VALUE"; return }
    [System.Environment]::SetEnvironmentVariable($parts[0], $parts[1], 'Process')
}

# ── Sudo ──────────────────────────────────────────────────────────────────────
if (Get-Command gsudo -ErrorAction SilentlyContinue) {
    function sudo { gsudo @args }
}

# ── Open / Explorer ───────────────────────────────────────────────────────────
function open     { param([string]$target = '.') Invoke-Item $target }
function explorer { param([string]$target = '.') explorer.exe $target }

# ── Profile reload ────────────────────────────────────────────────────────────
function reload {
    Write-Host "Reloading profile…" -ForegroundColor Cyan
    . $PROFILE
}

# ── Git shortcuts ─────────────────────────────────────────────────────────────
function g    { git @args }
function ga   { git add @args }
function gc   { git commit @args }
function gst  { git status @args }
function gp   { git push @args }
function gl   { git log --oneline --graph --decorate @args }
function gd   { git diff @args }
function gco  { git checkout @args }
function gb   { git branch @args }

