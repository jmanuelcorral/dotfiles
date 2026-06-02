# Local AI Agent for dotfiles CLI — Architecture Plan

**Author:** Morpheus (Lead / Architect)  
**Date:** 2026-06-02  
**Status:** PROPOSED — awaiting Jose's approval  
**Requested by:** Jose (jmanuelcorral)

---

## 1. Summary & Goals

Add two new subcommands to the `dotfiles` CLI:

| Subcommand | Purpose |
|------------|---------|
| `dotfiles agent "<request>"` | Generate a single shell command from natural language, grounded in the user's registered tools/aliases. **Print only — never execute.** |
| `dotfiles explain <cmd-or-alias>` | Show example invocations of a command. **Offline-first** (registry lookup), optionally AI-enhanced. |

### Goals

- **Offline-first:** `explain` must work with no model installed (pure JSON lookup)
- **Portable:** Same model backend reachable from PowerShell and WSL bash
- **Safe:** Commands printed, never auto-executed; user copies and runs
- **Optional AI:** Feature degrades gracefully; Ollama is an enhancement, not a dependency
- **No bloat in git:** Models stored in Ollama's cache, not in-repo

### Non-Goals

- Remote/cloud API fallback (strictly local for now)
- Streaming/interactive chat (single-shot command generation only)
- Auto-execution of generated commands

---

## 2. Chosen Approach

### Endorsing Oracle's Recommendation: **Ollama + Phi-4-mini-instruct**

| Criterion | Decision |
|-----------|----------|
| **Runtime** | Ollama (`localhost:11434`) — single binary, manages model lifecycle, OpenAI-compatible REST API |
| **Primary model** | `phi4-mini` (3.8B params, ~2.3 GB, MIT license, 128K context, best instruction-following at 3B class) |
| **Fallback model** | `qwen2.5-coder:1.5b` (~1.0 GB, Apache 2.0) — for machines with ≤8 GB RAM |
| **Model override** | `$env:DOTFILES_AGENT_MODEL` / `$DOTFILES_AGENT_MODEL` |
| **Keep-warm** | Set `OLLAMA_KEEP_ALIVE=60m` in shell config |

### Why Ollama over alternatives?

| Backend | Install | Cross-platform | Python | Verdict |
|---------|---------|----------------|--------|---------|
| **Ollama** | Low (winget/curl) | ✅ Win + WSL | No | **Primary** |
| ONNX GenAI | Medium (pip) | ✅ | Yes | Specialist only |
| llama.cpp | Medium | ✅ | Optional | Fallback |
| Foundry Local | Low | ❌ Win only | No | Future |

### Same backend from both shells

```
                    ┌──────────────────────────────┐
                    │  Ollama server @ :11434      │
                    │  (runs on Windows or WSL)    │
                    └──────────┬───────────────────┘
                               │  REST API
            ┌──────────────────┼──────────────────┐
            │                  │                  │
   ┌────────▼────────┐  ┌──────▼──────┐  ┌───────▼───────┐
   │ PowerShell      │  │ bash (WSL)  │  │ zsh (WSL)     │
   │ Invoke-RestMethod│ │ curl + jq   │  │ curl + jq     │
   └─────────────────┘  └─────────────┘  └───────────────┘
```

**WSL2 network note:** WSL2 shares `localhost` with the Windows host since ~2024. Installing Ollama on Windows means both PowerShell and WSL can hit `localhost:11434` without configuration.

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

| Subcommand | Syntax | Output |
|------------|--------|--------|
| `agent` | `dotfiles agent "<natural language>"` | Single copy-pasteable command (or `# Cannot build: <reason>`) |
| `explain` | `dotfiles explain <alias-or-tool>` | Formatted examples from registry; optionally AI-enriched |

### Existing subcommands (unchanged)

`help`, `list`, `register`, `update`, `edit` — no changes required.

### Exit codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Usage error / unknown subcommand |
| 2 | Ollama unavailable (agent only) |
| 3 | Model not pulled / timeout |

### Output format

- **`agent`:** Prints ONE line — the command. No markdown, no prose, no fences. Ready to copy.
- **`explain`:** Multi-line formatted output (alias definition + examples).

### Bash/zsh parity

The `dotfiles` shell function already exists in `shell/common.sh` (lines 187–254). It handles `help`, `list`, `update`, `edit`. We add `agent` and `explain` cases.

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
│   └── agent/                  # NEW — shared assets for both shells
│       ├── system-prompt.txt   # system prompt template (shell-agnostic)
│       └── few-shot.json       # few-shot examples: [{user, assistant}, ...]
│
├── powershell/
│   └── modules/
│       └── dotfiles-agent.psm1 # NEW — Invoke-Agent, Invoke-Explain functions
│
├── shell/
│   └── lib/
│       └── agent.sh            # NEW — agent/explain implementation for bash/zsh
│
└── bootstrap/
    ├── install.ps1             # add optional Ollama install section
    └── install.sh              # add optional Ollama install section
```

### Why this layout?

1. **One source of truth:** `shared/agent/system-prompt.txt` and `few-shot.json` are consumed by both shells — no drift.
2. **Shell-specific wrappers:** `dotfiles-agent.psm1` (PowerShell) and `agent.sh` (bash) handle HTTP mechanics differently but share the prompt template.
3. **Existing conventions respected:** PowerShell modules go in `powershell/modules/`; shell libs go in `shell/lib/`.

---

## 5. Context-Injection Design

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

### Output guardrails

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| `temperature` | 0 | Deterministic, no creative hallucination |
| `max_tokens` | 80 | Single command never needs more |
| `stop` | `["\n\n", "#", "---"]` | Stop at first blank line or comment |

### Post-processing

1. Strip markdown fences (` ```bash `) if present
2. Strip leading `$` or `> ` prompt characters
3. Trim whitespace
4. If result starts with `#`, treat as "cannot build" message

---

## 6. `explain` Offline-First Design

### Non-AI derivation (always works)

```
dotfiles explain ll
```

**Logic:**

1. Look up `ll` in `aliases.json` → found
2. Print:
   ```
   ll — Long listing with hidden files

   Windows (PowerShell):
     eza -la --icons --group-directories-first | Get-ChildItem -Force

   Unix (bash/zsh):
     eza -la --icons --group-directories-first | ls -la
   ```

3. If not in aliases, look in `tools.json` by name → print description + path
4. If not found anywhere, fall back to `<command> --help 2>&1 | head -20`

### AI-enhanced path (optional enrichment)

When Ollama is available and user passes `-Ai` or we detect the model is warm:

```
dotfiles explain ll -Ai
```

Prompt the model with the alias definition and ask for 3 concrete example invocations. Append AI examples to the offline output.

### Graceful degradation

| Condition | Behavior |
|-----------|----------|
| Ollama not installed | Offline output only (no error) |
| Ollama installed but server down | Offline output + hint: "Start Ollama for AI examples" |
| `-Ai` requested but no model | Error: "Model not available. Run: ollama pull phi4-mini" |

---

## 7. Install / Portability

### Ollama installation (opt-in)

Ollama is ~300 MB installer + 2.3 GB model. **Do not auto-install.** Add opt-in flag:

```powershell
# bootstrap/install.ps1
bootstrap/install.ps1 -IncludeAgent   # install Ollama + pull default model
```

```bash
# bootstrap/install.sh
bash bootstrap/install.sh --include-agent
```

### Idempotent install logic

```
# Pseudocode (PowerShell side)
if (-not $IncludeAgent) { skip }
if (Get-Command ollama) {
    Write-Skip "Ollama already installed"
} else {
    winget install Ollama.Ollama --silent
}
# Model pull happens on first `dotfiles agent` invocation, not at install time
# (avoids 2.3 GB download during initial setup if user doesn't want it)
```

### Model pull strategy

| Option | Recommendation |
|--------|----------------|
| Pull at install time | ❌ Bloats first-run experience |
| Pull on first `agent` call | ✅ **Chosen** — lazy download, clear message |
| Manual `ollama pull` | ✅ Documented alternative |

### Model cache location

Ollama stores models at:
- Windows: `$env:USERPROFILE\.ollama\models`
- Linux: `~/.ollama/models`

Override with `$env:OLLAMA_MODELS` if user wants a different drive.

### What goes in git

| Item | In git? |
|------|---------|
| `shared/agent/system-prompt.txt` | ✅ Yes (~1 KB) |
| `shared/agent/few-shot.json` | ✅ Yes (~1 KB) |
| Model files (*.gguf) | ❌ Never |
| Ollama binary | ❌ Never |

---

## 8. Graceful Degradation Matrix

| Scenario | `dotfiles agent "<query>"` | `dotfiles explain <cmd>` |
|----------|---------------------------|-------------------------|
| **(a) Ollama not installed** | Exit 2, message: "Ollama not installed. Get it: winget install Ollama.Ollama" | ✅ Full offline output |
| **(b) Installed, server down** | Exit 2, message: "Ollama not running. Start with: ollama serve" | ✅ Offline output + hint |
| **(c) Server up, model not pulled** | Exit 3, message: "Model 'phi4-mini' not available. Run: ollama pull phi4-mini" | ✅ Offline output |
| **(d) Request times out (>30s)** | Exit 3, message: "Request timed out. Model may still be loading." | ✅ Offline output |
| **(e) Everything working** | ✅ Prints generated command | ✅ Offline + AI examples if `-Ai` |

---

## 9. Phased Implementation Plan

### Phase 1: Shared Assets + Offline `explain`
**Owner:** Switch  
**Deliverables:**
- Create `shared/agent/` directory structure
- Write `system-prompt.txt` and `few-shot.json`
- Implement offline `explain` in `dotfiles.ps1` (read aliases.json/tools.json)
- Implement offline `explain` in `shell/common.sh`
- Add `explain` to `dotfiles help` output

**Dependencies:** None  
**Estimated effort:** 2–3 hours

### Phase 2: PowerShell `agent` + Ollama Wiring
**Owner:** Trinity  
**Deliverables:**
- Create `powershell/modules/dotfiles-agent.psm1`
- Implement `Invoke-Agent` function (builds prompt, calls Ollama REST, post-processes)
- Wire into `dotfiles.ps1` dispatch
- Implement graceful degradation (detect Ollama, model availability)
- Add `$env:DOTFILES_AGENT_MODEL` support

**Dependencies:** Phase 1  
**Estimated effort:** 3–4 hours

### Phase 3: Bash/zsh `agent` Parity
**Owner:** Tank  
**Deliverables:**
- Create `shell/lib/agent.sh`
- Implement `dotfiles agent` in bash (curl + jq)
- Add to `common.sh` dispatch
- Test WSL → Windows Ollama connectivity
- Match exit codes and error messages with PowerShell

**Dependencies:** Phase 1, Phase 2 (for API contract verification)  
**Estimated effort:** 2–3 hours

### Phase 4: Optional Installer Wiring
**Owner:** Switch  
**Deliverables:**
- Add `-IncludeAgent` flag to `bootstrap/install.ps1`
- Add `--include-agent` flag to `bootstrap/install.sh`
- Idempotent Ollama install (winget on Windows, curl script on Linux)
- Update cheatsheet with agent commands
- Update ARCHITECTURE.md with agent module docs

**Dependencies:** Phases 1–3  
**Estimated effort:** 1–2 hours

### Phase 5: AI-Enhanced `explain` (Optional)
**Owner:** Trinity (PS) + Tank (bash)  
**Deliverables:**
- Add `-Ai` flag to `explain`
- Prompt model with alias definition, append AI examples
- Graceful degradation if model unavailable

**Dependencies:** Phase 2, Phase 3  
**Estimated effort:** 1–2 hours

### Phase 6: Benchmarking & Model Tuning (If Needed)
**Owner:** Oracle  
**Deliverables:**
- Test Phi-4-mini vs Qwen-1.5B on real user queries
- Tune few-shot examples based on failure cases
- Document model swap procedure

**Dependencies:** Phases 2–5 complete  
**Estimated effort:** 2 hours

---

## 10. Open Questions for Jose

### Q1: Auto-install Ollama or leave manual?

**Options:**
- **A) Fully manual:** User runs `winget install Ollama.Ollama` themselves. We just document it.
- **B) Opt-in flag:** `-IncludeAgent` / `--include-agent` in installer. ← **Recommended**
- **C) Auto-install:** Always install Ollama if not present. ← **Not recommended** (300 MB surprise)

**Recommendation:** Option B — opt-in flag.

### Q2: Default model?

**Options:**
- **A) Phi-4-mini** (2.3 GB) — best quality, MIT license
- **B) Qwen2.5-Coder-1.5B** (1.0 GB) — smaller, faster, still excellent for CLI tasks

**Recommendation:** Phi-4-mini as default, Qwen as documented alternative for low-RAM machines.

### Q3: Allow remote fallback (OpenAI/Azure)?

**Options:**
- **A) Strictly local only** — privacy first, no API keys
- **B) Optional remote fallback** — `$env:DOTFILES_AGENT_ENDPOINT` overrides to any OpenAI-compatible API

**Recommendation:** Start with A (local only). B can be added later with a simple endpoint override.

### Q4: Should `explain` require a flag for AI enrichment?

**Options:**
- **A) Always try AI** when Ollama is available
- **B) Explicit `-Ai` flag** to request AI examples ← **Recommended** (faster default, user controls latency)

### Q5: Subcommand nesting?

**Options:**
- **A) Top-level:** `dotfiles agent`, `dotfiles explain`
- **B) Nested:** `dotfiles agent ask "<query>"`, `dotfiles agent explain <cmd>`

**Recommendation:** Option A (top-level). Simpler, matches existing `help`/`list`/`register` pattern.

---

## Decision Summary

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Runtime | Ollama | Cross-platform, no Python, OpenAI-compatible REST |
| Primary model | Phi-4-mini | Best quality at 3B class, MIT license |
| Fallback model | Qwen2.5-Coder-1.5B | Lighter, faster, Apache 2.0 |
| Install | Opt-in flag | Don't surprise user with 300 MB download |
| Model pull | Lazy (first use) | Don't block install with 2.3 GB download |
| `explain` default | Offline-first | Works on day 0, AI is enhancement |
| Auto-execute | Never | Safety first |

---

## Selected defaults (chosen autonomously, pending Jose's confirmation)

Jose was unavailable when the plan was delivered and asked the team to proceed with good judgment. To keep the proposal ready-to-start, the Coordinator locks in the following defaults (all matching Morpheus's recommendations). Jose can override any of these before implementation begins:

| Open question | Selected default |
|---------------|------------------|
| Q1 — Ollama install | **Opt-in** installer flag (`-IncludeAgent` / `--include-agent`); never auto-install |
| Q2 — Default model | **Phi-4-mini** (Qwen2.5-Coder-1.5B documented as the low-RAM alternative) |
| Q3 — Remote fallback | **Strictly local** for now (endpoint override deferred to a later phase) |
| Q4 — `explain` AI | **Offline-first by default**, AI examples behind an explicit `-Ai` flag |
| Q5 — Subcommand shape | **Top-level** `dotfiles agent` and `dotfiles explain` |

## Awaiting Approval

This plan requires Jose's sign-off before implementation begins. **No code has been written yet** — only the research brief and this plan.

**To approve:** Review the phased plan (§9) and open questions (§10). If the selected defaults above are acceptable, just say "go" and Switch starts Phase 1; otherwise tell us which defaults to change.

**Next step after approval:** Switch begins Phase 1 (shared assets + offline `explain`).

---

*Authored by Morpheus — do not implement until approved.*
