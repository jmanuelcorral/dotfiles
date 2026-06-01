# shell/zsh/zshrc.sh — Zsh-specific configuration
# Owner: Tank
# Sourced by the thin stub in ~/.zshrc:
#   export DOTFILES="<clone-path>"
#   source "$DOTFILES/shell/zsh/zshrc.sh"

# ── 1. Source common config ───────────────────────────────────────────────────
# shellcheck source=../common.sh
. "${DOTFILES}/shell/common.sh"

# ── 2. History settings ───────────────────────────────────────────────────────
HISTFILE="${HOME}/.zsh_history"
HISTSIZE=50000
SAVEHIST=100000
setopt HIST_IGNORE_ALL_DUPS    # don't record duplicates
setopt HIST_IGNORE_SPACE       # don't record lines starting with space
setopt HIST_VERIFY             # show expanded history before executing
setopt SHARE_HISTORY           # share history across all zsh sessions
setopt APPEND_HISTORY          # append to history file
setopt INC_APPEND_HISTORY      # write immediately (not on exit)
setopt EXTENDED_HISTORY        # save timestamp + duration

# ── 3. Zsh options ────────────────────────────────────────────────────────────
setopt AUTO_CD                 # type a directory name to cd
setopt AUTO_PUSHD              # cd pushes old dir to stack
setopt PUSHD_IGNORE_DUPS       # no duplicates in dir stack
setopt CORRECT                 # spell correction for commands
setopt CORRECT_ALL             # spell correction for args
setopt GLOB_DOTS               # include dotfiles in globbing
setopt EXTENDED_GLOB           # extended glob patterns (#, ^, ~)
setopt NO_BEEP                 # silence the beep
setopt INTERACTIVE_COMMENTS    # allow # comments in interactive shell

# ── 4. Completion (compinit) ──────────────────────────────────────────────────
# Only load compinit if oh-my-zsh hasn't already loaded it
if ! typeset -f compinit >/dev/null 2>&1 || ! typeset -f compdef >/dev/null 2>&1; then
    autoload -Uz compinit
    # Rebuild completion cache at most once per day
    _zcompdump="${ZDOTDIR:-$HOME}/.zcompdump"
    if [ -f "$_zcompdump" ] && \
       [ "$(find "$_zcompdump" -mtime +1 2>/dev/null)" != "" ]; then
        compinit -d "$_zcompdump"
    elif [ ! -f "$_zcompdump" ]; then
        compinit -d "$_zcompdump"
    else
        compinit -C -d "$_zcompdump"
    fi
    unset _zcompdump
fi

# Completion styling
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'  # case-insensitive
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*:descriptions' format '%F{yellow}-- %d --%f'
zstyle ':completion:*:warnings' format '%F{red}No matches for: %d%f'
zstyle ':completion:*' group-name ''
zstyle ':completion::complete:*' use-cache on
zstyle ':completion::complete:*' cache-path "${ZDOTDIR:-$HOME}/.zcompcache"

# ── 5. Key bindings ───────────────────────────────────────────────────────────
bindkey -e                          # emacs key bindings (Ctrl+A, Ctrl+E, etc.)
bindkey '^[[A' history-search-backward  # up arrow searches history
bindkey '^[[B' history-search-forward   # down arrow searches history
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^[[3~' delete-char

# ── 6. zoxide (zsh init) ──────────────────────────────────────────────────────
if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init zsh)"
fi

# ── 7. Starship prompt ────────────────────────────────────────────────────────
# Guard: don't start Starship if oh-my-zsh is already providing a prompt theme
# (oh-my-zsh sets ZSH variable; Powerlevel10k sets POWERLEVEL9K_* — skip both)
if command -v starship >/dev/null 2>&1 && \
   [ -z "${ZSH:-}" ] && \
   [ -z "${POWERLEVEL9K_LEFT_PROMPT_ELEMENTS:-}" ]; then
    eval "$(starship init zsh)"
fi

