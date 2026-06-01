#!/usr/bin/env bash
# bootstrap/install.sh — Unix/WSL one-shot installer
# Owner: Tank
# Usage:
#   bash bootstrap/install.sh              # full install
#   bash bootstrap/install.sh --no-packages  # only wire shell stubs
#
# Safe to re-run (idempotent). Backs up ~/.bashrc / ~/.zshrc before modifying.

set -euo pipefail

# ── Constants ─────────────────────────────────────────────────────────────────
MARKER="# dotfiles bootstrap"
TIMESTAMP="$(date +%Y-%m-%d-%H%M%S)"
INSTALL_PACKAGES=true

# ── Parse args ────────────────────────────────────────────────────────────────
for arg in "$@"; do
    case "$arg" in
        --no-packages) INSTALL_PACKAGES=false ;;
        --help|-h)
            echo "Usage: $0 [--no-packages]"
            echo "  --no-packages  Only write shell stubs; skip package installs."
            exit 0
            ;;
        *) echo "Unknown argument: $arg" >&2; exit 1 ;;
    esac
done

# ── Resolve DOTFILES root from this script's location ────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES="$(cd "${SCRIPT_DIR}/.." && pwd)"

# ── Helpers ───────────────────────────────────────────────────────────────────
info()    { printf '\e[34m[dotfiles]\e[0m %s\n' "$*"; }
ok()      { printf '\e[32m[  ok   ]\e[0m %s\n' "$*"; }
skip()    { printf '\e[33m[ skip  ]\e[0m %s\n' "$*"; }
warn()    { printf '\e[33m[ warn  ]\e[0m %s\n' "$*"; }
err()     { printf '\e[31m[ error ]\e[0m %s\n' "$*" >&2; }

has() { command -v "$1" >/dev/null 2>&1; }

# ── Detect package manager ────────────────────────────────────────────────────
detect_pkg_manager() {
    if has apt-get; then
        echo "apt"
    elif has dnf; then
        echo "dnf"
    elif has pacman; then
        echo "pacman"
    elif has brew; then
        echo "brew"
    else
        echo "none"
    fi
}

PKG_MANAGER="$(detect_pkg_manager)"
info "Detected package manager: ${PKG_MANAGER}"
info "DOTFILES root: ${DOTFILES}"

# ── Ensure ~/.local/bin exists ────────────────────────────────────────────────
mkdir -p "${HOME}/.local/bin"
case ":${PATH}:" in
    *":${HOME}/.local/bin:"*) ;;
    *) export PATH="${HOME}/.local/bin:${PATH}" ;;
esac

# ── Package install functions ─────────────────────────────────────────────────

apt_install_tool() {
    local pkg="$1"
    local binary="${2:-$1}"
    if has "$binary"; then
        skip "$pkg (binary '${binary}' already in PATH)"
        return 0
    fi
    info "Installing $pkg via apt..."
    sudo apt-get install -y "$pkg"
    ok "$pkg installed"
}

install_tool_apt_list() {
    # Core tools available in apt
    local tools=(
        "git:git"
        "curl:curl"
        "wget:wget"
        "unzip:unzip"
        "ripgrep:rg"
        "fzf:fzf"
        "jq:jq"
        "duf:duf"
    )
    for entry in "${tools[@]}"; do
        local pkg="${entry%%:*}"
        local bin="${entry##*:}"
        apt_install_tool "$pkg" "$bin"
    done
}

install_bat() {
    if has bat; then
        skip "bat (already present)"
        return 0
    fi
    if has batcat; then
        skip "bat (present as 'batcat')"
        # Ensure symlink exists
        if [ ! -e "${HOME}/.local/bin/bat" ]; then
            ln -s "$(command -v batcat)" "${HOME}/.local/bin/bat"
            ok "Created ~/.local/bin/bat → batcat"
        fi
        return 0
    fi
    info "Installing bat via apt..."
    sudo apt-get install -y bat 2>/dev/null || sudo apt-get install -y batcat 2>/dev/null || {
        warn "bat not found in apt; skipping. Install manually: cargo install bat"
        return 0
    }
    # After install, check which binary name was used
    if has batcat && [ ! -e "${HOME}/.local/bin/bat" ]; then
        ln -s "$(command -v batcat)" "${HOME}/.local/bin/bat"
        ok "Created ~/.local/bin/bat → batcat"
    else
        ok "bat installed"
    fi
}

install_fd() {
    if has fd; then
        skip "fd (already present)"
        return 0
    fi
    if has fdfind; then
        skip "fd (present as 'fdfind')"
        if [ ! -e "${HOME}/.local/bin/fd" ]; then
            ln -s "$(command -v fdfind)" "${HOME}/.local/bin/fd"
            ok "Created ~/.local/bin/fd → fdfind"
        fi
        return 0
    fi
    info "Installing fd-find via apt..."
    sudo apt-get install -y fd-find 2>/dev/null || {
        warn "fd-find not found in apt; skipping. Install manually: cargo install fd-find"
        return 0
    }
    if has fdfind && [ ! -e "${HOME}/.local/bin/fd" ]; then
        ln -s "$(command -v fdfind)" "${HOME}/.local/bin/fd"
        ok "Created ~/.local/bin/fd → fdfind"
    else
        ok "fd installed"
    fi
}

install_eza() {
    if has eza; then
        skip "eza (already present)"
        return 0
    fi
    info "Installing eza..."
    # Try apt first (Ubuntu 23.10+)
    if sudo apt-get install -y eza 2>/dev/null; then
        ok "eza installed via apt"
        return 0
    fi
    # Fallback: add the official eza apt repository for older Ubuntu
    if has gpg && has wget; then
        info "Adding eza apt repository (gpg + wget)..."
        sudo mkdir -p /etc/apt/keyrings
        wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc \
            | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg 2>/dev/null || true
        echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" \
            | sudo tee /etc/apt/sources.list.d/gierens.list >/dev/null
        sudo chmod 644 /etc/apt/keyrings/gierens.gpg \
                       /etc/apt/sources.list.d/gierens.list 2>/dev/null || true
        sudo apt-get update -qq && sudo apt-get install -y eza && ok "eza installed via eza apt repo"
    elif has cargo; then
        info "Installing eza via cargo..."
        cargo install eza && ok "eza installed via cargo"
    else
        warn "eza: could not install. Install manually: cargo install eza"
    fi
}

install_zoxide() {
    if has zoxide; then
        skip "zoxide (already present)"
        return 0
    fi
    info "Installing zoxide..."
    # Try apt first (Ubuntu 22.10+)
    if sudo apt-get install -y zoxide 2>/dev/null; then
        ok "zoxide installed via apt"
        return 0
    fi
    # Fallback: official install script
    if has curl; then
        curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash \
            || { warn "zoxide: install script failed; install manually: https://github.com/ajeetdsouza/zoxide"; return 0; }
        ok "zoxide installed via official script"
    else
        warn "zoxide: curl not found. Install manually."
    fi
}

install_starship() {
    if has starship; then
        skip "starship (already present)"
        return 0
    fi
    info "Installing starship via official script..."
    if has curl; then
        curl -sS https://starship.rs/install.sh | sh -s -- --yes \
            || { warn "starship: install script failed; install manually: https://starship.rs"; return 0; }
        ok "starship installed"
    else
        warn "starship: curl not found. Install manually: https://starship.rs/guide/"
    fi
}

install_delta() {
    if has delta; then
        skip "delta (already present)"
        return 0
    fi
    info "Installing git-delta from GitHub releases..."
    if ! has curl; then
        warn "delta: curl not found. Install manually."
        return 0
    fi
    local tmp_dir
    tmp_dir="$(mktemp -d -p "${HOME}")"  # uses $HOME, not /tmp
    local latest_url
    latest_url="$(curl -sI https://github.com/dandavison/delta/releases/latest \
        | grep -i '^location:' | tr -d '\r\n' | sed 's/.*location: //')" || true
    if [ -z "$latest_url" ]; then
        warn "delta: could not resolve latest release URL. Install manually: cargo install git-delta"
        rm -rf "$tmp_dir"
        return 0
    fi
    local version="${latest_url##*/}"
    local delta_target="x86_64-unknown-linux-musl"
    case "$(uname -m)" in
        aarch64|arm64) delta_target="aarch64-unknown-linux-gnu" ;;
        armv7l|arm)    delta_target="arm-unknown-linux-gnueabihf" ;;
    esac
    local download_url="https://github.com/dandavison/delta/releases/download/${version}/delta-${version}-${delta_target}.tar.gz"

    curl -sL "$download_url" -o "${tmp_dir}/delta.tar.gz" || {
        warn "delta: download failed. Install manually: cargo install git-delta"
        rm -rf "$tmp_dir"
        return 0
    }
    tar -xzf "${tmp_dir}/delta.tar.gz" -C "$tmp_dir" 2>/dev/null || true
    local delta_bin
    delta_bin="$(find "$tmp_dir" -name 'delta' -type f 2>/dev/null | head -1)"
    if [ -n "$delta_bin" ]; then
        install -m 0755 "$delta_bin" "${HOME}/.local/bin/delta"
        ok "delta installed to ~/.local/bin/delta"
    else
        warn "delta: binary not found in archive. Skipping."
    fi
    rm -rf "$tmp_dir"
}

install_yq() {
    if has yq; then
        skip "yq (already present)"
        return 0
    fi
    info "Installing yq (mikefarah) from GitHub releases..."
    if ! has curl; then
        warn "yq: curl not found. Install manually."
        return 0
    fi
    local arch="amd64"
    case "$(uname -m)" in
        aarch64|arm64) arch="arm64" ;;
        armv7*)        arch="arm"   ;;
    esac
    local yq_url
    yq_url="$(curl -sI https://github.com/mikefarah/yq/releases/latest \
        | grep -i '^location:' | tr -d '\r\n' | sed 's/.*location: //')" || true
    if [ -z "$yq_url" ]; then
        warn "yq: could not resolve latest release URL. Install manually: https://github.com/mikefarah/yq"
        return 0
    fi
    local version="${yq_url##*/}"
    local download_url="https://github.com/mikefarah/yq/releases/download/${version}/yq_linux_${arch}"

    curl -sL "$download_url" -o "${HOME}/.local/bin/yq" || {
        warn "yq: download failed. Install manually."
        return 0
    }
    chmod +x "${HOME}/.local/bin/yq"
    ok "yq installed to ~/.local/bin/yq"
}

install_nerd_font() {
    local font_dir="${HOME}/.local/share/fonts"
    # Check if MesloLGS NF is already present
    if find "$font_dir" -name 'MesloLGS*' -type f 2>/dev/null | grep -q .; then
        skip "MesloLGS NF (already present in ${font_dir})"
        return 0
    fi
    info "Installing MesloLGS NF fonts to ${font_dir}..."
    # NOTE: In WSL, the terminal font is set in Windows Terminal settings.json
    # This install is primarily for native Linux GUI environments.
    # For WSL users: set the Nerd Font in Windows Terminal → Settings → Default Profile → Font face.
    mkdir -p "$font_dir"
    local base_url="https://github.com/romkatv/powerlevel10k-media/raw/master"
    local fonts=(
        "MesloLGS NF Regular.ttf"
        "MesloLGS NF Bold.ttf"
        "MesloLGS NF Italic.ttf"
        "MesloLGS NF Bold Italic.ttf"
    )
    local any_installed=false
    for font in "${fonts[@]}"; do
        local encoded_font="${font// /%20}"
        local dest="${font_dir}/${font}"
        if [ ! -f "$dest" ] && has curl; then
            curl -sL "${base_url}/${encoded_font}" -o "$dest" && any_installed=true
        fi
    done
    if [ "$any_installed" = true ]; then
        # Refresh font cache on native Linux
        has fc-cache && fc-cache -fv "$font_dir" 2>/dev/null | grep -v '^$' || true
        ok "MesloLGS NF installed"
        info "WSL users: set font to 'MesloLGS NF' in Windows Terminal settings."
    else
        warn "MesloLGS NF: could not download fonts. Install manually."
    fi
}

configure_git_delta() {
    if ! has delta; then
        return 0
    fi
    if git config --global core.pager 2>/dev/null | grep -q delta; then
        skip "git-delta gitconfig (already configured)"
        return 0
    fi
    info "Configuring git to use delta as pager..."
    git config --global core.pager "delta"
    git config --global interactive.diffFilter "delta --color-only"
    git config --global delta.navigate "true"
    git config --global delta.side-by-side "true"
    git config --global delta.line-numbers "true"
    ok "git-delta configured in ~/.gitconfig"
}

# ── Write idempotent shell stub ───────────────────────────────────────────────
write_stub() {
    local rc_file="$1"
    local shell_file="$2"   # e.g. $DOTFILES/shell/bash/bashrc.sh

    if grep -q "${MARKER}" "${rc_file}" 2>/dev/null; then
        skip "${rc_file} (stub already present)"
        return 0
    fi

    # Backup before modifying
    if [ -f "${rc_file}" ]; then
        local backup="${rc_file}.backup.${TIMESTAMP}"
        cp "${rc_file}" "${backup}"
        info "Backed up ${rc_file} → ${backup}"
    fi

    cat >> "${rc_file}" <<EOF

${MARKER} — DO NOT EDIT BELOW (added ${TIMESTAMP})
export DOTFILES="${DOTFILES}"
# shellcheck source=${shell_file}
source "\${DOTFILES}/${shell_file}"
EOF
    ok "Stub written to ${rc_file}"
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
    echo ""
    info "═══════════════════════════════════════════════"
    info " dotfiles bootstrap — Unix/WSL installer"
    info " Repo: ${DOTFILES}"
    info "═══════════════════════════════════════════════"
    echo ""

    if [ "$INSTALL_PACKAGES" = true ]; then
        if [ "$PKG_MANAGER" = "apt" ]; then
            info "Updating apt package lists..."
            sudo apt-get update -qq
            install_tool_apt_list
            install_bat
            install_fd
            install_eza
            install_zoxide
        elif [ "$PKG_MANAGER" = "brew" ]; then
            info "Using brew for package installs..."
            for tool in git curl wget ripgrep fzf jq bat fd eza zoxide; do
                if has "$tool"; then
                    skip "$tool (already present)"
                else
                    brew install "$tool" && ok "$tool installed"
                fi
            done
        elif [ "$PKG_MANAGER" = "dnf" ]; then
            info "Using dnf for package installs..."
            for tool in git curl wget ripgrep fzf jq bat fd-find eza zoxide; do
                pkg="${tool}"
                bin="${tool}"
                [ "$tool" = "fd-find" ] && bin="fd"
                if has "$bin"; then skip "$tool"; else sudo dnf install -y "$pkg" && ok "$tool installed"; fi
            done
        elif [ "$PKG_MANAGER" = "pacman" ]; then
            info "Using pacman for package installs..."
            for tool in git curl wget ripgrep fzf jq bat fd eza zoxide; do
                if has "$tool"; then skip "$tool"; else sudo pacman -S --noconfirm "$tool" && ok "$tool installed"; fi
            done
        else
            warn "No supported package manager found (apt/dnf/pacman/brew). Skipping package installs."
        fi

        install_delta
        install_yq
        install_starship
        install_nerd_font
        configure_git_delta

        echo ""
    else
        info "Skipping package installs (--no-packages)"
    fi

    info "Writing shell stubs..."
    write_stub "${HOME}/.bashrc"  "shell/bash/bashrc.sh"
    write_stub "${HOME}/.zshrc"   "shell/zsh/zshrc.sh"

    echo ""
    info "═══════════════════════════════════════════════"
    ok " Bootstrap complete!"
    info " Open a new terminal (or run: source ~/.bashrc)"
    info "═══════════════════════════════════════════════"
    echo ""
}

main "$@"

