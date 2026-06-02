#!/usr/bin/env sh
# shell/lib/agent.sh — Agent engine + model bootstrapper for bash/zsh
# Owner   : Switch
# Phase   : 2 (Bootstrap / Installer)
# Compatible: bash 3.2+, zsh 5+, POSIX sh
#
# Exports (source this file to use):
#   install_agent_engine [--fallback]   Download llama-cli + model; idempotent.
#   agent_paths                         Print key=value pairs of well-known paths.
#   agent_ready                         Exit 0 if engine+model present, else 1.
#
# NOT IMPLEMENTED HERE (placeholder for Tank, Phase 4):
#   dotfiles_agent_query "<query>"      Build prompt, invoke llama-cli, post-process.
#   See: docs/plans/local-agent-plan.md §5 for the full prompt contract.

# ── Internal: resolve root and config ─────────────────────────────────────────

_agent_root() {
    if [ -n "${DOTFILES:-}" ]; then
        printf '%s' "$DOTFILES"
    else
        # This file lives at <root>/shell/lib/agent.sh
        _lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)"
        printf '%s' "$(cd "$_lib_dir/../.." && pwd)"
        unset _lib_dir
    fi
}

_agent_cache_dir() {
    if [ -n "${DOTFILES_CACHE:-}" ]; then
        printf '%s' "$DOTFILES_CACHE"
    else
        printf '%s' "$(_agent_root)/cache"
    fi
}

_agent_config_file() {
    printf '%s' "$(_agent_root)/shared/agent-config.json"
}

# ── Internal: platform detection ──────────────────────────────────────────────

_agent_platform_key() {
    local arch
    arch="$(uname -m 2>/dev/null)"
    case "$arch" in
        x86_64)  printf 'linux-x64' ;;
        aarch64|arm64) printf 'linux-arm64' ;;
        *)       printf 'linux-x64' ;; # best guess
    esac
}

# ── Internal: jq-based config reads ───────────────────────────────────────────

_cfg_read() {
    # Usage: _cfg_read '<jq filter>'
    local filter="$1"
    local cfg_file
    cfg_file="$(_agent_config_file)"
    if ! command -v jq >/dev/null 2>&1; then
        echo "dotfiles agent: jq is required for agent setup." >&2
        return 1
    fi
    jq -r "$filter" "$cfg_file" 2>/dev/null
}

# ── Internal: integrity check ──────────────────────────────────────────────────
# SHA256 is optional: when null, verify by size (±10%) only.

_check_integrity() {
    local file="$1"
    local expected_sha256="$2"   # may be "null" or empty
    local expected_size_mb="$3"  # integer; 0 = skip

    [ -f "$file" ] || return 1

    # SHA256 check (preferred)
    if [ -n "$expected_sha256" ] && [ "$expected_sha256" != "null" ]; then
        local actual
        if command -v sha256sum >/dev/null 2>&1; then
            actual="$(sha256sum "$file" | awk '{print $1}')"
        elif command -v shasum >/dev/null 2>&1; then
            actual="$(shasum -a 256 "$file" | awk '{print $1}')"
        else
            echo "  ⚠  No sha256sum/shasum available; skipping SHA256 check." >&2
            return 0
        fi
        if [ "$actual" != "$expected_sha256" ]; then
            echo "  ✗ SHA256 mismatch for $(basename "$file")" >&2
            return 1
        fi
        return 0
    fi

    # Fallback: size sanity check (truncated/failed download is the real risk).
    # Accept 70%-150% of expected; the exact size can drift across model revisions.
    if [ "${expected_size_mb:-0}" -gt 0 ] 2>/dev/null; then
        local size_bytes size_mb low high
        size_bytes="$(wc -c < "$file" 2>/dev/null | tr -d ' ')"
        size_mb=$((size_bytes / 1048576))
        low=$(( expected_size_mb * 7 / 10 ))
        high=$(( expected_size_mb * 3 / 2 ))
        if [ "$size_mb" -lt "$low" ] || [ "$size_mb" -gt "$high" ]; then
            echo "  ✗ Size check failed: ${size_mb} MB (expected ~${expected_size_mb} MB, allowed ${low}-${high})" >&2
            return 1
        fi
    fi
    return 0
}

# ── Internal: download with resume ────────────────────────────────────────────

_agent_download() {
    local url="$1"
    local dest="$2"
    local label="$3"

    echo "  Downloading $label ..."
    echo "    → $dest"

    if command -v curl >/dev/null 2>&1; then
        curl -L -C - --progress-bar -o "$dest" "$url" || {
            echo "  ✗ curl failed downloading: $url" >&2
            return 1
        }
    elif command -v wget >/dev/null 2>&1; then
        wget -c -O "$dest" "$url" || {
            echo "  ✗ wget failed downloading: $url" >&2
            return 1
        }
    else
        echo "  ✗ Neither curl nor wget found. Install one and retry." >&2
        return 1
    fi
    echo "  ✓ Downloaded: $label"
}

# ── Public: agent_paths ────────────────────────────────────────────────────────

agent_paths() {
    # Print key=value pairs of well-known paths.
    # Usage: eval "$(agent_paths)" to import them as variables.
    local root cache bin_dir models_dir
    root="$(_agent_root)"
    cache="$(_agent_cache_dir)"
    bin_dir="$cache/bin"
    models_dir="$cache/models"
    primary_file="$(_cfg_read '.models.primary.file')"
    fallback_file="$(_cfg_read '.models.fallback.file')"

    printf 'AGENT_ROOT=%s\n'          "$root"
    printf 'AGENT_CACHE=%s\n'         "$cache"
    printf 'AGENT_BIN_DIR=%s\n'       "$bin_dir"
    printf 'AGENT_MODELS_DIR=%s\n'    "$models_dir"
    printf 'AGENT_ENGINE=%s\n'        "$bin_dir/llama-cli"
    printf 'AGENT_PRIMARY_MODEL=%s\n' "$models_dir/$primary_file"
    printf 'AGENT_FALLBACK_MODEL=%s\n' "$models_dir/$fallback_file"
}

# ── Public: agent_ready ────────────────────────────────────────────────────────

agent_ready() {
    # Returns 0 if engine binary + at least one model exist, else 1.
    local bin_dir models_dir
    bin_dir="$(_agent_cache_dir)/bin"
    models_dir="$(_agent_cache_dir)/models"
    local primary_file fallback_file
    primary_file="$(_cfg_read '.models.primary.file')"
    fallback_file="$(_cfg_read '.models.fallback.file')"

    [ -x "$bin_dir/llama-cli" ] || return 1
    { [ -f "$models_dir/$primary_file" ] || [ -f "$models_dir/$fallback_file" ]; } || return 1
    return 0
}

# ── Public: install_agent_engine ──────────────────────────────────────────────

install_agent_engine() {
    local use_fallback=0
    if [ "${1:-}" = "--fallback" ]; then
        use_fallback=1
    fi

    local root cache bin_dir models_dir
    root="$(_agent_root)"
    cache="$(_agent_cache_dir)"
    bin_dir="$cache/bin"
    models_dir="$cache/models"
    local cfg_file
    cfg_file="$(_agent_config_file)"

    if ! command -v jq >/dev/null 2>&1; then
        echo "dotfiles agent --setup: jq is required. Install it first:" >&2
        echo "  sudo apt install jq  OR  brew install jq" >&2
        return 1
    fi

    local plat_key
    plat_key="$(_agent_platform_key)"

    echo ""
    echo "=== dotfiles agent --setup ==="
    echo "  Platform : $plat_key"
    echo "  CacheDir : $cache"
    echo ""

    # Low-RAM advisory
    if command -v free >/dev/null 2>&1; then
        local ram_gb
        ram_gb="$(free -g 2>/dev/null | awk '/^Mem:/{print $2}')"
        if [ -n "$ram_gb" ] && [ "$ram_gb" -le 4 ] 2>/dev/null; then
            echo "  ⚠  Low RAM detected (~${ram_gb} GB). Consider --fallback for the 0.5B model."
        fi
    fi

    # Ensure directories
    mkdir -p "$bin_dir" "$models_dir"

    # ── Step 1: Engine binary ─────────────────────────────────────────────────
    local engine_bin="$bin_dir/llama-cli"
    local asset_name
    asset_name="$(jq -r --arg k "$plat_key" '.engine.assets[$k] // empty' "$cfg_file")"

    if [ -z "$asset_name" ] || [ "$asset_name" = "null" ]; then
        echo "  ✗ No engine asset for platform '$plat_key' in agent-config.json" >&2
        return 1
    fi

    local base_url engine_url archive_path engine_sha256
    base_url="$(jq -r '.engine.base_url' "$cfg_file")"
    engine_url="${base_url}${asset_name}"
    archive_path="$bin_dir/$asset_name"
    engine_sha256="$(jq -r --arg k "$plat_key" '.engine.sha256[$k] // "null"' "$cfg_file")"

    if [ -x "$engine_bin" ]; then
        echo "  ✓ Engine already present: $engine_bin"
    else
        # Download archive (skip if already on disk — resume support)
        if [ ! -f "$archive_path" ]; then
            _agent_download "$engine_url" "$archive_path" "engine ($asset_name)" || return 1
        else
            echo "  ↩ Resuming archive: $asset_name"
            _agent_download "$engine_url" "$archive_path" "engine ($asset_name)" || return 1
        fi

        # Extract
        echo "  Extracting $asset_name ..."
        case "$asset_name" in
            *.tar.gz)
                tar -xzf "$archive_path" -C "$bin_dir" || {
                    echo "  ✗ tar extraction failed" >&2; return 1
                }
                ;;
            *.zip)
                if command -v unzip >/dev/null 2>&1; then
                    unzip -o "$archive_path" -d "$bin_dir" >/dev/null || {
                        echo "  ✗ unzip failed" >&2; return 1
                    }
                else
                    echo "  ✗ unzip not found; cannot extract .zip" >&2; return 1
                fi
                ;;
            *)
                echo "  ✗ Unknown archive format: $asset_name" >&2; return 1
                ;;
        esac

        # chmod +x the binary
        if [ -f "$engine_bin" ]; then
            chmod +x "$engine_bin"
        else
            # llama-cli may be inside a subdirectory from the tar
            local found_bin
            found_bin="$(find "$bin_dir" -name 'llama-cli' -type f 2>/dev/null | head -1)"
            if [ -n "$found_bin" ]; then
                chmod +x "$found_bin"
                # Move to expected location if needed
                [ "$found_bin" = "$engine_bin" ] || mv "$found_bin" "$engine_bin"
            else
                echo "  ✗ llama-cli binary not found after extraction" >&2; return 1
            fi
        fi

        # Clean up archive
        rm -f "$archive_path"
        echo "  ✓ Engine extracted: $engine_bin"
    fi

    # Verify engine runs
    echo "  Verifying engine ..."
    local ver
    ver="$("$engine_bin" --version 2>&1)" || {
        echo "  ✗ llama-cli --version failed" >&2; return 1
    }
    echo "  ✓ $ver"

    # ── Step 2: Model ──────────────────────────────────────────────────────────
    local model_file model_url model_sha256 model_size_mb model_path model_label
    if [ "$use_fallback" -eq 1 ]; then
        model_file="$(jq -r '.models.fallback.file'    "$cfg_file")"
        model_url="$(jq  -r '.models.fallback.url'     "$cfg_file")"
        model_sha256="$(jq -r '.models.fallback.sha256 // "null"' "$cfg_file")"
        model_size_mb="$(jq -r '.models.fallback.size_mb' "$cfg_file")"
        model_label="fallback (0.5B)"
    else
        model_file="$(jq -r '.models.primary.file'     "$cfg_file")"
        model_url="$(jq  -r '.models.primary.url'      "$cfg_file")"
        model_sha256="$(jq -r '.models.primary.sha256 // "null"' "$cfg_file")"
        model_size_mb="$(jq -r '.models.primary.size_mb' "$cfg_file")"
        model_label="primary (1.5B)"
    fi
    model_path="$models_dir/$model_file"

    if _check_integrity "$model_path" "$model_sha256" "$model_size_mb"; then
        echo "  ✓ Model already present and valid: $model_path"
    else
        [ -f "$model_path" ] && echo "  ↩ Partial/invalid model found; re-downloading ..."
        _agent_download "$model_url" "$model_path" "$model_label (~${model_size_mb} MB)" || return 1
        if ! _check_integrity "$model_path" "$model_sha256" "$model_size_mb"; then
            echo "  ✗ Model integrity check failed: $model_path" >&2; return 1
        fi
        echo "  ✓ Model ready: $model_path"
    fi

    echo ""
    echo "=== Setup complete ==="
    echo "  Engine : $engine_bin"
    echo "  Model  : $model_path"
    echo ""
    echo "  Run inference (Phase 4): dotfiles agent \"<your query>\""
}

# ── PHASE 4: dotfiles_agent — natural-language → shell command inference ──────
# Owner  : Tank
# Phase  : 4 (Inference)
# Requires: jq, timeout, awk, sed

# ── Internal: assemble grounded SYSTEM prompt ─────────────────────────────────

_agent_build_prompt() {
    # Outputs the SYSTEM prompt (template + tools + aliases + few-shot) to stdout.
    # No ChatML, no user query: llama-cli b9469 is conversation-only, so the
    # query is passed separately via -p and this text goes to -sysf. The model's
    # own chat template wraps both. Mirrors the PowerShell _Build-AgentPrompt.
    local root
    root="$(_agent_root)"

    # Detect shell (zsh vs bash) for {{SHELL_TYPE}} substitution
    local shell_type="unix-bash"
    [ -n "${ZSH_VERSION:-}" ] && shell_type="unix-zsh"

    local sys_prompt_path="$root/shared/agent/system-prompt.txt"
    local tools_json="$root/shared/tools.json"
    local aliases_json="$root/shared/aliases.json"
    local few_shot_path="$root/shared/agent/few-shot.json"

    # Fail loudly if the grounding template is missing — otherwise inference
    # would run ungrounded with only the EXAMPLES block.
    if [ ! -f "$sys_prompt_path" ]; then
        echo "dotfiles agent: system prompt not found: $sys_prompt_path" >&2
        return 1
    fi

    # ── Tools block: "- {name}: {description}" per tool, or "(none registered)" ─
    local tools_block=""
    if [ -f "$tools_json" ]; then
        tools_block="$(jq -r \
            'if (.tools | length) > 0 then
               [.tools[] | "- " + .name + ": " + (.description // "")] | join("\n")
             else "(none registered)" end' \
            "$tools_json" 2>/dev/null)"
    fi
    : "${tools_block:=(none registered)}"

    # ── Aliases block: skip _-prefixed keys; omit absent win/unix brackets ────
    local aliases_block=""
    if [ -f "$aliases_json" ]; then
        aliases_block="$(jq -r \
            '[.aliases | to_entries[] |
              select(.key | startswith("_") | not) |
              "- " + .key + ": " + (.value._note // "") +
              (if .value.windows then " [win: " + .value.windows + "]" else "" end) +
              (if .value.unix    then " [unix: " + .value.unix    + "]" else "" end)
             ] | join("\n")' \
            "$aliases_json" 2>/dev/null)"
    fi
    : "${aliases_block:=(none registered)}"

    # ── Fill system prompt template ───────────────────────────────────────────
    # sed handles the inline {{SHELL_TYPE}} replacement (simple scalar value).
    # awk handles {{TOOLS_BLOCK}} / {{ALIASES_BLOCK}} via ENVIRON so multi-line
    # block values survive without the line-count limit of awk -v.
    local filled_sys
    filled_sys="$(
        export _ADFT_TOOLS="$tools_block"
        export _ADFT_ALIASES="$aliases_block"
        sed "s/{{SHELL_TYPE}}/$shell_type/g" "$sys_prompt_path" | \
        awk '
            $0 == "{{TOOLS_BLOCK}}"   { print ENVIRON["_ADFT_TOOLS"];   next }
            $0 == "{{ALIASES_BLOCK}}" { print ENVIRON["_ADFT_ALIASES"]; next }
            { print }
        '
    )"

    # $() strips trailing newlines → clean separation before EXAMPLES block.
    printf '%s' "$filled_sys"

    # ── Few-shot examples as plain text: "{user} => {assistant}" per pair ──────
    if [ -f "$few_shot_path" ]; then
        local examples
        examples="$(jq -r '
            [ range(0; (length/2) | floor) as $i
              | { u: .[$i*2], a: .[$i*2+1] }
              | select(.u.role == "user" and .a.role == "assistant")
              | .u.content + " => " + .a.content
            ] | join("\n")' "$few_shot_path" 2>/dev/null)"
        if [ -n "$examples" ]; then
            printf '\n\nEXAMPLES:\n%s' "$examples"
        fi
    fi
}

# ── Internal: post-process raw llama-cli (conversation mode) stdout ───────────

_agent_postprocess() {
    # Conversation single-turn prints a banner, then the echoed user turn as a
    # "> <query>" line, then the reply, then "[ Prompt: ...]"/"[ Generation: ...]"
    # and "Exiting...". Locate the echoed query line (exact "> <query>", falling
    # back to the last "> " line), extract text AFTER it and BEFORE those markers;
    # strip ``` fences; return the first non-empty line (stripped of a leading
    # "$ "/"> " marker and surrounding backticks). Mirrors PowerShell.
    # Usage: _agent_postprocess "<raw>" "<query>"
    printf '%s\n' "$1" | awk -v q="$2" '
        { lines[NR] = $0 }
        END {
            start = 0
            # Prefer the exact echoed query line.
            for (i = 1; i <= NR; i++) {
                if (lines[i] == "> " q) start = i
            }
            # Fallback: last line beginning with "> ".
            if (start == 0) {
                for (i = 1; i <= NR; i++) {
                    if (lines[i] ~ /^> /) start = i
                }
            }
            for (i = start + 1; i <= NR; i++) {
                l = lines[i]
                if (l ~ /^\[ (Prompt|Generation):/ || l ~ /^Exiting/) break
                if (l ~ /^```/) continue
                sub(/^[[:space:]]+/, "", l)
                sub(/[[:space:]]+$/, "", l)
                if (length(l) == 0) continue
                if (substr(l,1,2) == "$ ") sub(/^\$ /, "", l)
                else if (substr(l,1,2) == "> ") sub(/^> /, "", l)
                gsub(/^`+|`+$/, "", l)
                print l
                exit
            }
        }
    '
}

# ── Public: dotfiles_agent ────────────────────────────────────────────────────

dotfiles_agent() {
    # Usage: dotfiles_agent "<query>" [--run]
    # Exit codes: 0=ok  1=no-cmd/cannot-build  2=no-engine  3=no-model  4=timeout
    local query="${1:-}"
    local do_run=0
    [ "${2:-}" = "--run" ] && do_run=1

    if [ -z "$query" ]; then
        printf 'Usage: dotfiles agent "<query>" [--run]\n' >&2
        return 1
    fi

    if ! command -v jq >/dev/null 2>&1; then
        echo "dotfiles agent: jq is required for inference. Install: sudo apt install jq" >&2
        return 1
    fi

    # ── Resolve well-known paths ──────────────────────────────────────────────
    local AGENT_ROOT AGENT_CACHE AGENT_BIN_DIR AGENT_MODELS_DIR
    local AGENT_ENGINE AGENT_PRIMARY_MODEL AGENT_FALLBACK_MODEL
    eval "$(agent_paths)"

    # ── Engine presence check (exit 2 = engine missing) ───────────────────────
    if [ ! -x "$AGENT_ENGINE" ]; then
        echo "Agent engine not installed. Run: dotfiles agent --setup" >&2
        return 2
    fi

    # ── Model resolution: env > primary > fallback (exit 3 = no model) ────────
    local model_path=""
    if [ -n "${DOTFILES_AGENT_MODEL:-}" ]; then
        model_path="$DOTFILES_AGENT_MODEL"
    elif [ -f "$AGENT_PRIMARY_MODEL" ]; then
        model_path="$AGENT_PRIMARY_MODEL"
    elif [ -f "$AGENT_FALLBACK_MODEL" ]; then
        model_path="$AGENT_FALLBACK_MODEL"
    fi

    if [ -z "$model_path" ] || [ ! -f "$model_path" ]; then
        echo "No model found. Run: dotfiles agent --setup" >&2
        return 3
    fi

    # ── Config (env DOTFILES_AGENT_TIMEOUT overrides config file) ─────────────
    local n_predict temp timeout_sec
    n_predict="$(_cfg_read '.defaults.n_predict' 2>/dev/null)"
    temp="$(_cfg_read '.defaults.temp' 2>/dev/null)"
    timeout_sec="$(_cfg_read '.defaults.timeout_seconds' 2>/dev/null)"
    [ -n "${DOTFILES_AGENT_TIMEOUT:-}" ] && timeout_sec="$DOTFILES_AGENT_TIMEOUT"
    : "${n_predict:=80}" "${temp:=0}" "${timeout_sec:=60}"

    # ── Resolve timeout binary (GNU timeout, or gtimeout on macOS/brew) ───────
    local timeout_bin=""
    if command -v timeout >/dev/null 2>&1; then
        timeout_bin="timeout"
    elif command -v gtimeout >/dev/null 2>&1; then
        timeout_bin="gtimeout"
    fi

    # ── Write SYSTEM prompt to temp file (UTF-8, no BOM) ──────────────────────
    local prompt_file
    prompt_file="$(mktemp "${TMPDIR:-/tmp}/dotfiles-agent-XXXXXX.txt")" || {
        echo "dotfiles agent: failed to create temp file" >&2
        return 1
    }
    # Clean up the temp file on interrupt/termination too (sourced-function-safe:
    # the handler clears itself so it never lingers in the interactive shell).
    trap 'rm -f "$prompt_file"; trap - INT TERM HUP; return 130' INT TERM HUP

    if ! _agent_build_prompt > "$prompt_file" 2>/dev/null; then
        rm -f "$prompt_file"; trap - INT TERM HUP
        echo "dotfiles agent: failed to build prompt" >&2
        return 1
    fi

    # ── Invoke llama-cli: conversation single-turn, timeout-wrapped ───────────
    # b9469 is conversation-only; -no-cnv is rejected. The grounding+few-shot is
    # the system prompt (-sysf); the live query is the user turn (-p); -st exits
    # after one reply. Mirrors the PowerShell recipe.
    local raw_output engine_rc
    if [ -n "$timeout_bin" ]; then
        raw_output="$("$timeout_bin" "${timeout_sec}s" "$AGENT_ENGINE" \
            -m "$model_path" \
            -sysf "$prompt_file" \
            -p "$query" \
            -st \
            --simple-io \
            --no-display-prompt \
            -n "$n_predict" \
            --temp "$temp" \
            2>/dev/null)"
        engine_rc=$?
    else
        echo "dotfiles agent: 'timeout' not found; running without a time limit (Ctrl-C to abort)." >&2
        raw_output="$("$AGENT_ENGINE" \
            -m "$model_path" \
            -sysf "$prompt_file" \
            -p "$query" \
            -st \
            --simple-io \
            --no-display-prompt \
            -n "$n_predict" \
            --temp "$temp" \
            2>/dev/null)"
        engine_rc=$?
    fi

    rm -f "$prompt_file"; trap - INT TERM HUP

    # timeout(1) exits 124 on expiry → map to exit code 4
    if [ "$engine_rc" -eq 124 ]; then
        echo "Request timed out after ${timeout_sec}s. Consider --setup --fallback for a smaller/faster model." >&2
        return 4
    fi

    # ── Post-process: strip fences, trim, first non-empty line ───────────────
    local cmd
    cmd="$(_agent_postprocess "$raw_output" "$query")"

    if [ -z "$cmd" ]; then
        echo "No command generated. Try rephrasing your query." >&2
        return 1
    fi

    # "# Cannot build:" → print and exit 1
    case "$cmd" in
        '# Cannot build:'*)
            printf '%s\n' "$cmd"
            return 1
            ;;
    esac

    # ── Show generated command ────────────────────────────────────────────────
    printf '%s\n' "$cmd"

    # ── Best-effort clipboard (WSL: clip.exe | X11: xclip | Wayland: wl-copy) -
    if command -v clip.exe >/dev/null 2>&1; then
        printf '%s' "$cmd" | clip.exe 2>/dev/null || true
    elif command -v xclip >/dev/null 2>&1; then
        printf '%s' "$cmd" | xclip -selection clipboard 2>/dev/null || true
    elif command -v wl-copy >/dev/null 2>&1; then
        printf '%s' "$cmd" | wl-copy 2>/dev/null || true
    fi

    # ── Optional interactive run ──────────────────────────────────────────────
    if [ "$do_run" -eq 1 ]; then
        printf 'Execute? [y/N] '
        read -r ans
        case "$ans" in
            y|Y) eval "$cmd" ;;
        esac
    fi

    return 0
}
# ─────────────────────────────────────────────────────────────────────────────
