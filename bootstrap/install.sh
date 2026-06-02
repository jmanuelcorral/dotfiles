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

# ── Helpers ───────────────────────────────────────────────────────────────────
info()    { printf '\e[34m[dotfiles]\e[0m %s\n' "$*"; }
ok()      { printf '\e[32m[  ok   ]\e[0m %s\n' "$*"; }
skip()    { printf '\e[33m[ skip  ]\e[0m %s\n' "$*"; }
warn()    { printf '\e[33m[ warn  ]\e[0m %s\n' "$*"; }
err()     { printf '\e[31m[ error ]\e[0m %s\n' "$*" >&2; }

has() { command -v "$1" >/dev/null 2>&1; }

# ── Self-bootstrap (curl | bash mode) ────────────────────────────────────────
# When piped via `curl ... | bash`, BASH_SOURCE[0] is not a real file on disk.
# Detect this, clone/update the repo, then exec the on-disk installer so the
# rest of this script runs from a proper path (SCRIPT_DIR/DOTFILES are valid).
_bs_src="${BASH_SOURCE[0]:-}"
if [ -z "$_bs_src" ] || [ "$_bs_src" = "bash" ] || [ "$_bs_src" = "sh" ] \
    || [ ! -f "$_bs_src" ]; then
    info "Running in piped/bootstrap mode — cloning repo first."
    if ! has git; then
        err "git is required but not installed. Please install git and re-run."
        exit 1
    fi
    _bs_target="${DOTFILES:-${HOME}/dotfiles}"
    if [ -d "${_bs_target}/.git" ]; then
        info "Repo already exists at ${_bs_target}; pulling latest..."
        git -C "${_bs_target}" pull --ff-only || \
            warn "git pull failed; continuing with existing checkout."
    else
        info "Cloning dotfiles to ${_bs_target}..."
        git clone https://github.com/jmanuelcorral/dotfiles.git "${_bs_target}" || {
            err "git clone failed. Check your network connection and try again."
            exit 1
        }
        ok "Cloned to ${_bs_target}"
    fi
    info "Re-launching on-disk installer..."
    exec bash "${_bs_target}/bootstrap/install.sh" "$@"
fi
unset _bs_src _bs_target

# ── Resolve DOTFILES root from this script's location ────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES="$(cd "${SCRIPT_DIR}/.." && pwd)"
DOTFILES_VERSION="0.0.0"
if [ -f "${DOTFILES}/VERSION" ]; then
    DOTFILES_VERSION="$(sed -n '1{s/[[:space:]]//g;p;q;}' "${DOTFILES}/VERSION")"
fi

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

# Helper: download Meslo.zip from Nerd Fonts releases and install ttf files into $1.
# $2 = "true" to run fc-cache afterward (Linux only).
_nerd_font_download_zip() {
    local font_dir="$1"
    local run_fccache="$2"
    local zip_url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Meslo.zip"

    # Require a downloader
    local downloader=""
    if has curl; then
        downloader="curl"
    elif has wget; then
        downloader="wget"
    else
        warn "Nerd Font: curl and wget are both missing — cannot download."
        warn "  Install one then re-run, or download manually: ${zip_url}"
        return 0
    fi

    # Require unzip
    if ! has unzip; then
        warn "Nerd Font: unzip not found — cannot extract the font archive."
        warn "  Install unzip and re-run, or download manually: ${zip_url}"
        return 0
    fi

    mkdir -p "$font_dir"
    local tmp_dir
    tmp_dir="$(mktemp -d -p "${HOME}")"

    info "Downloading Meslo Nerd Font from Nerd Fonts releases..."
    if [ "$downloader" = "curl" ]; then
        curl -sL "$zip_url" -o "${tmp_dir}/Meslo.zip" || {
            warn "Nerd Font: download failed. Install manually: ${zip_url}"
            rm -rf "$tmp_dir"
            return 0
        }
    else
        wget -q "$zip_url" -O "${tmp_dir}/Meslo.zip" || {
            warn "Nerd Font: download failed. Install manually: ${zip_url}"
            rm -rf "$tmp_dir"
            return 0
        }
    fi

    info "Extracting MesloLG*.ttf files..."
    mkdir -p "${tmp_dir}/extracted"
    unzip -o "${tmp_dir}/Meslo.zip" 'MesloLG*.ttf' -d "${tmp_dir}/extracted" \
        >/dev/null 2>&1 || {
        warn "Nerd Font: unzip failed — archive may be corrupt. Install manually: ${zip_url}"
        rm -rf "$tmp_dir"
        return 0
    }

    local ttf_count=0
    for ttf_file in "${tmp_dir}/extracted"/MesloLG*.ttf; do
        [ -f "$ttf_file" ] || continue
        cp "$ttf_file" "$font_dir/"
        ttf_count=$((ttf_count + 1))
    done

    rm -rf "$tmp_dir"

    if [ "$ttf_count" -eq 0 ]; then
        warn "Nerd Font: no MesloLG*.ttf files found in archive. Install manually: ${zip_url}"
        return 0
    fi

    ok "Meslo Nerd Font: ${ttf_count} file(s) installed to ${font_dir}"

    if [ "$run_fccache" = "true" ]; then
        if has fc-cache; then
            info "Refreshing font cache..."
            fc-cache -f "$font_dir" 2>/dev/null || true
            ok "Font cache refreshed"
        else
            warn "Nerd Font: fc-cache not found — run 'fc-cache -f' after installing fontconfig."
        fi
    fi
}

install_nerd_font() {
    local os_type
    os_type="$(uname -s 2>/dev/null)" || os_type="Linux"

    # ── macOS ─────────────────────────────────────────────────────────────────
    if [ "$os_type" = "Darwin" ]; then
        # Brew cask installs to ~/Library/Fonts; also check the system dir
        if find "${HOME}/Library/Fonts" /Library/Fonts \
               -name 'MesloLG*.ttf' -type f 2>/dev/null | grep -q .; then
            skip "Meslo Nerd Font (already present in Fonts)"
            return 0
        fi
        if has brew; then
            info "Installing Meslo Nerd Font via brew cask..."
            brew install --cask font-meslo-lg-nerd-font || {
                warn "Nerd Font: brew cask install failed."
                warn "  Try manually: brew install --cask font-meslo-lg-nerd-font"
                return 0
            }
            ok "Meslo Nerd Font installed via brew"
        else
            _nerd_font_download_zip "${HOME}/Library/Fonts" false
        fi
        info "ACTION REQUIRED: set your terminal font face to 'MesloLGS NF'."
        return 0
    fi

    # ── Linux / WSL ───────────────────────────────────────────────────────────
    local font_dir="${HOME}/.local/share/fonts"
    if find "$font_dir" -name 'MesloLG*.ttf' -type f 2>/dev/null | grep -q .; then
        skip "Meslo Nerd Font (already present in ${font_dir})"
        return 0
    fi
    info "Installing Meslo Nerd Font to ${font_dir}..."
    _nerd_font_download_zip "$font_dir" true
    info "ACTION REQUIRED: set your terminal font face to 'MesloLGS NF'."
    info "  WSL / Windows Terminal → Settings → Profile → Appearance → Font face → 'MesloLGS NF'"
    info "  Linux GUI terminal    → Preferences → Font → 'MesloLGS NF'"
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
    info " dotfiles bootstrap v${DOTFILES_VERSION} — Unix/WSL installer"
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
    info " Font tip: set terminal font face to 'MesloLGS NF'"
    info "═══════════════════════════════════════════════"
    echo ""
}

main "$@"
