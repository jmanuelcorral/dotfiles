---
name: "packages-and-tooling"
description: "How to declare packages and register tools across winget/scoop/apt in the dotfiles repo"
domain: "tooling"
confidence: "high"
source: "manual"
---

## Context

Package management in this repo is **declarative and idempotent**. All CLI tools are declared in JSON manifests under `packages/`; `bootstrap/install.ps1` (Windows) and `bootstrap/install.sh` (WSL/Linux) consume those manifests and guard every install via a binary presence check. No package is ever installed by editing an installer script directly.

**Package manifest files:**

| File | Platform | Owner |
|---|---|---|
| `packages/winget.json` | Windows (winget primary, scoop fallback) | Switch |
| `packages/scoop.json` | Windows (scoop standalone) | Switch |
| `packages/apt.json` | Debian/Ubuntu (WSL) | Tank |

**Tool registry:**

`shared/tools.json` is the registry of personal scripts in `bin/`. It powers `dotfiles help` and `dotfiles list`. Managed exclusively via `dotfiles register <name>` — never edited by hand.

**Cross-shell aliases:**

`shared/aliases.json` is the single source of truth for all shell aliases. Trinity generates `powershell/aliases.ps1` from it; Tank generates `shell/common.sh` entries. The JSON schema per entry: `{ "windows": "...", "unix": "...", "_note": "..." }`.

---

## Patterns

### 1. `packages/winget.json` — Schema

```json
{
  "_comment": "...",
  "_owner": "Switch",
  "packages": [
    {
      "id":          "<winget package ID>",
      "command":     "<binary name on PATH — used as idempotency guard>",
      "scoop":       "<scoop package name — fallback, or null>",
      "description": "<human-readable description>"
    }
  ]
}
```

- `id` — the winget package ID (e.g. `sharkdp.bat`)
- `command` — the binary name checked via `Get-Command` before attempting any install; if found, the entry is skipped entirely
- `scoop` — fallback package name used when winget is unavailable or returns a non-success exit code; set to `null` for packages with no scoop equivalent (e.g. `Volta.Volta`)
- `description` — plain English; makes the file self-documenting

### 2. How `bootstrap/install.ps1` consumes `winget.json`

```powershell
foreach ($pkg in $pkgData.packages) {
    # Guard: already on PATH — skip entirely
    if (Get-Command $pkg.command -ErrorAction SilentlyContinue) {
        Write-Skip "already present : $($pkg.command)"
        continue
    }

    # Try winget first
    if ($hasWinget -and $pkg.id) {
        winget install --id $pkg.id --silent `
            --accept-package-agreements --accept-source-agreements
        # Exit -1978335189 (0x8A150011) = "already installed" — treat as success
        if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq -1978335189) { $installed = $true }
    }

    # Fallback: scoop
    if (-not $installed -and $hasScoop -and $pkg.scoop) {
        scoop install $pkg.scoop
    }
}
```

The `command` field is the **sole idempotency gate**. If the binary is already resolvable on PATH, winget and scoop are never called.

### 3. `packages/apt.json` — Schema (WSL/Linux)

Three sub-arrays handle the different install mechanisms on Debian/Ubuntu:

- `apt[]` — standard `apt install` entries with `name` and `binary` fields
- `script_installs[]` — tools installed via official curl scripts (e.g. starship, zoxide fallback); each entry has `install_cmd`
- `github_releases[]` — tools fetched from GitHub Releases (e.g. delta, yq); each entry has `repo` and `asset_pattern`

**Binary quirks** are documented in `_binary_quirks` (e.g. `bat` installs as `batcat` on Ubuntu <22.04; `fd-find` installs as `fdfind`). `bootstrap/install.sh` creates `~/.local/bin/` symlinks automatically.

### 4. PowerShell Modules

Declared inline in `bootstrap/install.ps1` (not in a JSON file). Guard is version-based:

```powershell
$psModules = @(
    @{ Name = 'PSReadLine';     MinVer = '2.3.0' },
    @{ Name = 'Terminal-Icons'; MinVer = '0.0.1' },
    @{ Name = 'posh-git';       MinVer = '1.0.0' },
    @{ Name = 'PSFzf';          MinVer = '2.0.0' }
)

foreach ($mod in $psModules) {
    $found = Get-Module -ListAvailable -Name $mod.Name |
             Where-Object { $_.Version -ge [version]$mod.MinVer }
    if ($found) { continue }
    Install-Module -Name $mod.Name -Scope CurrentUser -Force -AllowClobber -Repository PSGallery
}
```

Modules are installed to `CurrentUser` scope — no admin required.

### 5. `shared/tools.json` + `dotfiles register`

`shared/tools.json` holds the registry of personal scripts placed in `bin/`:

```json
{
  "_comment": "Registry of user tools in bin/. Powers 'dotfiles help' and 'dotfiles list'.",
  "_owner": "Switch",
  "tools": []
}
```

**To register a new script:**

```powershell
dotfiles register my-script -Description "Does something useful"
```

This command performs an **upsert** — if `my-script` already exists in `tools.json` it is updated, not duplicated. Paths are stored with forward slashes for cross-platform readability, even on Windows.

### 6. Adding a Package — The Only Correct Workflow

**Windows tool:**
1. Add an entry to `packages/winget.json` with `id`, `command`, `scoop`, `description`
2. Run `bootstrap/install.ps1` (or it runs on next fresh machine bootstrap)

**WSL/Linux tool:**
1. Add an entry to `packages/apt.json` under the appropriate sub-array (`apt`, `script_installs`, or `github_releases`)
2. Run `bootstrap/install.sh`

That is the entire workflow. The JSON is the source of truth.

---

## Examples

### Example 1 — A `winget.json` entry

```json
{ "id": "dandavison.delta", "command": "delta", "scoop": "delta", "description": "Better git diffs" }
```

### Example 2 — The guard-then-install loop from `install.ps1`

```powershell
# Skip if binary already exists on PATH
if (Get-Command $pkg.command -ErrorAction SilentlyContinue) {
    Write-Skip "already present : $($pkg.command)"
    continue
}

# Primary installer
winget install --id $pkg.id --silent --accept-package-agreements --accept-source-agreements
if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq -1978335189) {
    $installed = $true
} else {
    # Fallback
    scoop install $pkg.scoop
}
```

### Example 3 — An `apt.json` entry for a GitHub Releases tool

```json
{
  "name": "delta",
  "binary": "delta",
  "repo": "dandavison/delta",
  "description": "Syntax-highlighting git diff pager",
  "asset_pattern": "delta-*-x86_64-unknown-linux-musl.tar.gz"
}
```

### Example 4 — Registering a personal script

```powershell
# Creates/updates bin/my-script.ps1 entry in shared/tools.json
dotfiles register my-script -Description "Short description shown in dotfiles help"
```

### Example 5 — The current modern CLI stack (from `winget.json`)

| Binary | winget ID | Description |
|---|---|---|
| `git` | `Git.Git` | Version control |
| `gh` | `GitHub.cli` | GitHub CLI |
| `oh-my-posh` | `JanDeDobbeleer.OhMyPosh` | Prompt theme engine |
| `bat` | `sharkdp.bat` | `cat` with syntax highlighting |
| `eza` | `eza-community.eza` | Modern `ls` replacement |
| `fd` | `sharkdp.fd` | Fast `find` replacement |
| `rg` | `BurntSushi.ripgrep.MSVC` | Fast `grep` replacement |
| `fzf` | `junegunn.fzf` | Fuzzy finder |
| `zoxide` | `ajeetdsouza.zoxide` | Frecency-based `cd` (Decision #2) |
| `delta` | `dandavison.delta` | Git diff pager |
| `jq` | `jqlang.jq` | JSON processor |
| `volta` | `Volta.Volta` | Node.js version manager |
| `gsudo` | `gerardog.gsudo` | Sudo for Windows |

---

## Anti-Patterns

### ❌ Editing the installer instead of the JSON

```powershell
# WRONG — do not add install logic directly in bootstrap/install.ps1
winget install --id SomeVendor.SomeTool --silent
```

The JSON manifests are the source of truth. The installer is a consumer. Hardcoding installs bypasses the idempotency guard, breaks the declarative model, and makes the tool invisible to agents and documentation tooling.

### ❌ Omitting the `command` field

```json
{ "id": "SomeVendor.SomeTool", "description": "Some tool" }
```

The `command` field is the idempotency guard. Without it, `Get-Command` cannot check whether the tool is already installed, and the installer will attempt a winget/scoop call on every run.

### ❌ Setting `scoop` to a name that doesn't exist in the scoop bucket

The `scoop` field is used as-is in `scoop install <name>`. Verify the name in the target bucket (`main` or `extras`) before adding it. Use `null` when no scoop package exists (as done for `Volta.Volta`).

### ❌ Registering a personal script by hand-editing `tools.json`

```json
// WRONG — do not edit tools.json directly
{ "name": "my-script", "path": "bin/my-script.ps1" }
```

Always use `dotfiles register my-script`. Direct edits risk malformed JSON, wrong path separators, and duplicates — `dotfiles register` handles upsert and path normalization automatically.

### ❌ Duplicating a `tools.json` entry instead of upserting

If a script is already registered, running `dotfiles register` again will update it. Never add a second entry for the same name; the `dotfiles help` command will surface duplicates as noise.

### ❌ Recommending a tool that can't install cleanly on both Windows and WSL

Per Decision #2, all recommended tools must have a viable install path on both platforms. Before adding a tool to `winget.json` or `apt.json`, verify:
- Windows: winget ID exists **and** scoop fallback exists (or `null` is acceptable)
- WSL: available via apt, official script, or GitHub Releases with a static binary
- No platform-specific runtime dependencies (no .NET Framework, no MSVC CRT for the Linux build, etc.)
