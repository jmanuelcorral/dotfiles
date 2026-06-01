# powershell/profile.ps1 — Repo-side main entry point
# Owner: Trinity
#
# System $PROFILE should contain ONLY the thin stub (written by Switch/bootstrap):
#   $env:DOTFILES = "<clone-path>"
#   . "$env:DOTFILES\powershell\profile.ps1"
#
# DO NOT edit the system $PROFILE manually — edit files here instead.

# Resolve the repo root (fallback: derive from this script's location)
if (-not $env:DOTFILES) {
    $env:DOTFILES = Split-Path (Split-Path $PSCommandPath -Parent) -Parent
}

$_dot = $env:DOTFILES

# ── 1. Aliases ────────────────────────────────────────────────────────────────
. "$_dot\powershell\aliases.ps1"

# ── 2. PSReadLine ─────────────────────────────────────────────────────────────
. "$_dot\powershell\psreadline.ps1"

# ── 3. Prompt (Oh My Posh) ────────────────────────────────────────────────────
. "$_dot\powershell\prompt.ps1"

# ── 4. Completions + module imports ──────────────────────────────────────────
. "$_dot\powershell\completions.ps1"

# ── 5. Drop-in modules (alphabetical) ────────────────────────────────────────
$_modulesDir = "$_dot\powershell\modules"
if (Test-Path $_modulesDir) {
    Get-ChildItem -Path $_modulesDir -Filter '*.ps1' |
        Sort-Object Name |
        ForEach-Object { . $_.FullName }
}

# ── 6. Add bin/ to PATH ───────────────────────────────────────────────────────
$_binDir = "$_dot\bin"
if ((Test-Path $_binDir) -and ($env:PATH -notlike "*$_binDir*")) {
    $env:PATH = "$_binDir$([IO.Path]::PathSeparator)$env:PATH"
}

Remove-Variable _dot, _modulesDir, _binDir -ErrorAction SilentlyContinue

