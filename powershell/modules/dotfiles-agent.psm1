#Requires -Version 5.1
<#
.SYNOPSIS
    dotfiles-agent.psm1 — Engine + model bootstrapper for the local AI agent.
.DESCRIPTION
    Owner : Switch
    Phase : 2 (Bootstrap / Installer)

    Exports:
        Install-AgentEngine   Download llama-cli + model; idempotent.
        Get-AgentPaths        Return hashtable of well-known paths (for Trinity Phase 3).
        Test-AgentReady       Return $true if engine binary + at least one model exist.

    NOT IMPLEMENTED HERE (left for Trinity, Phase 3):
        - Prompt assembly
        - llama-cli subprocess invocation
        - Output post-processing
        See placeholder section at the bottom of this file.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── Internal: resolve repo root and config ────────────────────────────────────

function _Get-DotfilesRoot {
    if ($env:DOTFILES) { return $env:DOTFILES }
    # Module lives at <root>/powershell/modules/dotfiles-agent.psm1
    Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
}

function _Get-AgentConfig {
    $root = _Get-DotfilesRoot
    $cfg  = Join-Path $root 'shared\agent-config.json'
    if (-not (Test-Path $cfg)) {
        throw "agent-config.json not found at: $cfg"
    }
    Get-Content $cfg -Raw | ConvertFrom-Json
}

# ── Public: Get-AgentPaths ────────────────────────────────────────────────────

function Get-AgentPaths {
    <#
    .SYNOPSIS
        Return a hashtable of well-known cache paths for the agent.
        Used by Trinity (Phase 3) to locate the engine and model without
        hard-coding paths.
    #>
    $root      = _Get-DotfilesRoot
    $cacheDir  = if ($env:DOTFILES_CACHE) { $env:DOTFILES_CACHE } else { Join-Path $root 'cache' }
    $binDir    = Join-Path $cacheDir 'bin'
    $modelsDir = Join-Path $cacheDir 'models'
    $cfg       = _Get-AgentConfig

    $isWin = ($env:OS -eq 'Windows_NT') -or $IsWindows
    $exeName = if ($isWin) { 'llama-cli.exe' } else { 'llama-cli' }

    $primaryFile  = $cfg.models.primary.file
    $fallbackFile = $cfg.models.fallback.file

    return @{
        Root         = $root
        CacheDir     = $cacheDir
        BinDir       = $binDir
        ModelsDir    = $modelsDir
        EngineBin    = Join-Path $binDir $exeName
        PrimaryModel = Join-Path $modelsDir $primaryFile
        FallbackModel= Join-Path $modelsDir $fallbackFile
        Config       = $cfg
    }
}

# ── Public: Test-AgentReady ───────────────────────────────────────────────────

function Test-AgentReady {
    <#
    .SYNOPSIS
        Returns $true if llama-cli binary exists and at least one model is present.
    .OUTPUTS
        [bool]
    #>
    $paths = Get-AgentPaths
    $binOk = Test-Path $paths.EngineBin
    $modelOk = (Test-Path $paths.PrimaryModel) -or (Test-Path $paths.FallbackModel)
    return ($binOk -and $modelOk)
}

# ── Internal: platform detection ──────────────────────────────────────────────

function _Get-PlatformKey {
    $isWin = ($env:OS -eq 'Windows_NT') -or $IsWindows
    if ($isWin) {
        $arch = $env:PROCESSOR_ARCHITECTURE   # AMD64 or ARM64
        if ($arch -eq 'ARM64') { return 'win-arm64' }
        return 'win-x64'
    } else {
        $m = (uname -m 2>$null)
        if ($m -match 'aarch64|arm64') { return 'linux-arm64' }
        return 'linux-x64'
    }
}

# ── Internal: download with resume ───────────────────────────────────────────

function _Invoke-Download {
    param(
        [string]$Url,
        [string]$Destination,
        [string]$Label
    )
    Write-Host "  Downloading $Label ..." -ForegroundColor Cyan
    Write-Host "    → $Destination" -ForegroundColor DarkGray

    $curlExe = Get-Command 'curl.exe' -ErrorAction SilentlyContinue
    if ($curlExe) {
        # curl.exe -L follows redirects; -C - resumes partial downloads
        & curl.exe -L -C - --progress-bar -o $Destination $Url
        if ($LASTEXITCODE -ne 0) {
            throw "curl.exe failed (exit $LASTEXITCODE) downloading: $Url"
        }
    } else {
        # Fallback: Invoke-WebRequest (no resume, but always available)
        Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing
    }
    Write-Host "  ✓ Downloaded: $Label" -ForegroundColor Green
}

# ── Internal: integrity check ─────────────────────────────────────────────────

function _Test-FileIntegrity {
    param(
        [string]$Path,
        [string]$ExpectedSha256,   # may be $null or empty
        [int]   $ExpectedSizeMb    # expected megabytes; 0 = skip size check
    )
    if (-not (Test-Path $Path)) { return $false }

    # SHA256 check (preferred when available)
    if ($ExpectedSha256 -and $ExpectedSha256 -ne 'null') {
        $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash
        if ($actual -ine $ExpectedSha256) {
            Write-Warning "SHA256 mismatch for $(Split-Path $Path -Leaf)"
            Write-Warning "  expected: $ExpectedSha256"
            Write-Warning "  actual  : $actual"
            return $false
        }
        return $true
    }

    # Fallback: size sanity check. A truncated/failed download is the real risk,
    # so we accept anything from 70% to 150% of the expected size_mb (the exact
    # size can drift across model revisions, but a partial download is far smaller).
    if ($ExpectedSizeMb -gt 0) {
        $sizeMb  = (Get-Item $Path).Length / 1MB
        $low     = $ExpectedSizeMb * 0.7
        $high    = $ExpectedSizeMb * 1.5
        if ($sizeMb -lt $low -or $sizeMb -gt $high) {
            Write-Warning ("Size check failed for {0}: {1:N0} MB (expected ~{2} MB, allowed {3:N0}-{4:N0})" -f (Split-Path $Path -Leaf), $sizeMb, $ExpectedSizeMb, $low, $high)
            return $false
        }
    }
    return $true
}

# ── Public: Install-AgentEngine ───────────────────────────────────────────────

function Install-AgentEngine {
    <#
    .SYNOPSIS
        Download and install the llama-cli engine and a Qwen2.5-Coder model.
    .PARAMETER Fallback
        When set, download the 0.5B fallback model instead of the 1.5B primary.
    .DESCRIPTION
        Idempotent — skips files that are already present and pass integrity checks.
        SHA256 is optional: when null in agent-config.json, file size (±10%) and
        a successful 'llama-cli --version' are used as proof of integrity.
        Does NOT download or run the model on behalf of the user — only downloads
        the binary and GGUF file to cache/.
    #>
    [CmdletBinding()]
    param(
        [switch]$Fallback
    )

    $paths  = Get-AgentPaths
    $cfg    = $paths.Config
    $platKey = _Get-PlatformKey

    Write-Host ""
    Write-Host "=== dotfiles agent --setup ===" -ForegroundColor Magenta
    Write-Host "  Platform : $platKey" -ForegroundColor DarkGray
    Write-Host "  CacheDir : $($paths.CacheDir)" -ForegroundColor DarkGray
    Write-Host ""

    # Low-RAM advisory
    try {
        $ramGb = (Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue).TotalPhysicalMemory / 1GB
        if ($ramGb -le 4) {
            Write-Host "  ⚠  Low RAM detected (~${ramGb:N0} GB). Consider --fallback for the 0.5B model." -ForegroundColor Yellow
        }
    } catch { <# non-fatal #> }

    # Ensure directories exist
    @($paths.BinDir, $paths.ModelsDir) | ForEach-Object {
        if (-not (Test-Path $_)) { New-Item -ItemType Directory -Force -Path $_ | Out-Null }
    }

    # ── Step 1: Engine binary ─────────────────────────────────────────────────
    $assetName = $cfg.engine.assets.$platKey
    if (-not $assetName) {
        throw "No engine asset defined for platform '$platKey' in agent-config.json"
    }

    $engineUrl    = $cfg.engine.base_url + $assetName
    $archivePath  = Join-Path $paths.BinDir $assetName
    $engineSha256 = $cfg.engine.sha256.$platKey   # may be $null

    if (Test-Path $paths.EngineBin) {
        Write-Host "  ✓ Engine already present: $($paths.EngineBin)" -ForegroundColor Green
    } else {
        # Download archive
        if (-not (Test-Path $archivePath)) {
            _Invoke-Download -Url $engineUrl -Destination $archivePath -Label "engine ($assetName)"
        } else {
            Write-Host "  ↩ Resuming archive: $assetName" -ForegroundColor DarkGray
        }

        # Expand archive
        Write-Host "  Extracting $assetName ..." -ForegroundColor Cyan
        if ($assetName -match '\.zip$') {
            Expand-Archive -Path $archivePath -DestinationPath $paths.BinDir -Force
        } elseif ($assetName -match '\.tar\.gz$') {
            # tar is available on Windows 10 1803+ via bsdtar
            & tar -xzf $archivePath -C $paths.BinDir
            if ($LASTEXITCODE -ne 0) { throw "tar failed extracting $archivePath" }
        } else {
            throw "Unsupported archive format: $assetName"
        }

        # Unblock all extracted files (Windows Zone.Identifier security mark)
        if (($env:OS -eq 'Windows_NT') -or $IsWindows) {
            Get-ChildItem -LiteralPath $paths.BinDir -Recurse -File |
                ForEach-Object { Unblock-File -LiteralPath $_.FullName -ErrorAction SilentlyContinue }
            Write-Host "  ✓ Unblocked all extracted files" -ForegroundColor DarkGray
        }

        # Remove archive to save space
        Remove-Item -LiteralPath $archivePath -Force -ErrorAction SilentlyContinue

        if (-not (Test-Path $paths.EngineBin)) {
            throw "Engine binary not found after extraction: $($paths.EngineBin)"
        }
        Write-Host "  ✓ Engine extracted: $($paths.EngineBin)" -ForegroundColor Green
    }

    # Verify engine runs
    Write-Host "  Verifying engine ..." -ForegroundColor Cyan
    try {
        $ver = & $paths.EngineBin --version 2>&1
        Write-Host "  ✓ $ver" -ForegroundColor Green
    } catch {
        throw "llama-cli --version failed: $_"
    }

    # ── Step 2: Model ──────────────────────────────────────────────────────────
    $modelCfg   = if ($Fallback) { $cfg.models.fallback } else { $cfg.models.primary }
    $modelPath  = if ($Fallback) { $paths.FallbackModel } else { $paths.PrimaryModel }
    $modelLabel = $modelCfg.name

    if (_Test-FileIntegrity -Path $modelPath -ExpectedSha256 $modelCfg.sha256 -ExpectedSizeMb $modelCfg.size_mb) {
        Write-Host "  ✓ Model already present and valid: $modelPath" -ForegroundColor Green
    } else {
        if (Test-Path $modelPath) {
            Write-Host "  ↩ Partial/invalid model found; re-downloading ..." -ForegroundColor DarkGray
        }
        _Invoke-Download -Url $modelCfg.url -Destination $modelPath -Label "$modelLabel (~$($modelCfg.size_mb) MB)"

        if (-not (_Test-FileIntegrity -Path $modelPath -ExpectedSha256 $modelCfg.sha256 -ExpectedSizeMb $modelCfg.size_mb)) {
            throw "Model integrity check failed for: $modelPath"
        }
        Write-Host "  ✓ Model ready: $modelPath" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "=== Setup complete ===" -ForegroundColor Green
    Write-Host "  Engine : $($paths.EngineBin)" -ForegroundColor White
    Write-Host "  Model  : $modelPath" -ForegroundColor White
    Write-Host ""
    Write-Host "  Run inference (Phase 3): dotfiles agent ""<your query>""" -ForegroundColor DarkGray
}

# ── Internal: prompt assembly ─────────────────────────────────────────────────

function _Build-AgentPrompt {
    <#
    .SYNOPSIS
        Assemble the grounded SYSTEM prompt for llama-cli conversation mode.

    .DESCRIPTION
        PROMPT SERIALIZATION CONTRACT — Tank (bash) must reproduce this exactly.

        llama-cli (b9469) is conversation-only; raw one-shot completion (-no-cnv)
        is rejected ("please use llama-completion instead", which is broken on
        Windows). We therefore run llama-cli in single-turn conversation mode and
        pass this text as the SYSTEM prompt (-sysf), with the live user query as
        the user turn (-p). The model's own chat template wraps both.

        This function returns ONLY the system prompt text (no ChatML tags, no
        user query). Steps:

        1. Read shared/agent/system-prompt.txt as a template.
        2. Replace {{SHELL_TYPE}}    → literal string "windows-powershell"
        3. Replace {{TOOLS_BLOCK}}   → one line per tool from tools.json:
               "- {name}: {description}"
             If tools array is empty → literal "(none registered)"
        4. Replace {{ALIASES_BLOCK}} → one line per alias key in aliases.json.
             Skip any key whose name starts with '_' (metadata keys).
             Line format: "- {key}: {_note} [win: {windows}] [unix: {unix}]"
             Omit [win: ...] bracket entirely when 'windows' field is absent.
             Omit [unix: ...] bracket entirely when 'unix' field is absent.
        5. Append few-shot examples from few-shot.json as plain text. The file is
             a flat array of alternating {role:user}/{role:assistant} objects;
             render each pair as one line "{user-content} => {assistant-content}"
             under an "EXAMPLES:" header.
    #>
    param(
        [hashtable]$Paths
    )

    $root = $Paths.Root

    # ── System prompt template ────────────────────────────────────────────────
    $sysPromptPath = Join-Path $root 'shared\agent\system-prompt.txt'
    $sysPrompt = Get-Content $sysPromptPath -Raw

    # ── Tools block ───────────────────────────────────────────────────────────
    $toolsBlock    = '(none registered)'
    $toolsJsonPath = Join-Path $root 'shared\tools.json'
    if (Test-Path $toolsJsonPath) {
        $toolsData = Get-Content $toolsJsonPath -Raw | ConvertFrom-Json
        if ($null -ne $toolsData.tools -and @($toolsData.tools).Count -gt 0) {
            $tLines = foreach ($t in $toolsData.tools) {
                "- $($t.name): $($t.description)"
            }
            $toolsBlock = $tLines -join "`n"
        }
    }

    # ── Aliases block ─────────────────────────────────────────────────────────
    $aliasLines      = [System.Collections.Generic.List[string]]::new()
    $aliasesJsonPath = Join-Path $root 'shared\aliases.json'
    if (Test-Path $aliasesJsonPath) {
        $aliasData = (Get-Content $aliasesJsonPath -Raw | ConvertFrom-Json).aliases
        if ($null -ne $aliasData) {
            foreach ($prop in $aliasData.PSObject.Properties) {
                if ($prop.Name.StartsWith('_')) { continue }   # skip metadata keys
                $aName  = $prop.Name
                $aEntry = $prop.Value
                $note   = ''
                $winVal = $null
                $nixVal = $null
                if ($aEntry | Get-Member -Name '_note'   -ErrorAction SilentlyContinue) { $note   = $aEntry.'_note'   }
                if ($aEntry | Get-Member -Name 'windows' -ErrorAction SilentlyContinue) { $winVal = $aEntry.windows }
                if ($aEntry | Get-Member -Name 'unix'    -ErrorAction SilentlyContinue) { $nixVal = $aEntry.unix    }
                $line = "- ${aName}: $note"
                if ($null -ne $winVal) { $line += " [win: $winVal]" }
                if ($null -ne $nixVal) { $line += " [unix: $nixVal]" }
                $aliasLines.Add($line)
            }
        }
    }
    $aliasesBlock = if ($aliasLines.Count -gt 0) { ($aliasLines.ToArray() -join "`n") } else { '(none registered)' }

    # ── Fill template ─────────────────────────────────────────────────────────
    $sysPrompt = $sysPrompt.Replace('{{SHELL_TYPE}}',    'windows-powershell')
    $sysPrompt = $sysPrompt.Replace('{{TOOLS_BLOCK}}',   $toolsBlock)
    $sysPrompt = $sysPrompt.Replace('{{ALIASES_BLOCK}}', $aliasesBlock)

    # ── Append few-shot examples as plain text ────────────────────────────────
    # few-shot.json is a flat array of alternating user/assistant objects.
    # Render each pair as: "{user-content} => {assistant-content}".
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.Append($sysPrompt.TrimEnd())

    $fewShotPath = Join-Path $root 'shared\agent\few-shot.json'
    if (Test-Path $fewShotPath) {
        $fewShot = @(Get-Content $fewShotPath -Raw | ConvertFrom-Json)
        $exampleLines = [System.Collections.Generic.List[string]]::new()
        for ($i = 0; $i -lt $fewShot.Count - 1; $i += 2) {
            $u = $fewShot[$i]
            $a = $fewShot[$i + 1]
            if ($u.role -eq 'user' -and $a.role -eq 'assistant') {
                $exampleLines.Add("$($u.content) => $($a.content)")
            }
        }
        if ($exampleLines.Count -gt 0) {
            [void]$sb.Append("`n`nEXAMPLES:`n")
            [void]$sb.Append(($exampleLines.ToArray() -join "`n"))
        }
    }

    return $sb.ToString()
}

# ── Internal: output post-processor ──────────────────────────────────────────

function _Post-ProcessAgentOutput {
    <#
    .SYNOPSIS
        Clean raw llama-cli (conversation mode) stdout into a single command line.

        llama-cli single-turn conversation prints a banner, then the echoed user
        turn as a "> <query>" line, then the generated reply, then a stats line
        "[ Prompt: ... ]" / "[ Generation: ... ]" and "Exiting...". We locate the
        echoed query line (exact "> <query>", with a fallback to the last "> "
        line), then extract the text AFTER it and BEFORE the stats/Exiting
        markers, then:
          1. Strip ``` fenced-block markers.
          2. Take the FIRST non-empty line.
          3. Strip a leading "$ " or "> " prompt marker and surrounding backticks.
        Returns empty string when nothing useful remains.
    #>
    param([string]$Raw, [string]$Query)

    $lines = $Raw -split "`r?`n"

    # Find the conversation-echo line ("> <query>"); generation follows it.
    # Match the EXACT echoed query first so a generated command that itself
    # begins with "> " is never mistaken for the echo boundary. Fall back to
    # the last "^> " line only if the exact echo is not present.
    $echoLine = "> $Query"
    $startIdx = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i].TrimEnd() -eq $echoLine) { $startIdx = $i }
    }
    if ($startIdx -lt 0) {
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match '^> ') { $startIdx = $i }
        }
    }

    $gen = [System.Collections.Generic.List[string]]::new()
    if ($startIdx -ge 0) {
        for ($i = $startIdx + 1; $i -lt $lines.Count; $i++) {
            $l = $lines[$i]
            if ($l -match '^\[ (Prompt|Generation):' -or $l -match '^Exiting') { break }
            $gen.Add($l)
        }
    } else {
        # Fallback: no banner detected — treat all lines as candidate output.
        foreach ($l in $lines) { $gen.Add($l) }
    }

    # Strip ``` fenced-block markers but KEEP the inner content
    $filtered = [System.Collections.Generic.List[string]]::new()
    foreach ($line in $gen) {
        if ($line -match '^```') { continue }
        $filtered.Add($line)
    }

    foreach ($line in $filtered) {
        $t = $line.Trim()
        if ($t) {
            $t = $t -replace '^(\$ |> )', ''
            $t = $t.Trim('`').Trim()
            return $t
        }
    }
    return ''
}

# ── Internal: Invoke-AgentQuery ─────────────────────────────────────────────────

function Invoke-AgentQuery {
    <#
    .SYNOPSIS
        Run a natural-language query through the local llama-cli agent and
        print the resulting shell command.
    .DESCRIPTION
        1. Checks engine binary and model are present (exit-code semantics 2/3).
        2. Builds a grounded SYSTEM prompt (template + tools + aliases + few-shot).
        3. Writes the system prompt to a UTF-8 (no-BOM) temp file.
        4. Runs llama-cli in single-turn conversation mode (-sysf <file> -p <query>)
           as a one-shot subprocess with a configurable timeout.
        5. Post-processes stdout → single command line.
        6. Prints the command; copies to clipboard (best-effort).
        7. If -Run is given, prompts "Execute? [y/N]" before Invoke-Expression.

        Return object: [pscustomobject]@{ ExitCode = <int>; Command = <string> }
          0 = success
          1 = "# Cannot build:" or nothing generated
          2 = engine binary missing
          3 = model file missing
          4 = timeout

        llama-cli flags used (b9469 — conversation single-turn mode):
          -m <model>           model file path
          -sysf <file>         system prompt file (grounding + few-shot)
          -p <query>           the live user query (single conversation turn)
          -st                  single-turn: exit after one reply (non-interactive
                               because the first turn is predefined via -p)
          --simple-io          basic IO for subprocess compatibility
          --no-display-prompt  suppress prompt echo
          -n <int>             max new tokens
          --temp <float>       sampling temperature

        Model resolution priority:
          -Model param > $env:DOTFILES_AGENT_MODEL > PrimaryModel > FallbackModel

        Timeout resolution priority:
          -TimeoutSeconds param > $env:DOTFILES_AGENT_TIMEOUT > config timeout_seconds
    .PARAMETER Query
        Natural-language description of the command you want.
    .PARAMETER Run
        When set, prompt the user to confirm before executing the generated command.
    .PARAMETER Model
        Override the model file path. Defaults to auto-resolved primary/fallback.
    .PARAMETER TimeoutSeconds
        Override inference timeout in seconds. 0 = use config/env default.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Query,
        [switch]$Run,
        [string]$Model          = '',
        [int]   $TimeoutSeconds = 0
    )

    # ── 1. Readiness check ────────────────────────────────────────────────────
    $paths = Get-AgentPaths

    if (-not (Test-Path $paths.EngineBin)) {
        Write-Host "Agent engine not installed. Run: dotfiles agent --setup" -ForegroundColor Red
        return [pscustomobject]@{ ExitCode = 2; Command = '' }
    }

    # Resolve model path (priority: param > env > primary > fallback)
    $modelPath = ''
    if ($Model) {
        $modelPath = $Model
    } elseif ($env:DOTFILES_AGENT_MODEL) {
        $modelPath = $env:DOTFILES_AGENT_MODEL
    } elseif (Test-Path $paths.PrimaryModel) {
        $modelPath = $paths.PrimaryModel
    } elseif (Test-Path $paths.FallbackModel) {
        $modelPath = $paths.FallbackModel
    }

    if (-not $modelPath -or -not (Test-Path $modelPath)) {
        Write-Host "No model found. Run: dotfiles agent --setup" -ForegroundColor Red
        return [pscustomobject]@{ ExitCode = 3; Command = '' }
    }

    # Resolve config defaults
    $cfg      = $paths.Config
    $nPredict = [int]$cfg.defaults.n_predict
    $temp     = $cfg.defaults.temp   # may be 0 (int) or 0.0 (float) — both stringify fine

    # Resolve timeout (param > env > config)
    $timeoutSec = if ($TimeoutSeconds -gt 0) {
        $TimeoutSeconds
    } elseif ($env:DOTFILES_AGENT_TIMEOUT) {
        [int]$env:DOTFILES_AGENT_TIMEOUT
    } else {
        [int]$cfg.defaults.timeout_seconds
    }
    $timeoutMs = $timeoutSec * 1000

    # ── 2. Build grounded system prompt ──────────────────────────────────────
    $promptText = _Build-AgentPrompt -Paths $paths

    # ── 3. Write system prompt to temp file (UTF-8, no BOM) ───────────────────
    $tempDir    = if ($env:TEMP) { $env:TEMP } else { $env:TMP }
    $promptFile = Join-Path $tempDir ("dotfiles-agent-" + [System.Guid]::NewGuid().ToString('N') + ".txt")

    try {
        [System.IO.File]::WriteAllText(
            $promptFile,
            $promptText,
            [System.Text.UTF8Encoding]::new($false)   # $false = no BOM
        )

        # ── 4. Invoke llama-cli (conversation single-turn, with timeout) ──────
        #
        # b9469 is conversation-only; raw completion (-no-cnv) is rejected. We
        # run a single conversation turn: the system prompt (grounding+few-shot)
        # comes from -sysf, the live query from -p, and -st makes it exit after
        # one reply. Args are added individually (ArgumentList) so multi-word
        # values like the query are never re-split by the shell.
        $psi                        = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName               = $paths.EngineBin
        [void]$psi.ArgumentList.Add('-m');                  [void]$psi.ArgumentList.Add($modelPath)
        [void]$psi.ArgumentList.Add('-sysf');               [void]$psi.ArgumentList.Add($promptFile)
        [void]$psi.ArgumentList.Add('-p');                  [void]$psi.ArgumentList.Add($Query)
        [void]$psi.ArgumentList.Add('-st')
        [void]$psi.ArgumentList.Add('--simple-io')
        [void]$psi.ArgumentList.Add('--no-display-prompt')
        [void]$psi.ArgumentList.Add('-n');                  [void]$psi.ArgumentList.Add("$nPredict")
        [void]$psi.ArgumentList.Add('--temp');              [void]$psi.ArgumentList.Add("$temp")
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError  = $true
        $psi.UseShellExecute        = $false
        # CreateNoWindow MUST be $false: llama-cli conversation mode needs to
        # share a console or it exits 130 with no output.
        $psi.CreateNoWindow         = $false

        $proc = New-Object System.Diagnostics.Process
        $proc.StartInfo = $psi
        [void]$proc.Start()

        # Begin async reads BEFORE WaitForExit to prevent stdout-buffer deadlock
        $stdoutTask = $proc.StandardOutput.ReadToEndAsync()
        $stderrTask = $proc.StandardError.ReadToEndAsync()   # discarded; read to drain

        $exited = $proc.WaitForExit($timeoutMs)

        if (-not $exited) {
            try { $proc.Kill() } catch { <# best-effort #> }
            Write-Host "Request timed out after $timeoutSec s. Consider --setup --fallback for a smaller/faster model." -ForegroundColor Yellow
            return [pscustomobject]@{ ExitCode = 4; Command = '' }
        }

        $rawOutput = $stdoutTask.GetAwaiter().GetResult()

        # ── 5. Post-process output ────────────────────────────────────────────
        $command = _Post-ProcessAgentOutput -Raw $rawOutput -Query $Query

        if ([string]::IsNullOrWhiteSpace($command)) {
            Write-Host "No command generated. Try rephrasing your query." -ForegroundColor Yellow
            return [pscustomobject]@{ ExitCode = 1; Command = '' }
        }

        if ($command.StartsWith('# Cannot build:')) {
            Write-Host $command -ForegroundColor Yellow
            return [pscustomobject]@{ ExitCode = 1; Command = $command }
        }

        # ── 6. Show, copy, optionally run ─────────────────────────────────────
        Write-Host $command -ForegroundColor Cyan

        # Best-effort clipboard (never fatal)
        if (Get-Command Set-Clipboard -ErrorAction SilentlyContinue) {
            try { Set-Clipboard -Value $command } catch { <# non-fatal #> }
        }

        if ($Run) {
            $confirm = Read-Host 'Execute? [y/N]'
            if ($confirm -ceq 'y' -or $confirm -ceq 'Y') {
                Invoke-Expression $command
            }
        }

        return [pscustomobject]@{ ExitCode = 0; Command = $command }

    } finally {
        # Always clean up the temp prompt file
        if (Test-Path -LiteralPath $promptFile -ErrorAction SilentlyContinue) {
            Remove-Item -LiteralPath $promptFile -Force -ErrorAction SilentlyContinue
        }
    }
}

Export-ModuleMember -Function Install-AgentEngine, Get-AgentPaths, Test-AgentReady, Invoke-AgentQuery
