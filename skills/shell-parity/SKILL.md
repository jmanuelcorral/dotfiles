---
name: "shell-parity"
description: "POSIX-first bash/zsh configuration and Windows parity rules for the dotfiles repo"
domain: "shell"
confidence: "high"
source: "manual"
---

## Context

Tank owns `shell/` in this dotfiles repo. The Unix side must remain symmetric with the PowerShell side (Trinity) so that aliases, the `dotfiles` CLI, and tool availability feel identical regardless of whether the user is in PowerShell or bash/zsh.

**Key files:**
- `shell/common.sh` — POSIX-first shared config; sourced by both bash and zsh entry points
- `shell/bash/bashrc.sh` — bash-specific init (sourced by `~/.bashrc` stub)
- `shell/zsh/zshrc.sh` — zsh-specific init (sourced by `~/.zshrc` stub)
- `shared/aliases.json` — single source of truth for all cross-shell aliases
- `bootstrap/install.sh` — idempotent installer (writes stubs, installs packages, creates symlinks)

**Decision authority:** All patterns below are governed by Decision #4 (Shell Configuration) in `.squad/decisions.md`.

---

## Patterns

### 1. Load Contract — The Two-Line Stub

`~/.bashrc` and `~/.zshrc` contain **only** a two-line bootstrap stub, guarded by the `# dotfiles bootstrap` marker so the idempotency check in `bootstrap/install.sh` can detect it. The stub sets `DOTFILES` and sources the shell entry point:

```sh
# dotfiles bootstrap
export DOTFILES="$HOME/dotfiles"
source "$DOTFILES/shell/bash/bashrc.sh"   # or zshrc.sh for zsh
```

**Never** put configuration logic in `~/.bashrc` or `~/.zshrc` directly. Always edit the repo files.

The per-shell entry point (`bashrc.sh` / `zshrc.sh`) then sources `common.sh` as its first act:

```sh
. "${DOTFILES}/shell/common.sh"
```

`common.sh` itself has a `DOTFILES` self-resolve fallback using `BASH_SOURCE[0]:-$0` (line 10), so the file stays portable even if sourced manually.

---

### 2. POSIX-First Rule — common.sh

`common.sh` is shared between bash and zsh. **No bashisms permitted.** Rules:

| Banned (bashism) | Use instead |
|---|---|
| `[[ ]]` | `[ ]` |
| `echo -e` | `printf` |
| `${var,,}` / `${var^^}` | POSIX `tr` or `awk` |
| `local` inside sourced (non-function) context | Move to a function or use a `_prefix_` name |
| `$(< file)` | `$(cat file)` |

The file must pass `bash -n shell/common.sh` with no errors.

**Zsh guard for Starship/oh-my-zsh coexistence:** Shell-specific `eval` calls (zoxide init, starship init) live in the per-shell files, not `common.sh`. In `zshrc.sh` the Starship block guards against oh-my-zsh and Powerlevel10k:

```sh
if command -v starship >/dev/null 2>&1 && \
   [ -z "${ZSH:-}" ] && \
   [ -z "${POWERLEVEL9K_LEFT_PROMPT_ELEMENTS:-}" ]; then
    eval "$(starship init zsh)"
fi
```

Do not put `eval "$(starship init zsh)"` in `common.sh` — zsh-specific eval syntax would break bash.

---

### 3. Alias Guards + Fallbacks

Every modern-tool alias in `common.sh` is guarded with `command -v` and always falls back to the equivalent coreutils command. **An alias must never break a shell that lacks the modern tool.**

Structure (from `shell/common.sh` lines 36–53):

```sh
if command -v eza >/dev/null 2>&1; then
    alias ls='eza --icons --group-directories-first'
    alias ll='eza -la --icons --group-directories-first --git'
    alias la='eza -a --icons --group-directories-first'
    alias l='eza --icons --group-directories-first'
    alias lt='eza --tree --level=2 --icons --git'
else
    alias ls='ls --color=auto'
    alias ll='ls -la --color=auto'
    alias la='ls -A --color=auto'
    alias l='ls -CF --color=auto'
    if command -v tree >/dev/null 2>&1; then
        alias lt='tree -L 2'
    else
        lt() { find "${1:-.}" -maxdepth 2 | sed 's|[^/]*/|  |g'; }
    fi
fi
```

All modern-tool aliases follow this same pattern:
- `eza` → `ls --color=auto` family
- `rg` → `grep --color=auto`
- `bat` → no alias (coreutils `cat` is fine)
- `fd` → no alias when absent
- `duf` → `df -h`

---

### 4. shared/aliases.json — Single Source of Truth

`shared/aliases.json` is the canonical catalog for all cross-shell aliases. Schema (excerpt):

```json
{
  "aliases": {
    "ll": {
      "_note": "Long listing with hidden files",
      "windows": "eza -la --icons --group-directories-first | Get-ChildItem -Force",
      "unix":    "eza -la --icons --group-directories-first | ls -la"
    }
  }
}
```

**Parity rule:** Adding or renaming an alias on the Unix side requires a matching change in `shared/aliases.json` (`unix` field) **and** the PowerShell side (`windows` field in `aliases.json`, implementation in `powershell/aliases.ps1`). The `dotfiles explain <alias>` command reads this file — if an alias is absent here, explain cannot describe it.

---

### 5. apt Binary-Name Quirks — Two-Layer Handling

Ubuntu apt packages `bat` as `batcat` and `fd` as `fdfind` (namespace collision with other packages). Two layers of defence:

**Layer 1 — Installer symlinks** (`bootstrap/install.sh`): Creates `~/.local/bin/bat → batcat` and `~/.local/bin/fd → fdfind` so the canonical names work in all contexts (scripts, Makefiles, etc.).

**Layer 2 — Shell function wrappers** (`shell/common.sh` lines 25–30): Belt-and-suspenders fallback for sessions where the symlinks have not been created yet:

```sh
if ! command -v bat >/dev/null 2>&1 && command -v batcat >/dev/null 2>&1; then
    bat() { batcat "$@"; }
fi
if ! command -v fd >/dev/null 2>&1 && command -v fdfind >/dev/null 2>&1; then
    fd() { fdfind "$@"; }
fi
```

This two-layer approach also applies to `eza` (Ubuntu 23.10+ via apt; older LTS needs the gierens.de repo or cargo) and `zoxide` (Ubuntu 22.10+ via apt; fallback to official install script).

---

### 6. PATH Deduplication — case Idiom

`$DOTFILES/bin` is added to `PATH` using the POSIX `case` duplicate-guard idiom (from `shell/common.sh` lines 16–19):

```sh
case ":${PATH}:" in
    *":${DOTFILES}/bin:"*) ;;
    *) export PATH="${DOTFILES}/bin:${PATH}" ;;
esac
```

This pattern is O(1), works in all POSIX shells, and avoids the repeated-source bloat that plagues dotfile setups that use `export PATH="$NEW:$PATH"` unconditionally.

---

### 7. The dotfiles() Function — Subcommand Parity

`common.sh` defines the `dotfiles` shell function providing the same subcommands as the PowerShell `dotfiles` command:

| Subcommand | Behaviour |
|---|---|
| `dotfiles help [query]` | fzf interactive if no query; rg/grep keyword filter otherwise |
| `dotfiles list` | Reads `shared/tools.json` via jq; column-formatted |
| `dotfiles version` | Reads `VERSION` file + `git rev-parse --short HEAD` |
| `dotfiles update` | `git pull`, re-runs installer, reloads shell |
| `dotfiles edit` | Opens `$DOTFILES` in `$EDITOR` |
| `dotfiles explain <name>` | Looks up `aliases.json` → `tools.json` → `--help` |
| `dotfiles agent --setup` | Sources `shell/lib/agent.sh`; downloads llama-cli + model |
| `dotfiles agent "<query>"` | Sources `shell/lib/agent.sh`; runs inference |

All subcommands that read JSON use `jq` with a grep/sed fallback for environments where jq is absent.

---

### 8. Shell-Specific Code Stays in Per-Shell Files

Code requiring shell-specific syntax lives in `bashrc.sh` or `zshrc.sh`, never in `common.sh`:

| Feature | bash (`bashrc.sh`) | zsh (`zshrc.sh`) |
|---|---|---|
| History | `HISTCONTROL`, `shopt -s histappend`, `PROMPT_COMMAND` | `setopt HIST_IGNORE_ALL_DUPS`, `SHARE_HISTORY` |
| Shell options | `shopt -s globstar cdspell autocd` | `setopt AUTO_CD AUTO_PUSHD GLOB_DOTS EXTENDED_GLOB` |
| Completion | `/usr/share/bash-completion/bash_completion` | `autoload -Uz compinit` (guarded for oh-my-zsh) |
| zoxide init | `eval "$(zoxide init bash)"` | `eval "$(zoxide init zsh)"` |
| Starship init | `eval "$(starship init bash)"` | `eval "$(starship init zsh)"` + oh-my-zsh guard |
| Key bindings | (bash-completion handles) | `bindkey -e`, custom arrow-key history search |

---

## Examples

### Correct — guarded alias block (common.sh)

```sh
# grep → ripgrep
if command -v rg >/dev/null 2>&1; then
    alias grep='rg'
else
    alias grep='grep --color=auto'
fi

# cat → bat
if command -v bat >/dev/null 2>&1; then
    alias cat='bat --style=plain'
else
    : # cat is a builtin — no alias needed
fi
```

### Correct — batcat/fdfind wrappers (common.sh)

```sh
if ! command -v bat >/dev/null 2>&1 && command -v batcat >/dev/null 2>&1; then
    bat() { batcat "$@"; }
fi
if ! command -v fd >/dev/null 2>&1 && command -v fdfind >/dev/null 2>&1; then
    fd() { fdfind "$@"; }
fi
```

### Correct — PATH dedup case idiom (common.sh)

```sh
case ":${PATH}:" in
    *":${DOTFILES}/bin:"*) ;;
    *) export PATH="${DOTFILES}/bin:${PATH}" ;;
esac
```

### Correct — Starship init in zshrc.sh with oh-my-zsh guard

```sh
if command -v starship >/dev/null 2>&1 && \
   [ -z "${ZSH:-}" ] && \
   [ -z "${POWERLEVEL9K_LEFT_PROMPT_ELEMENTS:-}" ]; then
    eval "$(starship init zsh)"
fi
```

### Correct — two-line stub in ~/.bashrc

```sh
# dotfiles bootstrap
export DOTFILES="$HOME/dotfiles"
source "$DOTFILES/shell/bash/bashrc.sh"
```

---

## Anti-Patterns

### ❌ Bashism in common.sh

```sh
# WRONG — [[ ]] is bash-only
if [[ -n "$DOTFILES" ]]; then
    export PATH="${DOTFILES}/bin:${PATH}"
fi
```

```sh
# CORRECT — POSIX [ ]
if [ -n "${DOTFILES:-}" ]; then
    case ":${PATH}:" in
        *":${DOTFILES}/bin:"*) ;;
        *) export PATH="${DOTFILES}/bin:${PATH}" ;;
    esac
fi
```

### ❌ Editing ~/.bashrc directly instead of repo files

Editing `~/.bashrc` directly bypasses the repo. Changes will be lost on the next `dotfiles update` or fresh machine bootstrap. Always edit `shell/common.sh`, `shell/bash/bashrc.sh`, or `shell/zsh/zshrc.sh`.

### ❌ Unguarded alias that breaks a fresh shell

```sh
# WRONG — fails with "alias: not found" if eza is not installed
alias ls='eza --icons --group-directories-first'
```

```sh
# CORRECT — always falls back
if command -v eza >/dev/null 2>&1; then
    alias ls='eza --icons --group-directories-first'
else
    alias ls='ls --color=auto'
fi
```

### ❌ Adding a unix alias without mirroring in shared/aliases.json and PowerShell

```sh
# WRONG — added to common.sh only
alias jl='jupyter lab'
```

Every alias that makes sense cross-platform must be added to `shared/aliases.json` with both `unix` and `windows` fields, and implemented in `powershell/aliases.ps1`. Aliases that are genuinely Unix-only (e.g., `xdg-open` wrappers) may omit the `windows` field but must still appear in `aliases.json` with a `_note` explaining the scope.

### ❌ Assuming Ubuntu-only (no distro detection)

```sh
# WRONG — apt hard-coded, breaks on Arch, macOS, Alpine
apt-get install -y bat
```

```sh
# CORRECT — detect package manager
if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get install -y bat
elif command -v brew >/dev/null 2>&1; then
    brew install bat
elif command -v pacman >/dev/null 2>&1; then
    sudo pacman -S --noconfirm bat
fi
```

`bootstrap/install.sh` already has a `_pm` (package manager) detection block. Use it rather than hardcoding `apt`.

### ❌ Putting eval shell-init calls in common.sh

```sh
# WRONG — zsh-specific syntax in common.sh breaks bash
eval "$(zoxide init zsh)"
```

Shell-specific `eval` inits belong in `bashrc.sh` or `zshrc.sh` respectively. `common.sh` only guards for the presence of the binary (no-op comment) and delegates the per-shell init call to the appropriate shell file.

### ❌ Duplicating PATH unconditionally

```sh
# WRONG — bloats PATH on repeated source
export PATH="${DOTFILES}/bin:${PATH}"
```

Always use the `case ":${PATH}:"` duplicate-guard. Repeated sourcing (e.g., `dotfiles update` calls `reload`) would otherwise append the same entry multiple times.
