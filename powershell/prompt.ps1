# powershell/prompt.ps1 — Oh My Posh prompt initialisation
# Owner: Trinity  |  Load order: 3rd
#
# REQUIRES: A Nerd Font installed and set as your terminal font.
# Recommended: CaskaydiaCove Nerd Font, JetBrainsMono Nerd Font, or MesloLGS NF.
# In Windows Terminal: Settings → Profile → Appearance → Font face.
#
# Theme: $env:DOTFILES\powershell\themes\dotfiles.omp.json  (repo-local, no hardcoded paths)
# Falls back to the built-in "jandedobbeleer" theme if the repo theme file is missing.
# Falls back to a minimal plain-text prompt if oh-my-posh is not installed.

if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {

    # Prefer the repo-local theme; fall back to a reliable built-in
    $_ompTheme = if ($env:DOTFILES -and (Test-Path "$env:DOTFILES\powershell\themes\dotfiles.omp.json")) {
        "$env:DOTFILES\powershell\themes\dotfiles.omp.json"
    } elseif ($env:POSH_THEMES_PATH -and (Test-Path "$env:POSH_THEMES_PATH\jandedobbeleer.omp.json")) {
        "$env:POSH_THEMES_PATH\jandedobbeleer.omp.json"
    } else {
        $null
    }

    if ($_ompTheme) {
        oh-my-posh init pwsh --config $_ompTheme | Invoke-Expression
    } else {
        oh-my-posh init pwsh | Invoke-Expression
    }

    Remove-Variable _ompTheme

} else {
    # Graceful plain-text fallback — no oh-my-posh required
    function prompt {
        $branch = ''
        if (Get-Command git -ErrorAction SilentlyContinue) {
            $ref = git symbolic-ref --short HEAD 2>$null
            if ($ref) { $branch = " [$ref]" }
        }
        $path = $executionContext.SessionState.Path.CurrentLocation
        "$path$branch`n> "
    }
}

