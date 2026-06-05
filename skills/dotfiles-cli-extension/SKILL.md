---
name: "dotfiles-cli-extension"
description: "How to add a `dotfiles` CLI subcommand with Windows/Unix parity"
domain: "cli"
confidence: "high"
source: "manual"
---

## Context

The `dotfiles` CLI is implemented **twice** for cross-platform parity:

| File | Shell | Dispatch |
|------|-------|----------|
| `bin/dotfiles.ps1` | PowerShell 7+ | `switch ($Command.ToLower()) { ... }` |
| `shell/common.sh` | POSIX bash/zsh | `case "$cmd" in ... esac` inside `dotfiles()` |

Both files must be updated together whenever a new subcommand is added. This is Decision #3 in `.squad/decisions.md` — the parity rule is a hard requirement.

**Repo root resolution:**
- PowerShell: `$DotfilesRoot = if ($env:DOTFILES) { $env:DOTFILES } else { Split-Path $PSScriptRoot -Parent }`
- Bash: `${DOTFILES}` — set by the shell stub in `~/.bashrc`/`~/.zshrc` before sourcing `common.sh`

## Patterns

### 1. Adding a Subcommand to `bin/dotfiles.ps1`

**Step 1 — Write a function:**
```powershell
function Invoke-MyCmd {
    param([string]$Action, [string]$Target)
    # ... implementation using $DotfilesRoot
    switch ($Action.ToLower()) {
        'sub1' { ... }
        'sub2' { ... }
        default {
            Write-Host "Usage:" -ForegroundColor Yellow
            Write-Host "  dotfiles mycmd sub1   Do thing one" -ForegroundColor White
            Write-Host "  dotfiles mycmd sub2   Do thing two" -ForegroundColor White
        }
    }
}
```

**Step 2 — Wire into the switch:**
```powershell
switch ($Command.ToLower()) {
    # ... existing cases ...
    'mycmd'  { Invoke-MyCmd  -Action $Arg1 -Target $Arg2 }
    default {
        Write-Host "Usage: dotfiles <help|list|...|mycmd>" -ForegroundColor Yellow
        exit 1
    }
}
```

**Step 3 — Update the comment-based help** (`.DESCRIPTION` section and `.EXAMPLE`):
```powershell
<#
.DESCRIPTION
    Subcommands:
        ...
        mycmd sub1             Do thing one.
        mycmd sub2             Do thing two.
.EXAMPLE
    dotfiles mycmd sub1
    dotfiles mycmd sub2 ./myproject
#>
```

**Available variables inside functions:**
- `$DotfilesRoot` — absolute path to repo root
- `$ToolsJson`, `$AliasesJson`, `$Cheatsheet`, `$VersionFile`, `$Changelog` — pre-resolved paths
- `$Arg1`, `$Arg2` — positional arguments from the user
- `$Description` — named `-Description` param

### 2. Adding a Subcommand to `shell/common.sh`

**Step 1 — Add a `case` arm inside the `dotfiles()` function:**
```sh
dotfiles() {
    local cmd="${1:-help}"
    shift 2>/dev/null || true
    case "$cmd" in
        # ... existing cases ...
        mycmd)
            local action="${1:-}"
            local target="${2:-}"
            local myroot="${DOTFILES}/mydir"
            case "$action" in
                sub1) echo "doing sub1" ;;
                sub2) echo "doing sub2 in ${target:-$(pwd)}" ;;
                *)
                    echo "Usage:"
                    echo "  dotfiles mycmd sub1   Do thing one"
                    echo "  dotfiles mycmd sub2 [target]"
                    ;;
            esac
            ;;
        *)
            echo "Usage: dotfiles <help|list|...|mycmd> [args]" >&2
            return 1
            ;;
    esac
}
```

**POSIX rules (common.sh is POSIX-first):**
- Use `[ ]` not `[[ ]]`
- Use `command -v` not `which`
- Use `printf` over `echo -e`
- Use `local` for all variables inside functions
- Use `cp -R` / `mkdir -p` not PowerShell equivalents
- File must pass `bash -n shell/common.sh`

### 3. The `skills` Subcommand — Worked Example

The `skills` subcommand was added to both files following this exact pattern.

**PowerShell (`bin/dotfiles.ps1`):**
```powershell
function Invoke-Skills {
    param([string]$Action, [string]$Target)
    $SkillsRoot = Join-Path $DotfilesRoot 'skills'

    if (-not (Test-Path $SkillsRoot)) {
        Write-Host "  ⚠ skills/ directory not found at: $SkillsRoot" -ForegroundColor Yellow
        return
    }

    switch ($Action.ToLower()) {
        'list' {
            foreach ($dir in (Get-ChildItem $SkillsRoot -Directory)) {
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
        }
        'path' { Write-Host $SkillsRoot }
        'install' {
            $dest = Join-Path ($Target ? $Target : $PWD.Path) '.copilot\skills'
            New-Item -ItemType Directory -Path $dest -Force | Out-Null
            foreach ($dir in (Get-ChildItem $SkillsRoot -Directory)) {
                Copy-Item -Path $dir.FullName -Destination (Join-Path $dest $dir.Name) -Recurse -Force
                Write-Host "  ✓ $($dir.Name)" -ForegroundColor Green
            }
        }
        default { <# print usage #> }
    }
}
# Wired as: 'skills' { Invoke-Skills -Action $Arg1 -Target $Arg2 }
```

**Bash (`shell/common.sh`):**
```sh
skills)
    local skills_action="${1:-}"
    local skills_target="${2:-}"
    local skills_root="${DOTFILES}/skills"
    [ -d "$skills_root" ] || { echo "dotfiles: skills/ not found" >&2; return 1; }
    case "$skills_action" in
        list)
            for skill_dir in "$skills_root"/*/; do
                [ -d "$skill_dir" ] || continue
                skill_name="$(basename "$skill_dir")"
                desc=""
                if [ -f "${skill_dir}SKILL.md" ]; then
                    desc="$(grep -m1 '^description:' "${skill_dir}SKILL.md" \
                        | sed 's/^description:[[:space:]]*//;s/^"//;s/"$//')"
                fi
                printf '  %-30s %s\n' "$skill_name" "$desc"
            done ;;
        path)  echo "$skills_root" ;;
        install)
            local dest="${skills_target:-$(pwd)}/.copilot/skills"
            mkdir -p "$dest"
            for skill_dir in "$skills_root"/*/; do
                [ -d "$skill_dir" ] || continue
                skill_name="$(basename "$skill_dir")"
                cp -R "$skill_dir" "${dest}/${skill_name}"
                echo "  ✓ $skill_name"
            done ;;
        *) echo "Usage: dotfiles skills list|path|install [target]" ;;
    esac
    ;;
```

### 4. Reading Shared Data Files

Subcommands can read shared data from `$DotfilesRoot/shared/`:

**PowerShell:**
```powershell
$tools = (Get-Content (Join-Path $DotfilesRoot 'shared\tools.json') -Raw | ConvertFrom-Json).tools
```

**Bash (with jq):**
```sh
jq -r '.tools[] | .name' "${DOTFILES}/shared/tools.json"
```

### 5. fzf-Interactive-Else-Plain Pattern

When a subcommand could benefit from interactive selection, check for fzf first:

**PowerShell:**
```powershell
$hasFzf = [bool](Get-Command fzf -ErrorAction SilentlyContinue)
if ($hasFzf) {
    $lines | fzf --prompt='Select> '
} else {
    $lines | ForEach-Object { Write-Host $_ }
}
```

**Bash:**
```sh
if command -v fzf >/dev/null 2>&1; then
    selected="$(printf '%s\n' "$@" | fzf --prompt='Select> ')"
else
    printf '%s\n' "$@"
fi
```

## Anti-Patterns

- **Adding a subcommand to only one shell** — PowerShell and bash implementations must always be in sync. A user sourcing `common.sh` on Linux expects the same subcommands as `dotfiles.ps1` on Windows.
- **Hardcoding the repo root** — always use `$DotfilesRoot` (PowerShell) or `$DOTFILES` (bash). Never write `C:\Users\jose\dotfiles` or `~/dotfiles`.
- **Breaking the param/positional contract** — PowerShell uses `param($Command, $Arg1, $Arg2, $Description)`; bash uses `shift` after reading `$cmd`. New subcommands consume `$Arg1`/`$Arg2` (PS) or `$1`/`$2` (bash) as their sub-arguments. Do not add new top-level params without updating both files.
- **Using bashisms in `common.sh`** — `[[ ]]`, `$'\n'`, `local x=()` (array) are bash-only. Use `[ ]`, `printf`, and POSIX-compatible constructs; verify with `bash -n shell/common.sh`.
- **Forgetting to update the `default`/`*)` usage line** — when adding a new subcommand, always update the catch-all usage string in both files so users see the complete list.
