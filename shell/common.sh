# shell/common.sh — Shared POSIX-compatible config for bash and zsh
# Owner: Tank
# Sourced by: shell/bash/bashrc.sh and shell/zsh/zshrc.sh
# Do NOT put bash-only or zsh-only syntax here.

# ── Resolve DOTFILES root ─────────────────────────────────────────────────────
# DOTFILES must be set by the thin stub in ~/.bashrc / ~/.zshrc before sourcing.
# As a fallback, derive from this file's own location (two levels up).
if [ -z "${DOTFILES:-}" ]; then
    _this_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
    export DOTFILES="$(cd "$_this_dir/.." && pwd)"
    unset _this_dir
fi

# ── PATH: add $DOTFILES/bin (guard duplicates) ────────────────────────────────
case ":${PATH}:" in
    *":${DOTFILES}/bin:"*) ;;
    *) export PATH="${DOTFILES}/bin:${PATH}" ;;
esac

# ── Binary-name quirks (batcat → bat, fdfind → fd) ───────────────────────────
# Ubuntu apt installs bat as 'batcat' and fd as 'fdfind' on older releases.
# Prefer ~/.local/bin symlinks (created by bootstrap/install.sh), but also
# set shell functions here so the session works even without the symlinks.
if ! command -v bat >/dev/null 2>&1 && command -v batcat >/dev/null 2>&1; then
    bat() { batcat "$@"; }
fi
if ! command -v fd >/dev/null 2>&1 && command -v fdfind >/dev/null 2>&1; then
    fd() { fdfind "$@"; }
fi

# ── Aliases — generated from shared/aliases.json (unix field) ────────────────
# Each modern-tool alias is guarded with command -v and falls back to coreutils.

# ls / directory listing
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
    # lt: tree falls back to find-based approximation
    if command -v tree >/dev/null 2>&1; then
        alias lt='tree -L 2'
    else
        lt() { find "${1:-.}" -maxdepth 2 | sed 's|[^/]*/|  |g'; }
    fi
fi

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
    : # cat is a builtin / system binary — no alias needed
fi

# find → fd
if command -v fd >/dev/null 2>&1; then
    alias find='fd'
fi

# df / du with modern replacements when available
if command -v duf >/dev/null 2>&1; then
    alias df='duf'
else
    alias df='df -h'
fi
alias du='du -sh'

# Disk / process aliases (plain, no modern-tool substitution needed)
alias ps='ps aux'

# Navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# Git short-hands
alias g='git'
alias ga='git add'
alias gc='git commit'
alias gst='git status'
alias gp='git push'
alias gl='git log --oneline --graph --decorate'
alias gd='git diff'

# Misc quality-of-life
alias mkdir='mkdir -p'
alias which='command -v'

# cd to dotfiles root
alias cdot='cd "${DOTFILES}"'

# Reload the current shell profile
# (bash/zsh each implement the specific source path in their own file,
#  but we provide a sane default here)
reload() {
    if [ -n "${ZSH_VERSION:-}" ]; then
        exec zsh
    else
        exec bash
    fi
}

# ── Functions ─────────────────────────────────────────────────────────────────

# mkcd — make directory and cd into it
mkcd() {
    [ -z "$1" ] && { echo "Usage: mkcd <dir>"; return 1; }
    mkdir -p "$1" && cd "$1" || return 1
}

# up N — go up N directory levels
up() {
    local count="${1:-1}"
    local path=''
    local i=0
    while [ "$i" -lt "$count" ]; do
        path="${path}../"
        i=$((i + 1))
    done
    cd "${path%/}" || return 1
}

# ── zoxide (smart cd) ─────────────────────────────────────────────────────────
# Per-shell init is done in bashrc.sh / zshrc.sh because the eval output
# uses shell-specific syntax. We only skip here if zoxide is missing.
# (No-op in common.sh; the shell files call: eval "$(zoxide init <shell>)")

# ── fzf keybindings and completion ───────────────────────────────────────────
# fzf installs its shell integration under /usr/share/doc/fzf/examples/ (apt)
# or ~/.fzf/  (manual). Load whichever is present.
_fzf_load() {
    local share_dir="/usr/share/doc/fzf/examples"
    local home_dir="${HOME}/.fzf"
    local shell_name

    if [ -n "${ZSH_VERSION:-}" ]; then
        shell_name="zsh"
    else
        shell_name="bash"
    fi

    if [ -f "${home_dir}/key-bindings.${shell_name}" ]; then
        # shellcheck source=/dev/null
        . "${home_dir}/key-bindings.${shell_name}"
    elif [ -f "${share_dir}/key-bindings.${shell_name}" ]; then
        # shellcheck source=/dev/null
        . "${share_dir}/key-bindings.${shell_name}"
    fi

    if [ -f "${home_dir}/completion.${shell_name}" ]; then
        # shellcheck source=/dev/null
        . "${home_dir}/completion.${shell_name}"
    elif [ -f "${share_dir}/completion.${shell_name}" ]; then
        # shellcheck source=/dev/null
        . "${share_dir}/completion.${shell_name}"
    fi
}
command -v fzf >/dev/null 2>&1 && _fzf_load
unset -f _fzf_load 2>/dev/null || true

# ── MANPAGER: use bat for man pages when bat is available ─────────────────────
if command -v bat >/dev/null 2>&1; then
    export MANPAGER="sh -c 'col -bx | bat -l man -p'"
fi

# ── git-delta: configure if present ──────────────────────────────────────────
# delta is configured in ~/.gitconfig; nothing extra needed here.

# ── dotfiles CLI helper ───────────────────────────────────────────────────────
# Provides: dotfiles help [query] | dotfiles list | dotfiles update | dotfiles edit
#           dotfiles explain <alias-or-tool> | dotfiles agent --setup [--fallback]
# Reads shared/tools.json, shared/aliases.json, and docs/cheatsheet.md.
# Uses fzf for interactive search when available, plain grep otherwise.
dotfiles() {
    local cmd="${1:-help}"
    shift 2>/dev/null || true

    case "$cmd" in
        help)
            local cheatsheet="${DOTFILES}/docs/cheatsheet.md"
            if [ ! -f "$cheatsheet" ]; then
                echo "dotfiles: cheatsheet not found at $cheatsheet" >&2
                return 1
            fi
            if [ -n "${1:-}" ]; then
                # Filter by keyword (rg preferred, else grep)
                if command -v rg >/dev/null 2>&1; then
                    rg --color=never -i "$1" "$cheatsheet"
                else
                    grep -i "$1" "$cheatsheet"
                fi
            elif command -v fzf >/dev/null 2>&1; then
                # Interactive fuzzy search
                fzf --preview 'echo {}' \
                    --preview-window=up:3:wrap \
                    --bind 'ctrl-/:toggle-preview' \
                    --prompt='dotfiles> ' \
                    < "$cheatsheet"
            else
                if command -v bat >/dev/null 2>&1; then
                    bat "$cheatsheet"
                else
                    cat "$cheatsheet"
                fi
            fi
            ;;
        list)
            local tools_json="${DOTFILES}/shared/tools.json"
            if [ ! -f "$tools_json" ]; then
                echo "dotfiles: tools.json not found at $tools_json" >&2
                return 1
            fi
            if command -v jq >/dev/null 2>&1; then
                jq -r '.tools[] | "\(.name)\t\(.description // "")"' "$tools_json" \
                    | column -t -s $'\t' 2>/dev/null || \
                  jq -r '.tools[] | "\(.name)  \(.description // "")"' "$tools_json"
            else
                grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"' "$tools_json" \
                    | sed 's/"name"[[:space:]]*:[[:space:]]*//;s/"//g'
            fi
            ;;
        update)
            echo "Updating dotfiles..."
            ( cd "${DOTFILES}" && git pull --rebase ) || return 1
            echo "Reloading shell..."
            reload
            ;;
        edit)
            local editor="${EDITOR:-${VISUAL:-vi}}"
            "$editor" "${DOTFILES}"
            ;;
        register)
            echo "dotfiles register: use the PowerShell CLI on Windows or edit shared/tools.json directly." >&2
            return 1
            ;;
        explain)
            # Offline explain: aliases.json → tools.json → <cmd> --help
            local name="${1:-}"
            if [ -z "$name" ]; then
                echo "Usage: dotfiles explain <alias-or-tool>" >&2
                return 1
            fi
            local aliases_json="${DOTFILES}/shared/aliases.json"
            local tools_json="${DOTFILES}/shared/tools.json"
            local found=0

            # 1. Check aliases.json (requires jq; grep/sed fallback)
            if [ -f "$aliases_json" ]; then
                if command -v jq >/dev/null 2>&1; then
                    local note win_form unix_form
                    note=$(jq -r --arg k "$name" '.aliases[$k]._note // ""' "$aliases_json" 2>/dev/null)
                    win_form=$(jq -r --arg k "$name" '.aliases[$k].windows // "(not defined)"' "$aliases_json" 2>/dev/null)
                    unix_form=$(jq -r --arg k "$name" '.aliases[$k].unix // "(not defined)"' "$aliases_json" 2>/dev/null)
                    if [ -n "$note" ] && [ "$note" != "null" ]; then
                        echo ""
                        echo "  $name — $note"
                        echo ""
                        echo "  Windows (PowerShell):"
                        echo "    $win_form"
                        echo ""
                        echo "  Unix (bash/zsh):"
                        echo "    $unix_form"
                        echo ""
                        found=1
                    fi
                else
                    # grep/sed fallback: look for the key block heuristically
                    if grep -q "\"$name\"" "$aliases_json" 2>/dev/null; then
                        echo ""
                        echo "  $name — (install jq for full alias details)"
                        grep -A4 "\"$name\"" "$aliases_json" | grep -v "^--$" | head -6
                        echo ""
                        found=1
                    fi
                fi
            fi

            # 2. Check tools.json
            if [ "$found" -eq 0 ] && [ -f "$tools_json" ]; then
                if command -v jq >/dev/null 2>&1; then
                    local desc path_val
                    desc=$(jq -r --arg n "$name" '.tools[] | select(.name == $n) | .description // ""' "$tools_json" 2>/dev/null)
                    path_val=$(jq -r --arg n "$name" '.tools[] | select(.name == $n) | .path // ""' "$tools_json" 2>/dev/null)
                    if [ -n "$desc" ]; then
                        echo ""
                        echo "  $name — $desc"
                        echo "  Path: $path_val"
                        echo ""
                        found=1
                    fi
                fi
            fi

            # 3. Fall back to --help
            if [ "$found" -eq 0 ]; then
                if command -v "$name" >/dev/null 2>&1; then
                    echo "  '$name' not in registry — showing --help output:"
                    echo ""
                    "$name" --help 2>&1 | head -20 | sed 's/^/  /'
                    echo ""
                else
                    echo "  '$name' not found in aliases.json, tools.json, or PATH." >&2
                    echo "  Try: dotfiles help $name" >&2
                    return 1
                fi
            fi
            ;;
        agent)
            # Wire --setup; inference is Phase 4 (Tank)
            local subarg="${1:-}"
            local extraflag="${2:-}"
            local agent_lib="${DOTFILES}/shell/lib/agent.sh"

            if [ "$subarg" = "--setup" ]; then
                if [ ! -f "$agent_lib" ]; then
                    echo "dotfiles: agent lib not found at $agent_lib" >&2
                    return 1
                fi
                # shellcheck source=/dev/null
                . "$agent_lib"
                if [ "$extraflag" = "--fallback" ]; then
                    install_agent_engine --fallback
                else
                    install_agent_engine
                fi
                return $?
            fi

            if [ -n "$subarg" ] && [ "${subarg#--}" = "$subarg" ]; then
                if [ ! -f "$agent_lib" ]; then
                    echo "dotfiles: agent lib not found at $agent_lib" >&2
                    return 1
                fi
                # shellcheck source=/dev/null
                . "$agent_lib"
                dotfiles_agent "$subarg" "${extraflag:-}"
                return $?
            fi

            echo "Usage:"
            echo "  dotfiles agent --setup             Download engine + primary model"
            echo "  dotfiles agent --setup --fallback  Download engine + 0.5B model"
            echo "  dotfiles agent \"<query>\"           Generate a shell command"
            echo "  dotfiles agent \"<query>\" --run     Generate and optionally execute"
            ;;
        *)
            echo "Usage: dotfiles <help|list|update|edit|explain|agent> [args]" >&2
            return 1
            ;;
    esac
}

