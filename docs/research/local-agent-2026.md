# Local AI Agent for dotfiles CLI — Research Brief (June 2026)

**Author:** Oracle  
**Requested by:** Jose (jmanuelcorral)  
**Status:** Proposed — for Trinity / Switch to implement  
**Scope:** `dotfiles agent "<query>"` and `dotfiles explain <cmd>` subcommands

---

## 1. Local SLM Landscape (mid-2026)

The "build me a CLI command from plain English" task has very constrained output requirements: a single shell command, maybe 1–3 lines, grounded in a small context window of registered tools. This is _ideal_ for small models — anything ≥7B is overkill.

### Model Comparison

| Model | Params | GGUF/ONNX size (int4) | RAM (comfortable) | License | CLI task quality | Notes |
|---|---|---|---|---|---|---|
| **Phi-4-mini-instruct** | 3.8B | ~2.3 GB | 6–8 GB | MIT | ★★★★★ | Best all-around; 128K ctx; top reasoning at 3B class |
| **Qwen2.5-Coder-1.5B-Instruct** | 1.5B | ~1.0 GB | 3–4 GB | Apache 2.0 | ★★★★☆ | Outperforms many 7B models on shell/bash tasks; fastest cold start |
| **Qwen2.5-Coder-3B-Instruct** | 3B | ~2.0 GB | 5–6 GB | Apache 2.0 | ★★★★★ | Near-SOTA for code tasks at this size; very strong CLI generation |
| **Llama 3.2-3B-Instruct** | 3B | ~2.0 GB | 5–6 GB | Llama 3.2 Community | ★★★★☆ | Strong general instruction follow; slightly weaker at shell specifics vs Qwen |
| **Llama 3.2-1B-Instruct** | 1B | ~0.7 GB | 2–3 GB | Llama 3.2 Community | ★★★☆☆ | Very fast, usable for simple commands; hallucination risk higher |
| **Gemma 3-2B-IT** | 2B | ~1.4 GB | 4–5 GB | Gemma ToS | ★★★★☆ | Good instruction following; Google license (non-commercial caveats) |
| **SmolLM2-1.7B-Instruct** | 1.7B | ~1.1 GB | 3–4 GB | Apache 2.0 | ★★★☆☆ | Excellent edge performance; weaker at structured command output |

**Recommendation for this task:** Phi-4-mini-instruct (primary) or Qwen2.5-Coder-3B-Instruct (lighter alternative, Apache licensed, shell-specialized). Qwen2.5-Coder-1.5B is the ultra-light option for machines with ≤8 GB RAM.

### What to avoid
- Models ≥7B: unnecessary for single-command outputs, slow on CPU
- Models without instruction tuning (base weights): will not follow JSON/structured output constraints
- Gemma license: requires accepting Google's ToS per machine — friction on a new install

---

## 2. Runtime / Backend Options

### 2.1 Ollama (`ollama run`)

**What it is:** Single-binary model manager + local REST server (`:11434`). Manages model downloads, keeps models loaded, exposes an OpenAI-compatible `/v1/chat/completions` endpoint.

**Strengths:**
- Zero-friction install: `winget install Ollama.Ollama` or `curl https://ollama.ai/install.sh | sh`
- Works identically on Windows (native) and WSL2
- Model pulls: `ollama pull phi4-mini`, `ollama pull qwen2.5-coder:3b`
- PowerShell: `Invoke-RestMethod http://localhost:11434/v1/chat/completions` — clean, no Python required
- bash/curl in WSL hits the same endpoint (WSL2 shares `localhost` with host)
- Keep-alive model: server stays running; subsequent calls are fast (~1–3 s for 50-token output on modern CPU)
- `ollama run` also available as a CLI for ad-hoc use

**Weaknesses:**
- Requires a background daemon; on fresh machine needs `ollama serve` or the tray app
- Cold start (first call after machine boot, model not loaded): 5–20 s to load Phi-4-mini into RAM
- WSL: if Ollama runs on Windows, WSL can reach it at `localhost:11434` directly (WSL2 network sharing)

**Verdict:** ✅ **Primary recommendation.** Best scripting story from PowerShell + bash/curl. No Python required. OpenAI-compatible API means future model swaps are trivial.

---

### 2.2 ONNX Runtime GenAI (`onnxruntime-genai`)

**What it is:** Microsoft's Python package for running transformer models in ONNX format; includes int4-quantized Phi-3/Phi-4 model downloads from Hugging Face.

**Invocation:** Python API only — no standalone REST server, no CLI binary. Requires `pip install onnxruntime-genai` and a Python environment.

```python
import onnxruntime_genai as og
model = og.Model("phi-4-mini-cpu-int4")
tokenizer = og.Tokenizer(model)
params = og.GeneratorParams(model)
params.input_ids = tokenizer.encode("<|user|>build a git command...<|end|><|assistant|>")
generator = og.Generator(model, params)
# stream tokens...
```

**Strengths:**
- Official Microsoft path for Phi models; best CPU + DirectML + CUDA support
- int4 quantized models from Hugging Face: `microsoft/Phi-4-mini-instruct-onnx`
- Runs headless, no daemon; Python subprocess is trivial to call from PowerShell

**Weaknesses:**
- Requires Python 3.10+ and pip install (~100 MB package + model download ~2.3 GB)
- Cold start per call: Python interpreter + model load = **8–20 s per invocation** (no persistence)
- No REST API out of the box — you would need to wrap it in a FastAPI server yourself
- More complex scripting integration than Ollama's HTTP call
- Model download is manual (huggingface-hub CLI or direct `hf_hub_download`)

**Verdict:** ⚠️ Good if Jose specifically wants ONNX/Phi on DirectML (GPU acceleration without CUDA). Higher setup friction for a dotfiles-style "just works" install. Use this path only if Ollama is unavailable or DirectML perf matters.

---

### 2.3 llama.cpp / llama-cpp-python (GGUF)

**What it is:** Portable C++ inference engine for GGUF-format models. Available as a binary, a Python binding, or a server.

**Strengths:**
- Widest model support (all Llama, Qwen, Phi, Gemma GGUF variants)
- `llama-server` (included) exposes an OpenAI-compatible REST API — same pattern as Ollama
- GGUF files downloadable from Hugging Face with `huggingface-cli download`
- Excellent CPU performance with AVX2/AVX512
- llama-cpp-python: `pip install llama-cpp-python` — prebuilt wheels for Windows and Linux

**Weaknesses:**
- More manual than Ollama: you manage model files, server flags, keep-alive yourself
- No integrated model manager (no `llama pull phi4`)
- Binaries vary by platform; users need to pick the right build (CPU vs CUDA vs Metal)

**Verdict:** 🔄 Strong fallback, especially in WSL. If Ollama is not an option, `llama-server` with a GGUF model gives the same REST API pattern. Heavier to bootstrap on a fresh Windows machine.

---

### 2.4 Microsoft Foundry Local

**What it is:** Microsoft's 2025 Windows-native LLM runtime. `winget install Microsoft.FoundryLocal` → `foundry model run phi-4-mini`. No Python required; auto-selects CPU/GPU/NPU backend.

**Strengths:**
- Zero Python dependency — pure Windows-native
- Auto-hardware selection (CUDA, DirectML, NPU, CPU fallback)
- Official Microsoft support; models include full Phi-4 family
- REST API on `localhost:5272` (OpenAI-compatible)

**Weaknesses:**
- Windows-only — will not work in WSL/Linux at all
- Still maturing (2025–2026); less community tooling than Ollama
- Large install footprint (~2 GB runtime + models)

**Verdict:** 🔮 Promising for Windows-only workflows and future NPU machines (Copilot+ PCs). Too Windows-specific for a cross-platform dotfiles repo. **Not the primary path yet.**

---

### Backend Summary

| Backend | Install friction | Portable W+WSL | Python needed | Cold start | Keep-warm | REST API | Recommendation |
|---|---|---|---|---|---|---|---|
| **Ollama** | Low (winget/curl) | ✅ Yes | No | 5–20 s | ✅ Auto | ✅ OAI-compat | **Primary** |
| onnxruntime-genai | Medium (pip + HF) | ✅ Yes | Yes | 10–20 s/call | ❌ Manual | ❌ Manual | ONNX/DirectML only |
| llama.cpp | Medium (binary) | ✅ Yes | Optional | 5–15 s | Manual | ✅ OAI-compat | **Fallback** |
| Foundry Local | Low (winget) | ❌ Windows only | No | 3–10 s | ✅ Auto | ✅ OAI-compat | Future Windows-only |

---

## 3. Invocation Pattern from the CLI

### Recommended: Ollama REST via PowerShell / curl

`dotfiles.ps1` (and `common.sh`) should call Ollama's REST endpoint directly — no subprocess Python, no binary dependency beyond `ollama`.

**PowerShell flow:**
```powershell
# Check daemon, then POST to /v1/chat/completions
$response = Invoke-RestMethod -Uri "http://localhost:11434/v1/chat/completions" `
  -Method Post -ContentType 'application/json' `
  -Body ($payload | ConvertTo-Json -Depth 5)
$response.choices[0].message.content
```

**bash/WSL flow (same endpoint):**
```bash
curl -sf http://localhost:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d "$payload" | jq -r '.choices[0].message.content'
```

Both hit `localhost:11434` — in WSL2, the host machine's Ollama is reachable on the same address (WSL2 network bridge since ~2024).

### Latency expectations

| Scenario | Expected latency |
|---|---|
| Model already warm (daemon up, model loaded) | 1–4 s for 50-token output (CPU, Phi-4-mini int4) |
| Model cold (daemon up, first call) | 5–20 s load + generation |
| Daemon not running | Need graceful degradation message |

**Strategy for keeping model warm:** Ollama automatically keeps the last-used model resident in memory for `OLLAMA_KEEP_ALIVE` minutes (default: 5 min). For a dev machine, setting `$env:OLLAMA_KEEP_ALIVE = "60m"` in `powershell/aliases.ps1` (or `common.sh`) keeps Phi-4-mini hot across a typical work session.

### Graceful degradation
When Ollama is unreachable, `dotfiles agent` should fall back to the non-AI `explain` path (see §5) and print a hint: `# Ollama not running. Start with: ollama serve`.

### Same pattern from bash/zsh
The curl call works identically in WSL. `common.sh` implements the same `dotfiles agent` function using `curl` + `jq` (both already in the stack per Decision §2). No shell-specific branches needed for the HTTP call — only for the `Invoke-RestMethod` vs `curl` mechanic.

---

## 4. Context Injection / Prompting

### What to inject
The model needs to know _what tools and aliases the user has registered_ to avoid hallucinating flags or non-existent commands.

**Grounding data to serialize:**
- `shared/tools.json` → tools array (name, description, bin path)
- `shared/aliases.json` → aliases object (name, note, windows/unix commands)
- Current shell context: `$env:OS` / `uname` to steer to the right platform variant

### Recommended prompt structure

```
SYSTEM:
You are a shell command assistant for a developer's dotfiles environment.
You ONLY build commands from the tools and aliases listed below.
Never invent flags or tools not in this list.
Respond with a SINGLE shell command, no explanation, no markdown, no trailing newline.
If the request cannot be satisfied from the available tools, respond with:
  # Cannot build: <reason>

REGISTERED TOOLS:
<tools.json tools[] serialized as: name | description | bin path>

REGISTERED ALIASES:
<aliases.json aliases{} serialized as: alias | note | windows: ... | unix: ...>

SHELL: windows-powershell  # or: unix-bash / unix-zsh

USER:
<user's natural language query>
```

**Few-shot examples** (2–3 shots in the system prompt) significantly improve single-line output discipline. Example:
```
User: list files sorted by size
Assistant: eza -la --sort=size --icons
```

### Output guardrails
- Max tokens: 80 (a single command never needs more)
- Temperature: 0 (deterministic, no creative hallucination)
- Stop sequences: `\n\n`, `#`, `---` — model stops at first blank line
- Post-process: strip markdown fences (` ```bash `) if present; strip leading `$` or `> `
- **Never auto-execute** — print the command, let the user confirm and run it

### Context size check
Serialized `tools.json` + `aliases.json` for a typical dotfiles setup (50–100 entries) is ≈2–4 KB of text. Phi-4-mini's 128K context window handles this trivially. Even Qwen2.5-Coder-1.5B's 128K context is adequate.

---

## 5. `explain` Subcommand

### Usage
```
dotfiles explain ll          # explain the 'll' alias
dotfiles explain dotfiles    # explain the dotfiles CLI itself
dotfiles explain git status  # explain a registered tool or built-in
```

### Model-assisted approach (when Ollama is running)
Prompt the model with the tool/alias definition from the registry and ask for 3 example invocations:
```
Given this alias definition:
  alias: ll → eza -la --icons --group-directories-first
Provide 3 concrete example invocations with a one-line comment for each.
Output ONLY the examples, no prose.
```

Output is grounded: the model sees the actual command text, not an abstraction.

### Non-AI fallback (always available)
Pull data directly from the registry files — zero model required:

1. **For aliases:** Read `aliases.json`, find the alias, print the `_note` + both `windows` and `unix` values formatted as examples
2. **For tools:** Read `tools.json`, find by name, print `description` + path
3. **For unknown entries:** `command --help 2>&1 | head -20` or `man <command> 2>&1 | head -20`

This fallback is synchronous, instant, and works offline. It should be the **default** when Ollama is unavailable, making `dotfiles explain` useful from day one even before any model is installed.

### Recommendation
Implement the fallback first (pure JSON read), add model path as enhancement. The fallback provides 80% of the value with 0% of the infrastructure cost.

---

## 6. Recommendation Summary

### Primary recommendation: **Ollama + Phi-4-mini-instruct**

- Install: `winget install Ollama.Ollama` (Windows) / `curl https://ollama.ai/install.sh | sh` (WSL)
- Model: `ollama pull phi4-mini` — 2.3 GB, MIT licensed, 128K context, best instruction following at 3B class
- Invocation: `Invoke-RestMethod` (PowerShell) / `curl` (bash) → `localhost:11434/v1/chat/completions`
- Keep-warm: set `OLLAMA_KEEP_ALIVE=60m` in dotfiles shell config
- Works identically on Windows + WSL2 — same endpoint, same prompt, same parsing

### Lighter fallback: **Ollama + Qwen2.5-Coder-1.5B-Instruct**

- Model: `ollama pull qwen2.5-coder:1.5b` — ~1.0 GB, Apache 2.0, faster cold start
- Use on machines with ≤8 GB RAM or where disk space is tight
- Shell/bash task quality is slightly better per GB than Phi at this size

### ONNX path (if user specifically wants ONNX/DirectML)
- Use `onnxruntime-genai` Python package + `microsoft/Phi-4-mini-instruct-onnx` from HuggingFace
- Wrap in a thin `bin/dotfiles-agent.py` script; dotfiles.ps1 shells out to `python bin/dotfiles-agent.py`
- Trade-off: adds Python dependency, no persistent server, higher per-call overhead

### Offline-first default
Implement `dotfiles explain` with the **JSON-only fallback** so the feature works offline and on machines with no model. The AI path (Ollama) is an enhancement, not a requirement. `dotfiles agent` should fail gracefully with a helpful message when Ollama is unreachable.

### Model file strategy — do NOT commit to git

| Option | Recommendation |
|---|---|
| Git LFS | ❌ Overkill; 2 GB model costs LFS bandwidth on every clone |
| In-repo | ❌ Absolutely not — blows up clone size |
| Download-on-first-run | ✅ **Best.** `dotfiles agent --setup` runs `ollama pull phi4-mini` |
| Cache dir | ✅ Ollama stores models in `$env:OLLAMA_MODELS` (Windows) / `~/.ollama/models` (Linux); point to a large drive via `$env:DOTFILES_AGENT_MODEL` |

### Portability gotchas

1. **WSL ↔ Windows Ollama:** WSL2 can reach Windows-side Ollama at `localhost:11434`. If the user runs Ollama inside WSL, the Windows PowerShell side needs `wsl hostname -I | awk '{print $1}'` to find the WSL IP. Simplest: install Ollama on Windows side only.
2. **Model path env var:** Expose `$env:DOTFILES_AGENT_MODEL` (default: `phi4-mini`) so users can override with a lighter/heavier model without editing scripts.
3. **Python env for ONNX path:** If using onnxruntime-genai, use a venv at `$env:DOTFILES\.venv` to avoid polluting global Python.
4. **Offline detection:** Use a short `Test-NetConnection localhost -Port 11434` (PowerShell) or `curl -sf http://localhost:11434/api/tags` (bash) with a 1-second timeout to detect Ollama availability before prompting.

---

### Quick-decision table

| Criterion | Ollama + Phi-4-mini | Ollama + Qwen-1.5B | ONNX GenAI + Phi-4-mini |
|---|---|---|---|
| Install steps | 2 (winget + pull) | 2 (winget + pull) | 4 (pip + hf download + wrapper) |
| Works in WSL | ✅ | ✅ | ✅ |
| Python required | ❌ | ❌ | ✅ |
| Disk footprint | ~2.3 GB | ~1.0 GB | ~2.3 GB |
| Cold start | 5–20 s | 3–10 s | 10–20 s/call |
| DirectML/GPU | Via Ollama backend | Via Ollama backend | ✅ Native |
| License | MIT | Apache 2.0 | MIT |
| Offline | ✅ | ✅ | ✅ |
| Shell scripting | Simple HTTP | Simple HTTP | Python subprocess |
| **Verdict** | **Primary** | **Fallback** | ONNX specialist |

---

*Research by Oracle — do not implement here. Implementation is Trinity (PowerShell) + Switch (bin/ + registration).*
