# Local AI Agent for dotfiles CLI — Architecture Plan

**Author:** Morpheus (Lead / Architect)  
**Date:** 2026-06-02  
**Status:** REVISED (v2) — self-contained design per Jose's directive  
**Requested by:** Jose (jmanuelcorral)  
**Supersedes:** Decisions #7 (Ollama + Phi-4-mini) and #8 (original 6-phase plan)

---

## 1. Summary & Goals

Add two new subcommands to the `dotfiles` CLI:

| Subcommand | Purpose |
|------------|---------|
| `dotfiles agent "<request>"` | Generate a single shell command from natural language, grounded in the user's registered tools/aliases. **Show, don't run** — print command + optional confirm-to-execute. |
| `dotfiles explain <cmd-or-alias>` | Show example invocations of a command. **Offline-first** (registry lookup); only fall back to AI for unknown input. |

### Goals

- **Self-contained:** One-shot subprocess per call — NO daemon, NO server, NO open port
- **Offline-first:** `explain` must work with no model installed (pure JSON lookup)
- **Portable:** Identical invocation from PowerShell and bash/WSL (same flags, same paths)
- **Safe:** Commands printed by default; optional `--run` flag or y/N confirmation to execute
- **Optional AI:** Feature degrades gracefully; model is enhancement, not dependency
- **No bloat in git:** Binary + model live in `$env:DOTFILES\cache\` (gitignored)

### Non-Goals

- Remote/cloud API fallback (strictly local)
- Streaming/interactive chat (single-shot command generation only)
- Background daemon or server process (explicitly rejected per Jose)

---

## 2. Chosen Approach — Self-Contained llama-cli Design

### Endorsing Oracle's Revised Recommendation: **llama-cli + Qwen2.5-Coder-1.5B**

| Criterion | Decision |
|-----------|----------|
| **Engine** | `llama-cli` prebuilt CPU-only binary from `ggml-org/llama.cpp` GitHub Releases |
| **Binary size** | ~9 MB compressed / ~15 MB extracted (Win: exe + ggml.dll + llama.dll) |
| **Primary model** | `Qwen2.5-Coder-1.5B-Instruct Q4_K_M` (~986 MB, Apache 2.0) |
| **Fallback model** | `Qwen2.5-Coder-0.5B-Instruct Q4_K_M` (~572 MB) for ≤4 GB RAM |
| **Model override** | `$env:DOTFILES_AGENT_MODEL` → path to any GGUF file |
| **Invocation** | One-shot subprocess, exits after output — NO warm state, NO daemon |
| **Cold start** | ~5–8 s (1.5B) / ~3–5 s (0.5B) per call on modern CPU |

### Why llama-cli over alternatives?

| Backend | Daemon-free | Install | Cross-platform | Python | Verdict |
|---------|-------------|---------|----------------|--------|---------|
| **llama-cli** | ✅ One-shot | Low (download+unzip) | ✅ Win + WSL | No | **Primary** |
| Ollama | ❌ Server required | Low | ✅ | No | **Rejected by Jose** |
| llamafile | ✅ One-shot | Low | ✅ | No | Less flexible (bundled model) |
| ONNX GenAI | ✅ One-shot | Medium (pip) | ✅ | Yes | Adds Python dep |

### One-shot invocation — identical from both shells

```
                    ┌─────────────────────────────────────────┐
                    │  llama-cli (one-shot subprocess)        │
                    │  Exits after printing output — no port  │
                    └────────────────┬────────────────────────┘
                                     │ stdout
            ┌────────────────────────┼────────────────────────┐
            │                        │                        │
   ┌────────▼────────┐      ┌────────▼────────┐      ┌───────▼───────┐
   │ PowerShell      │      │ bash (WSL)      │      │ zsh (WSL)     │
   │ & llama-cli ... │      │ ./llama-cli ... │      │ ./llama-cli   │
   └─────────────────┘      └─────────────────┘      └───────────────┘
```

**Invocation flags (OS-agnostic):**
```
llama-cli -m <model.gguf> --no-display-prompt --single-turn --log-disable -n 80 --temp 0 -p "<prompt>"
```

Only shell quoting differs. No HTTP, no REST, no port.

---

## 3. CLI Surface / Contract

### Existing param model (`bin\dotfiles.ps1`)

```powershell
param(
    [Parameter(Position = 0)] [string]$Command = 'help',
    [Parameter(Position = 1)] [string]$Arg1    = '',
    [string]$Description = ''
)
```

### New subcommands

| Subcommand | Syntax | Output | Flags |
|------------|--------|--------|-------|
| `agent` | `dotfiles agent "<natural language>"` | Single command line | `--run` to execute after confirm |
| `agent --setup` | `dotfiles agent --setup` | Download engine + model | `--fallback` for 0.5B model |
| `explain` | `dotfiles explain <alias-or-tool>` | Registry lookup + examples | (none) |

### Existing subcommands (unchanged)

`help`, `list`, `register`, `update`, `edit` — no changes required.

### Exit codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Usage error / unknown subcommand |
| 2 | Engine not available (run `dotfiles agent --setup`) |
| 3 | Model not available / download failed |
| 4 | Subprocess timeout (>60 s) |

### Output format — Show, Don't Run (default UX)

**`agent` default behavior:**
1. Build grounded prompt from `tools.json` + `aliases.json` + user query
2. Invoke `llama-cli` subprocess, capture stdout
3. Post-process: strip markdown fences, trim, extract first command line
4. Print the command to stdout (ready to copy)
5. If `--run` flag: prompt `Execute? [y/N]` → on `y`, execute via shell

**Example session:**
```
$ dotfiles agent "find all python files larger than 1MB"
fd -e py --size +1M

$ dotfiles agent "find all python files" --run
fd -e py
Execute? [y/N] y
(executes the command)
```

**`explain` behavior:**
- Print alias definition + examples from `aliases.json` / `tools.json`
- If not found in registry, fall back to `<command> --help | head -20`
- Model is NOT invoked for `explain` — fully offline by design

### Bash/zsh parity

The `dotfiles` shell function in `shell/common.sh` handles `help`, `list`, `update`, `edit`. We add `agent` and `explain` cases with identical logic.

---

## 4. Module / File Layout

```
dotfiles/
├── bin/
│   ├── dotfiles.ps1            # existing — add switch cases for agent/explain
│   └── (no new scripts here)
│
├── shared/
│   ├── tools.json              # existing registry
│   ├── aliases.json            # existing alias catalog
│   ├── agent-config.json       # NEW — model/engine config (see §8)
│   └── agent/                  # NEW — shared assets for both shells
│       ├── system-prompt.txt   # system prompt template (shell-agnostic)
│       └── few-shot.json       # few-shot examples: [{user, assistant}, ...]
│
├── powershell/
│   └── modules/
│       └── dotfiles-agent.psm1 # NEW — Invoke-Agent, Invoke-Explain, Install-AgentEngine
│
├── shell/
│   └── lib/
│       └── agent.sh            # NEW — agent/explain/setup implementation for bash/zsh
│
├── cache/                      # NEW — gitignored, NOT in repo
│   ├── bin/
│   │   ├── llama-cli.exe       # Windows binary
│   │   ├── ggml.dll            # Windows DLL
│   │   ├── llama.dll           # Windows DLL
│   │   └── llama-cli           # Linux binary (chmod +x)
│   └── models/
│       ├── qwen25coder-1.5b-q4_k_m.gguf   # primary (~986 MB)
│       └── qwen25coder-0.5b-q4_k_m.gguf   # fallback (~572 MB)
│
└── .gitignore                  # Add: cache/
```

### Why this layout?

1. **One source of truth:** `shared/agent/system-prompt.txt` and `few-shot.json` consumed by both shells — no drift.
2. **Shell-specific wrappers:** `dotfiles-agent.psm1` (PowerShell) and `agent.sh` (bash) handle subprocess invocation differently but share the prompt template.
3. **Existing conventions respected:** PowerShell modules in `powershell/modules/`; shell libs in `shell/lib/`.
4. **Cache outside git:** `cache/` is gitignored. Binary + model downloaded on first use, never committed.

---

## 5. Context-Injection & Prompt Design

### What gets injected

1. **tools.json → tools[]** — name, description, path
2. **aliases.json → aliases{}** — alias name, note, windows/unix commands
3. **Shell context** — `windows-powershell` or `unix-bash` / `unix-zsh`

### Prompt template structure (`shared/agent/system-prompt.txt`)

```
You are a shell command assistant for a developer's dotfiles environment.
You ONLY build commands from the tools and aliases listed below.
Never invent flags or tools not in this list.
Respond with a SINGLE shell command, no explanation, no markdown, no trailing newline.
If the request cannot be satisfied, respond with: # Cannot build: <reason>

SHELL: {{SHELL_TYPE}}

REGISTERED TOOLS:
{{TOOLS_BLOCK}}

REGISTERED ALIASES:
{{ALIASES_BLOCK}}
```

### Few-shot examples (`shared/agent/few-shot.json`)

```json
[
  {"role": "user", "content": "list files sorted by size"},
  {"role": "assistant", "content": "eza -la --sort=size --icons"},
  {"role": "user", "content": "find all Python files"},
  {"role": "assistant", "content": "fd -e py"},
  {"role": "user", "content": "show git log with graph"},
  {"role": "assistant", "content": "gl"}
]
```

### Prompt assembly — single shared contract

Both PowerShell and bash must build the prompt identically:

1. Read `system-prompt.txt`
2. Replace `{{SHELL_TYPE}}` with current shell (e.g., `windows-powershell`)
3. Replace `{{TOOLS_BLOCK}}` with serialized `tools.json` (one line per tool: `name: description`)
4. Replace `{{ALIASES_BLOCK}}` with serialized `aliases.json` (one line per alias)
5. Append few-shot examples as plain text under an `EXAMPLES:` header, one
   `user => assistant` line per pair from `few-shot.json`

The assembled text is the **system prompt** only. It is written to a temp file
and passed via `-sysf`; the live user query is passed separately via `-p`.

**Invocation recipe (b9469 — conversation single-turn mode):**

> llama-cli b9469 split the binaries: raw one-shot completion (`-no-cnv`) is
> rejected ("please use llama-completion instead"), and `llama-completion`
> needs a real console (exits 130 under a redirected subprocess). The working
> path is therefore **llama-cli in single-turn conversation mode**.

```
llama-cli -m <model> -sysf <system-prompt-file> -p "<user query>" \
          -st --simple-io --no-display-prompt -n 80 --temp 0
```

- The model's own chat template wraps the `-sysf` system prompt and the `-p`
  user turn — we do NOT emit raw `<|im_start|>` ChatML ourselves.
- PowerShell invokes via `System.Diagnostics.Process` with each arg added to
  `ArgumentList` (so the multi-word `-p` value is never re-split) and
  `CreateNoWindow = $false` (conversation mode needs to share a console).
- bash invokes via `timeout <sec>s llama-cli ...` directly.

### Output guardrails (llama-cli flags)

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| `--temp 0` | 0 | Deterministic, no creative hallucination |
| `-n 80` | 80 | Single command never needs more tokens |
| `--no-display-prompt` | - | Don't echo the input prompt |
| `-st` | - | Single-turn: exit after the first reply |
| `--simple-io` | - | Basic IO for subprocess compatibility |

### Post-processing

llama-cli conversation mode prints a banner, the echoed user turn as a `> <query>`
line, the reply, then `[ Prompt: ...]` / `[ Generation: ...]` stats and `Exiting...`.

1. Take the text AFTER the last `> ` line and BEFORE the stats/`Exiting` markers
2. Strip markdown fence markers (` ```bash `, ` ``` `) but keep their content
3. Strip leading `$ ` or `> ` prompt characters and surrounding backticks
4. Trim whitespace; take the first non-empty line as the command
5. If the result starts with `# Cannot build`, treat it as a refusal (exit 1)

---

## 6. `explain` Offline-First Design

### Precedence order (no model involved)

```
dotfiles explain ll
```

**Logic:**

1. Look up `ll` in `aliases.json` → found?
   - Yes: Print alias definition + note + windows/unix commands
2. If not in aliases, look in `tools.json` by name → found?
   - Yes: Print description + path
3. If not found anywhere, fall back to `<command> --help 2>&1 | head -20`
4. **Never invoke the model** — `explain` is 100% offline

### Example output

```
$ dotfiles explain ll

  ll — Long listing with hidden files

  Windows (PowerShell):
    eza -la --icons --group-directories-first | Get-ChildItem -Force

  Unix (bash/zsh):
    eza -la --icons --group-directories-first | ls -la
```

### Graceful degradation for unknown commands

If the command is not in `aliases.json` or `tools.json`, attempt:
```
<command> --help 2>&1 | head -20
```

This provides basic help without requiring the model.

---

## 7. Engine + Model Management (First-Run Bootstrap)

### Setup trigger

Engine + model are NOT downloaded during `bootstrap/install.ps1` or `install.sh`. Download happens:

1. **Explicitly:** `dotfiles agent --setup` (recommended)
2. **Lazily:** First call to `dotfiles agent "<query>"` if engine/model missing (with user prompt)

### Setup script logic (`Install-AgentEngine` / `install_agent_engine()`)

```
1. Detect OS + arch
   - PowerShell: $env:PROCESSOR_ARCHITECTURE (AMD64/ARM64)
   - bash: uname -m (x86_64/aarch64)

2. Determine download URLs (pinned versions)
   - Engine: https://github.com/ggml-org/llama.cpp/releases/download/b{BUILD}/llama-{BUILD}-bin-{OS}-{ARCH}.{EXT}
   - Model: https://huggingface.co/Qwen/Qwen2.5-Coder-1.5B-Instruct-GGUF/resolve/main/qwen2.5-coder-1.5b-instruct-q4_k_m.gguf

3. Download engine archive
   - PowerShell: Invoke-WebRequest with progress, or curl.exe for resume
   - bash: curl -L -C - (resumable)

4. Verify SHA256 checksum before extracting
   - Fail with clear error if checksum mismatch

5. Extract to $DOTFILES/cache/bin/
   - Windows: Expand-Archive (ZIP)
   - Linux: tar -xzf

6. Platform-specific post-download
   - Windows: Unblock-File on all extracted files (removes Zone.Identifier)
   - Linux: chmod +x llama-cli

7. Download model to $DOTFILES/cache/models/
   - Same resumable download + SHA256 verification

8. Verify setup
   - Run: llama-cli --version
   - Print success + model path
```

### Cache layout

```
$env:DOTFILES/cache/
  bin/
    llama-cli.exe       # Windows
    ggml.dll            # Windows (required)
    llama.dll           # Windows (required)
    llama-cli           # Linux
  models/
    qwen25coder-1.5b-q4_k_m.gguf   # primary (~986 MB)
    qwen25coder-0.5b-q4_k_m.gguf   # fallback (~572 MB, optional)
```

### Version pinning (in `shared/agent-config.json`)

```json
{
  "engine": {
    "version": "b9196",
    "sha256": {
      "win-x64": "abc123...",
      "win-arm64": "def456...",
      "linux-x64": "789ghi...",
      "linux-arm64": "jkl012..."
    }
  },
  "models": {
    "primary": {
      "name": "qwen25coder-1.5b-q4_k_m",
      "url": "https://huggingface.co/Qwen/Qwen2.5-Coder-1.5B-Instruct-GGUF/resolve/main/qwen2.5-coder-1.5b-instruct-q4_k_m.gguf",
      "sha256": "mno345...",
      "size_mb": 986
    },
    "fallback": {
      "name": "qwen25coder-0.5b-q4_k_m",
      "url": "https://huggingface.co/Qwen/Qwen2.5-Coder-0.5B-Instruct-GGUF/resolve/main/qwen2.5-coder-0.5b-instruct-q4_k_m.gguf",
      "sha256": "pqr678...",
      "size_mb": 572
    }
  },
  "defaults": {
    "model": "primary",
    "n_predict": 80,
    "temp": 0,
    "timeout_seconds": 60
  }
}
```

### Windows-specific notes

- **SmartScreen:** Downloaded unsigned `.exe` gets `Zone.Identifier = 3`. `Unblock-File` removes this mark.
- **Execution Policy:** Does NOT apply to `.exe` files — only to PowerShell scripts.
- **DLLs:** `ggml.dll` and `llama.dll` must be in the same directory as `llama-cli.exe`.

### Linux-specific notes

- **chmod +x:** Required after download.
- **libc:** Prebuilt binaries target glibc (Ubuntu). Should work on WSL2 + most desktop distros.

### What goes in git

| Item | In git? |
|------|---------|
| `shared/agent/system-prompt.txt` | ✅ Yes (~1 KB) |
| `shared/agent/few-shot.json` | ✅ Yes (~1 KB) |
| `shared/agent-config.json` | ✅ Yes (~1 KB) — version pins, NOT secrets |
| `cache/` directory | ❌ Never (.gitignore) |
| Model files (*.gguf) | ❌ Never |
| Engine binary | ❌ Never |

---

## 8. Graceful Degradation Matrix

| Scenario | `dotfiles agent "<query>"` | `dotfiles explain <cmd>` |
|----------|---------------------------|-------------------------|
| **(a) Engine not downloaded** | Exit 2: "Agent engine not installed. Run: `dotfiles agent --setup`" | ✅ Full offline output (no model needed) |
| **(b) Model not downloaded** | Exit 3: "Model not available. Run: `dotfiles agent --setup`" | ✅ Full offline output |
| **(c) Download in progress** | Print progress bar, wait for completion | ✅ Offline output |
| **(d) Subprocess times out (>60s)** | Exit 4: "Request timed out. Try the 0.5B model: `dotfiles agent --setup --fallback`" | ✅ Offline output |
| **(e) Low RAM detected (≤4 GB)** | Suggest fallback: "Consider: `dotfiles agent --setup --fallback` for the 0.5B model" | ✅ Offline output |
| **(f) Everything working** | ✅ Prints generated command | ✅ Offline output from registry |

### Low-RAM detection

On first `agent` call or `--setup`, check available RAM:
- PowerShell: `(Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB`
- bash: `free -g | awk '/^Mem:/{print $2}'`

If ≤4 GB, print suggestion to use `--fallback` (0.5B model) but don't force it.

### Timeout handling

Wrap subprocess call with timeout:
- PowerShell: `Start-Process` with `-Wait` + timer check, or `[System.Diagnostics.Process]` with timeout
- bash: `timeout 60s llama-cli ...`

Default timeout: 60 seconds (configurable in `agent-config.json`).

---

## 9. Configuration

### Config file: `shared/agent-config.json`

Already shown in §7. Key user-configurable options:

| Key | Default | Description |
|-----|---------|-------------|
| `defaults.model` | `"primary"` | Which model to use: `"primary"` (1.5B) or `"fallback"` (0.5B) |
| `defaults.n_predict` | `80` | Max output tokens |
| `defaults.temp` | `0` | Temperature (0 = deterministic) |
| `defaults.timeout_seconds` | `60` | Subprocess timeout |

### Environment variable overrides

| Variable | Purpose |
|----------|---------|
| `DOTFILES_AGENT_MODEL` | Path to a custom GGUF model file |
| `DOTFILES_AGENT_TIMEOUT` | Override subprocess timeout (seconds) |
| `DOTFILES_CACHE` | Override cache directory (default: `$DOTFILES/cache`) |

### Sane defaults (no config needed for basic use)

Out of the box:
- Primary model (1.5B) downloaded on `--setup`
- 60-second timeout
- Temperature 0 (deterministic)
- 80 max tokens
- Show-don't-run UX

---

## 10. Phased Implementation Plan

### Phase 1: Shared Assets + Offline `explain` + Config
**Owner:** Switch  
**Deliverables:**
- Create `shared/agent/` directory structure
- Write `system-prompt.txt` and `few-shot.json`
- Create `shared/agent-config.json` with pinned versions (engine + models)
- Add `cache/` to `.gitignore`
- Implement offline `explain` in `dotfiles.ps1` (read aliases.json/tools.json)
- Implement offline `explain` in `shell/common.sh`
- Add `explain` to `dotfiles help` output

**Test/verification:**
- `dotfiles explain ll` returns alias info (no model needed)
- `dotfiles explain gituseswitch` returns tool info from tools.json
- `dotfiles explain unknowncmd` falls back to `--help`

**Dependencies:** None  
**Estimated effort:** 2–3 hours

---

### Phase 2: First-Run Bootstrap (Engine + Model Downloader)
**Owner:** Switch  
**Deliverables:**
- Implement `Install-AgentEngine` in `powershell/modules/dotfiles-agent.psm1`
- Implement `install_agent_engine()` in `shell/lib/agent.sh`
- OS/arch detection logic (Win x64/arm64, Linux x64/arm64)
- SHA256 checksum verification for all downloads
- Windows: `Unblock-File` for extracted files
- Linux: `chmod +x` for extracted binary
- `--fallback` flag to download 0.5B model instead of 1.5B
- Wire `dotfiles agent --setup` subcommand

**Test/verification:**
- `dotfiles agent --setup` downloads engine + model, verifies SHA256
- `llama-cli --version` runs without error after setup
- Low-RAM warning printed on ≤4 GB systems
- Re-running `--setup` is idempotent (skips if already present)

**Dependencies:** Phase 1  
**Estimated effort:** 4–5 hours

---

### Phase 3: PowerShell `agent` Subcommand
**Owner:** Trinity  
**Deliverables:**
- Implement `Invoke-Agent` function in `dotfiles-agent.psm1`
  - Builds prompt (system + tools + aliases + few-shot + user query)
  - Invokes `llama-cli` subprocess with timeout
  - Post-processes output (strip fences, trim, extract command)
- Wire `dotfiles agent "<query>"` into `dotfiles.ps1` dispatch
- Implement `--run` flag with y/N confirmation
- Graceful degradation (detect missing engine/model, suggest `--setup`)
- `$env:DOTFILES_AGENT_MODEL` / `$env:DOTFILES_AGENT_TIMEOUT` overrides

**Test/verification:**
- `dotfiles agent "list files by size"` returns valid command
- `dotfiles agent "unknown impossible request"` returns `# Cannot build: ...`
- Missing engine → exit 2 with setup instructions
- `dotfiles agent "find py files" --run` prompts for confirmation

**Dependencies:** Phase 2  
**Estimated effort:** 3–4 hours

---

### Phase 4: Bash/zsh `agent` Parity
**Owner:** Tank  
**Deliverables:**
- Implement `dotfiles_agent()` in `shell/lib/agent.sh`
- Same prompt-building logic as PowerShell (read same templates)
- Subprocess call with `timeout` wrapper
- Post-processing identical to PowerShell
- Wire into `common.sh` dispatch
- Match exit codes and error messages exactly

**Test/verification:**
- Same test cases as Phase 3, executed in bash/zsh
- Verify cold-start timing matches expected (~5–8 s for 1.5B)
- WSL2 can run the Linux binary from Windows dotfiles repo

**Dependencies:** Phase 2, Phase 3 (for contract verification)  
**Estimated effort:** 2–3 hours

---

### Phase 5: Documentation + DX Polish
**Owner:** Switch  
**Deliverables:**
- Update `docs/cheatsheet.md` with `agent` and `explain` commands
- Update `ARCHITECTURE.md` with agent module docs
- Add troubleshooting section (SmartScreen, permissions, timeout)
- README section: "Local AI Agent (optional)"

**Dependencies:** Phases 1–4  
**Estimated effort:** 1–2 hours

---

### Phase 6: Validation + Tuning
**Owner:** Oracle + Scribe  
**Deliverables:**
- Test 20+ real user queries, document success/failure
- Tune few-shot examples based on failure patterns
- Verify cold-start latency on reference hardware
- Document model swap procedure (using custom GGUF)
- Scribe: update decisions.md to mark #7/#8 superseded

**Dependencies:** Phases 1–5 complete  
**Estimated effort:** 2 hours

---

### Build Order Summary

```
Phase 1 (Switch)  ──────────────┐
                                │
Phase 2 (Switch)  ◀─────────────┘
        │
        ├──────────────────┐
        ▼                  ▼
Phase 3 (Trinity)    Phase 4 (Tank)
        │                  │
        └────────┬─────────┘
                 ▼
          Phase 5 (Switch)
                 │
                 ▼
          Phase 6 (Oracle + Scribe)
```

---

## 11. Superseded Decisions

The following decisions from `.squad/decisions.md` are **superseded** by this revised plan:

| Decision | Status | Reason |
|----------|--------|--------|
| **#7** — Ollama + Phi-4-mini | SUPERSEDED | Jose rejected Ollama (daemon requirement) |
| **#8** — 6-Phase implementation (Ollama-based) | SUPERSEDED | Architecture changed to self-contained llama-cli |

See: `docs/research/local-agent-2026.md` → "Self-Contained (No-Daemon) Options" section for full rationale.

---

## 12. Selected Defaults

Jose requested plan-before-build and may be unavailable. To keep the plan actionable, these defaults are **locked in** (Jose can override before implementation):

| Item | Selected Default | Rationale |
|------|------------------|-----------|
| Engine | `llama-cli` from `ggml-org/llama.cpp` | Tiny binary, no daemon, cross-platform |
| Engine version | Pin to tested build (e.g., `b9196`) | Reproducibility |
| Primary model | `Qwen2.5-Coder-1.5B-Instruct Q4_K_M` (~986 MB) | Best quality-to-speed ratio for CPU cold-start |
| Fallback model | `Qwen2.5-Coder-0.5B-Instruct Q4_K_M` (~572 MB) | For ≤4 GB RAM machines |
| UX | Show-don't-run (print + optional `--run` with confirm) | Safety first |
| Setup | Opt-in (`dotfiles agent --setup`), never auto-download | Don't surprise user with 1 GB download |
| `explain` | Fully offline (registry lookup only) | Works day 0, no model needed |
| Timeout | 60 seconds | Generous for cold-start; configurable |
| Temperature | 0 | Deterministic output |
| Max tokens | 80 | Single command never needs more |

---

## 13. Open Questions / Awaiting Approval

### Q1: Remote fallback (OpenAI/Azure)?

**Current default:** Strictly local (no remote).  
**Future option:** `$env:DOTFILES_AGENT_ENDPOINT` could point to any OpenAI-compatible API. Deferred.

### Q2: Model bundling in repo?

**Current default:** Never bundle. Models are 500 MB – 1 GB and don't belong in git.  
**Alternative:** Ship a llamafile with bundled model. Rejected for flexibility reasons.

### Q3: Confirm UX for `--run`?

**Current default:** `y/N` prompt after printing command.  
**Alternative:** Clipboard-copy + message "Paste to run" (no exec at all).

---

## Decision Summary

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Runtime | `llama-cli` (one-shot subprocess) | No daemon, cross-platform, tiny binary |
| Primary model | Qwen2.5-Coder-1.5B Q4_K_M | Apache 2.0, fast cold-start, code-specialized |
| Fallback model | Qwen2.5-Coder-0.5B Q4_K_M | For low-RAM machines |
| Setup | Opt-in via `--setup` | Don't surprise user with 1 GB download |
| Model pull | Lazy (on `--setup` or first `agent` call) | Don't block dotfiles install |
| `explain` default | Offline-first (registry only) | Works day 0, no model needed |
| Auto-execute | Never (show + optional confirm-to-run) | Safety first |

---

## Awaiting Approval

This plan requires Jose's sign-off before implementation begins. **No code has been written yet.**

**To approve:** Review the phased plan (§10) and selected defaults (§12). If acceptable, say "go" and Switch starts Phase 1.

**Next step after approval:** Switch begins Phase 1 (shared assets + offline `explain` + config).

---

*Authored by Morpheus (Lead / Architect) — Revised 2026-06-02 for self-contained design per Jose's directive.*
