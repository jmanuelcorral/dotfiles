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
# Reads shared/tools.json and docs/cheatsheet.md.
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
        *)
            echo "Usage: dotfiles <help|list|update|edit> [query]" >&2
            return 1
            ;;
    esac
}

