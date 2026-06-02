# Trinity — History

## Seed Context

- **Project:** dotfiles — portable terminal/shell configuration repo
- **Stack:** PowerShell (latest), Git, Python, Node.js, Oh My Posh
- **Goals:** modular fast $PROFILE; Linux-style aliases; PSReadLine config; fix Oh My Posh errors. Profile must guard missing tools so it never breaks on a fresh machine.
- **Requested by:** Copilot (git user.name)

## Learnings

### 2026-06-01 — Initial PowerShell config implementation

**Oh My Posh fix**
- Old profile pointed at `C:\Users\josecorral\poshv3.json` which didn't exist → startup error every time.
- Fix: ship the theme inside the repo at `powershell/themes/dotfiles.omp.json`.
- `prompt.ps1` resolves the path via `$env:DOTFILES` — zero hardcoded user paths.
- Fallback chain: repo theme → `$env:POSH_THEMES_PATH\jandedobbeleer.omp.json` → plain-text prompt.

**PSReadLine VT guard**
- `Set-PSReadLineOption -PredictionViewStyle ListView` throws in non-VT consoles (e.g. pwsh -NoProfile in a test runner).
- Guard: check `$Host.UI.RawUI.WindowSize.Width -gt 0` before enabling ListView; always safe to skip in non-interactive.

**Key file paths**
- `powershell/profile.ps1` — main entry, dot-sources everything in order
- `powershell/aliases.ps1` — Linux-style wrappers + git shortcuts
- `powershell/psreadline.ps1` — PSReadLine modern config (VT-guarded)
- `powershell/prompt.ps1` — OMP init, guarded, no hardcoded paths
- `powershell/completions.ps1` — winget, dotnet, gh, posh-git, zoxide, PSFzf
- `powershell/themes/dotfiles.omp.json` — custom clean Nerd Font theme (Tokyo Night palette)
- `shared/aliases.json` — canonical cross-shell alias catalog (Trinity + Tank read this)

**Modules auto-load**
- `powershell/modules/*.ps1` are dot-sourced alphabetically after the 4 core files; safe to add drop-ins.

**All guards**
- Every external tool uses `Get-Command X -ErrorAction SilentlyContinue` before use.
- Profile is safe on a fresh machine with nothing installed.


### 2026-06-02 — Phase 3: Invoke-AgentQuery (llama-cli inference)

**What was implemented**
- Added `Invoke-AgentQuery` (exported) to `powershell/modules/dotfiles-agent.psm1`.
- Added internal helpers `_Build-AgentPrompt`, `_Post-ProcessAgentOutput`, `_Format-ProcArg`.
- Replaced the PHASE 3 PLACEHOLDER stub in `bin/dotfiles.ps1` `Invoke-Agent` with real wiring.

**Prompt serialization contract (for Tank parity)**
- Shell type token: `"windows-powershell"` (literal string).
- Tools block: one line `"- {name}: {description}"` per tool; `"(none registered)"` when empty.
- Aliases block: one line per alias key (skip `_`-prefixed metadata); format:
  `"- {key}: {_note} [win: {windows}] [unix: {unix}]"` — bracket omitted when field absent.
- ChatML envelope (LF line endings, no BOM):
  ```
  <|im_start|>system\n{filled-system-prompt}\n<|im_end|>\n
  (for each few-shot object in few-shot.json:)
  <|im_start|>{role}\n{content}\n<|im_end|>\n
  <|im_start|>user\n{Query}\n<|im_end|>\n
  <|im_start|>assistant\n
  ```
  (model appends completion after the final `\n`)

**llama-cli flags (b9469)**
`-m <model> -f <promptfile> --no-display-prompt -no-cnv --log-disable -n <n_predict> --temp <temp>`
Prompt is written to a UTF-8 (no BOM) temp file via `[System.IO.File]::WriteAllText` to avoid all shell quoting issues.

**Exit codes / degradation**
- 2 = engine binary missing (prints "Agent engine not installed. Run: dotfiles agent --setup")
- 3 = model file missing (prints "No model found. Run: dotfiles agent --setup")
- 4 = timeout (kills process, prints advisory to use --fallback)
- 1 = "# Cannot build: …" from model, or empty output
- 0 = success

**UX**
- Default: prints the command in Cyan; best-effort `Set-Clipboard` (guarded, never fatal).
- `--run` flag: prompts `Execute? [y/N]` before `Invoke-Expression`.

**PS 5.1 / 7 compatibility notes**
- Used `New-Object System.Diagnostics.ProcessStartInfo/Process` (not `::new()`) for max compat.
- `WaitForExit(ms)` timeout with `ReadToEndAsync()` started before wait to prevent stdout deadlock.
- `[System.IO.File]::WriteAllText` with `[System.Text.UTF8Encoding]::new($false)` for no-BOM UTF-8.


