# Tank — History

## Seed Context

- **Project:** dotfiles — portable terminal/shell configuration repo
- **Stack:** bash/zsh (WSL), Git, Python, Node.js, Oh My Posh/starship
- **Goals:** bash/zsh config + setup.sh for WSL/Linux that mirrors the Windows/PowerShell setup; portable across distros; idempotent.
- **Requested by:** Copilot (git user.name)

## Learnings

### 2026-06-01 — Shell config implementation

- **batcat/fdfind quirk**: Ubuntu apt installs `bat` as `batcat` and `fd` as `fdfind` due to namespace conflicts. Both bootstrap/install.sh (creates symlinks in `~/.local/bin`) and common.sh (shell function wrappers) handle this two-layer defence. The symlink approach is more robust; the shell functions are a belt-and-suspenders fallback.
- **eza apt availability**: Only available natively in Ubuntu 23.10+. For older LTS (22.04), the official gierens.de apt repository is the cleanest path. cargo is a last resort.
- **zoxide apt availability**: Ubuntu 22.10+. Official install script used as fallback for older LTS.
- **delta not in apt**: Must be fetched from GitHub releases (musl binary = no libc dependency = always works). Wrote auto-detect for arch.
- **yq ambiguity**: Two tools called `yq` exist (python-yq via pip, and mikefarah/yq which is the recommended Go binary). Always install from GitHub releases to avoid getting the wrong one.
- **starship vs oh-my-posh**: WSL shells use starship; PowerShell keeps oh-my-posh. Guard in zshrc.sh checks for `$ZSH` (oh-my-zsh) and `$POWERLEVEL9K_*` to avoid double-prompting.
- **zshrc compinit guard**: Checking `typeset -f compinit` before calling `autoload` prevents double-init conflicts with oh-my-zsh.
- **POSIX in common.sh**: Avoided bashisms (`[[`, `local` inside sourced context, `echo -e`). Used `[ ]`, printf, and portable parameter expansion. The file passes `bash -n` cleanly via Git Bash 5.3.
- **No WSL Ubuntu available for testing**: The machine only has docker-desktop WSL distro, not Ubuntu. Syntax validated via Git Bash 5.3 instead. Real-machine testing on Ubuntu WSL is recommended before first use.
- **mktemp in install.sh**: Used `mktemp -d -p "$HOME"` to avoid /tmp which is forbidden. Delta download uses a temp dir under $HOME.
- **dotfiles CLI function**: Kept parity with the PowerShell `dotfiles` command behavior described in cheatsheet.md. fzf used for interactive `dotfiles help`, grep/rg for keyword search, jq for `dotfiles list`.
- **fzf shell integration paths**: Checked both `~/.fzf/` (manual/git install) and `/usr/share/doc/fzf/examples/` (apt install) to load key-bindings and completion.
