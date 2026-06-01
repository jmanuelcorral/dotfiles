# shell/bash/bashrc.sh — Bash-specific configuration
# Owner: Tank
# Sourced by the thin stub in ~/.bashrc:
#   export DOTFILES="<clone-path>"
#   source "$DOTFILES/shell/bash/bashrc.sh"

# Guard: only run in interactive shells
[ -z "${PS1:-}" ] && [ "${-#*i}" = "$-" ] && return

# ── 1. Source common config ───────────────────────────────────────────────────
# shellcheck source=../common.sh
. "${DOTFILES}/shell/common.sh"

# ── 2. History settings ───────────────────────────────────────────────────────
HISTSIZE=50000
HISTFILESIZE=100000
HISTCONTROL=ignoreboth:erasedups   # ignore duplicates and lines starting with space
HISTTIMEFORMAT='%F %T  '           # timestamp in history
shopt -s histappend                 # append to history file, don't overwrite
# Write to history after every command (shared across terminals)
PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND; }history -a"

# ── 3. Shell options ──────────────────────────────────────────────────────────
shopt -s checkwinsize    # update LINES/COLUMNS after each command
shopt -s globstar        # ** glob for recursive matching
shopt -s cdspell         # auto-correct minor cd typos
shopt -s autocd          # type a directory name to cd into it
shopt -s dirspell        # correct directory spelling on completion

# ── 4. Bash completion ────────────────────────────────────────────────────────
if [ -f /usr/share/bash-completion/bash_completion ]; then
    # shellcheck source=/dev/null
    . /usr/share/bash-completion/bash_completion
elif [ -f /etc/bash_completion ]; then
    # shellcheck source=/dev/null
    . /etc/bash_completion
fi

# Homebrew completions (macOS / Linuxbrew)
if command -v brew >/dev/null 2>&1; then
    _brew_prefix="$(brew --prefix 2>/dev/null)"
    if [ -r "${_brew_prefix}/etc/profile.d/bash_completion.sh" ]; then
        # shellcheck source=/dev/null
        . "${_brew_prefix}/etc/profile.d/bash_completion.sh"
    fi
    unset _brew_prefix
fi

# ── 5. zoxide (bash init) ─────────────────────────────────────────────────────
if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init bash)"
fi

# ── 6. Starship prompt ────────────────────────────────────────────────────────
if command -v starship >/dev/null 2>&1; then
    eval "$(starship init bash)"
else
    # Minimal fallback PS1 when starship is not installed
    PS1='\[\e[32m\]\u@\h\[\e[0m\]:\[\e[34m\]\w\[\e[0m\]\$ '
fi

