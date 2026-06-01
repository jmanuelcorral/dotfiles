# powershell/psreadline.ps1 — PSReadLine modern configuration
# Owner: Trinity  |  Load order: 2nd

# Bail out gracefully if PSReadLine isn't loaded or we're not in an interactive terminal
if (-not (Get-Module PSReadLine -ErrorAction SilentlyContinue)) { return }
if (-not [System.Environment]::UserInteractive) { return }
# In VS Code integrated terminal or non-VT console, skip ListView to avoid startup errors
$_vtSupported = $Host.UI.RawUI -and $Host.UI.RawUI.WindowSize.Width -gt 0

# ── Prediction / History ──────────────────────────────────────────────────────
Set-PSReadLineOption -PredictionSource HistoryAndPlugin
if ($_vtSupported) {
    Set-PSReadLineOption -PredictionViewStyle ListView
}
Set-PSReadLineOption -HistorySearchCursorMovesToEnd
Set-PSReadLineOption -MaximumHistoryCount 10000
Set-PSReadLineOption -HistorySaveStyle SaveIncrementally
Set-PSReadLineOption -HistoryNoDuplicates

# ── Tab completion ────────────────────────────────────────────────────────────
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
Set-PSReadLineKeyHandler -Key Shift+Tab -Function MenuComplete

# ── Arrow key history search ──────────────────────────────────────────────────
Set-PSReadLineKeyHandler -Key UpArrow   -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

# ── Common editing bindings ───────────────────────────────────────────────────
Set-PSReadLineKeyHandler -Key Ctrl+d -Function DeleteCharOrExit
Set-PSReadLineKeyHandler -Key Ctrl+w -Function BackwardDeleteWord
Set-PSReadLineKeyHandler -Key Alt+d  -Function DeleteWord
Set-PSReadLineKeyHandler -Key Ctrl+LeftArrow  -Function BackwardWord
Set-PSReadLineKeyHandler -Key Ctrl+RightArrow -Function ForwardWord
Set-PSReadLineKeyHandler -Key Ctrl+k -Function KillLine
Set-PSReadLineKeyHandler -Key Ctrl+u -Function RevertLine

# ── Ctrl+Z → Undo ─────────────────────────────────────────────────────────────
Set-PSReadLineKeyHandler -Key Ctrl+z -Function Undo

# ── Smart paste (strips trailing newline) ────────────────────────────────────
Set-PSReadLineKeyHandler -Key Ctrl+v -Function Paste

# ── Ctrl+Space → trigger inline prediction accept ────────────────────────────
Set-PSReadLineKeyHandler -Key Ctrl+Spacebar -Function AcceptNextSuggestionWord

# ── F1 → show help for current command ───────────────────────────────────────
Set-PSReadLineKeyHandler -Key F1 -ScriptBlock {
    $token, $ast = $null, $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$ast, [ref]$token, [ref]$null, [ref]$null)
    if ($token) { Get-Help $token.Text -ShowWindow -ErrorAction SilentlyContinue }
}

# ── Ctrl+Alt+? → show all key bindings ───────────────────────────────────────
Set-PSReadLineKeyHandler -Key 'Ctrl+Alt+?' -Function ShowKeyBindings

# ── Syntax highlight colours ─────────────────────────────────────────────────
Set-PSReadLineOption -Colors @{
    Command            = [ConsoleColor]::Cyan
    Parameter          = [ConsoleColor]::DarkCyan
    Operator           = [ConsoleColor]::DarkYellow
    Variable           = [ConsoleColor]::Green
    String             = [ConsoleColor]::DarkGreen
    Number             = [ConsoleColor]::DarkRed
    Type               = [ConsoleColor]::DarkBlue
    Comment            = [ConsoleColor]::DarkGray
    Keyword            = [ConsoleColor]::Magenta
    Error              = [ConsoleColor]::Red
    InlinePrediction   = [ConsoleColor]::DarkGray
    ListPrediction     = [ConsoleColor]::DarkCyan
    ListPredictionSelected = [ConsoleColor]::DarkYellow
}

# ── Ctrl+R → interactive history search (fzf if present, else native) ────────
if (Get-Command fzf -ErrorAction SilentlyContinue) {
    Set-PSReadLineKeyHandler -Key Ctrl+r -ScriptBlock {
        $history = [Microsoft.PowerShell.PSConsoleReadLine]::GetHistoryItems() |
                   Select-Object -ExpandProperty CommandLine |
                   Sort-Object -Unique
        $selected = $history | fzf --height=40% --layout=reverse --border --tac 2>$null
        if ($selected) {
            [Microsoft.PowerShell.PSConsoleReadLine]::Insert($selected)
        }
    }
}

Remove-Variable _vtSupported -ErrorAction SilentlyContinue
