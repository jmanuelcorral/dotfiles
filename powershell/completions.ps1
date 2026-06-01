# powershell/completions.ps1 — Argument completers and module imports
# Owner: Trinity  |  Load order: 4th

# ── Terminal-Icons ────────────────────────────────────────────────────────────
if (Get-Module Terminal-Icons -ListAvailable -ErrorAction SilentlyContinue) {
    Import-Module Terminal-Icons -ErrorAction SilentlyContinue
}

# ── posh-git ──────────────────────────────────────────────────────────────────
if (Get-Module posh-git -ListAvailable -ErrorAction SilentlyContinue) {
    Import-Module posh-git -ErrorAction SilentlyContinue
}

# ── zoxide (smarter cd) ───────────────────────────────────────────────────────
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
}

# ── PSFzf (fzf integration) ───────────────────────────────────────────────────
if ((Get-Command fzf -ErrorAction SilentlyContinue) -and
    (Get-Module PSFzf -ListAvailable -ErrorAction SilentlyContinue)) {
    Import-Module PSFzf -ErrorAction SilentlyContinue
    Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t'
    Set-PsFzfOption -PSReadlineChordReverseHistory 'Ctrl+r'
}

# ── winget argument completer ─────────────────────────────────────────────────
# Sourced from the official winget completion script
if (Get-Command winget -ErrorAction SilentlyContinue) {
    Register-ArgumentCompleter -Native -CommandName winget -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)
        [Console]::InputEncoding = [Console]::OutputEncoding = [System.Text.Utf8Encoding]::new()
        $local:word = $wordToComplete.Replace('"', '\"')
        $local:ast  = $commandAst.ToString().Replace('"', '\"')
        winget complete --word="$local:word" --commandline "$local:ast" --position $cursorPosition |
            ForEach-Object {
                [System.Management.Automation.CompletionResult]::new(
                    $_, $_, 'ParameterValue', $_)
            }
    }
}

# ── dotnet argument completer ─────────────────────────────────────────────────
if (Get-Command dotnet -ErrorAction SilentlyContinue) {
    Register-ArgumentCompleter -Native -CommandName dotnet -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)
        dotnet complete --position $cursorPosition "$($commandAst.ToString())" 2>$null |
            ForEach-Object {
                [System.Management.Automation.CompletionResult]::new(
                    $_, $_, 'ParameterValue', $_)
            }
    }
}

# ── gh (GitHub CLI) ───────────────────────────────────────────────────────────
if (Get-Command gh -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (gh completion -s powershell | Out-String) })
}

# ── scoop ─────────────────────────────────────────────────────────────────────
if (Get-Command scoop -ErrorAction SilentlyContinue) {
    # scoop uses PowerShell-native param completion; no extra setup needed
    # Import scoop's own module if present
    $scoopCompleter = "$env:USERPROFILE\scoop\apps\scoop\current\supporting\completion\Scoop.psm1"
    if (Test-Path $scoopCompleter) {
        Import-Module $scoopCompleter -ErrorAction SilentlyContinue
    }
}

