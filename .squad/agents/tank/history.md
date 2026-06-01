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

### 2026-06-01 — Robustness fixes: pipefail + curl/grep + arch detection

- **pipefail + command-substitution gotcha**: Under `set -euo pipefail`, a pipeline inside `$()` can still kill the script if `grep` finds no match — it returns exit code 1 which propagates through the pipe and then through the assignment statement. Fix: append `|| true` to the entire command substitution, then explicitly check `if [ -z "$var" ]` and handle the empty case. This pattern is necessary anywhere you run `curl | grep` to parse headers.
- **Leaked temp dir on early exit**: When `mktemp` creates a directory before a command that can fail, any early-exit path (including the pipefail abort above) must `rm -rf "$tmp_dir"`. Always pair `mktemp` with a cleanup guard immediately after, or use a `trap` for the function scope.
- **Arch detection for delta**: delta's release assets use different libc suffixes per arch: x86_64 uses `musl` (statically linked, distro-agnostic), aarch64 uses `gnu`, and armv7 uses `gnueabihf`. Hardcoding `x86_64` silently installs a broken binary on ARM hosts. Pattern: set a `delta_target` variable via `case "$(uname -m)"` covering `aarch64|arm64`, `armv7l|arm`, and default x86_64, then interpolate into the full target triple in the URL.
- **curl | bash failure isolation**: `curl ... | bash` and `curl ... | sh` as standalone statements abort the whole installer on network failure. Append `|| { warn "..."; return 0; }` so optional tool installs degrade gracefully and the critical shell-wiring steps (write_stub calls) always execute.
