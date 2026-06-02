# Local AI Agent for dotfiles CLI — Research Brief (June 2026)

**Author:** Oracle  
**Requested by:** Jose (jmanuelcorral)  
**Status:** REVISED — Ollama rejected by Jose; see "Self-Contained" section below  
**Scope:** `dotfiles agent "<query>"` and `dotfiles explain <cmd>` subcommands

---

## Self-Contained (No-Daemon) Options — Revised per Jose

> **Constraint change (2026-06-02):** Jose has rejected Ollama and any always-on daemon or background server.  
> The new requirement: inference runs as a **one-shot subprocess per call** — a static binary + GGUF model  
> file downloaded into `$env:DOTFILES\cache\` on first run. Zero always-on processes. Fully offline after setup.  
> Portable across Windows (PowerShell) and WSL/Linux (bash/zsh). CPU-only must be viable on a dev laptop.

---

### SC-1 — llama.cpp as a Self-Contained One-Shot CLI ✅ Leading Candidate

#### What it is

`llama-cli` is the command-line inference binary from the [ggml-org/llama.cpp](https://github.com/ggml-org/llama.cpp) project.
It loads a GGUF model, evaluates the prompt, writes output to stdout, and exits. **No server, no daemon, no port.**
The project publishes prebuilt binaries on every release (multiple times per week as of mid-2026).

#### Binary acquisition

- **Releases:** `https://github.com/ggml-org/llama.cpp/releases`
- **Windows x64 (CPU):** `llama-{build}-bin-win-cpu-x64.zip` — ~9 MB compressed  
  Extracts to: `llama-cli.exe` (~5 MB), `ggml.dll`, `llama.dll` (all three required, ~15 MB total extracted)
- **Windows ARM64:** `llama-{build}-bin-win-cpu-arm64.zip` — ~9.7 MB
- **Linux x86_64:** `llama-{build}-bin-ubuntu-x64.tar.gz` — ~9 MB
- **Linux arm64:** `llama-{build}-bin-ubuntu-arm64.tar.gz`
- **Version pinning:** release URLs encode the build number (e.g., `b9196`); the setup script pins to a tested build and verifies SHA256 before use.
- **CPU-only build:** default `win-cpu-*` / `ubuntu-*` targets AVX2; no CUDA/Vulkan dependencies.

#### One-shot invocation — identical args on both shells

```
llama-cli -m <model.gguf> --no-display-prompt --single-turn --log-disable \
  -n 80 --temp 0 -p "<prompt text>"
```

**PowerShell:**
```powershell
$out = & "$env:DOTFILES\cache\bin\llama-cli.exe" `
  -m "$env:DOTFILES\cache\models\qwen25coder-1.5b-q4_k_m.gguf" `
  --no-display-prompt --single-turn --log-disable `
  -n 80 --temp 0 -p $prompt
```

**bash/WSL:**
```bash
out=$("$DOTFILES/cache/bin/llama-cli" \
  -m "$DOTFILES/cache/models/qwen25coder-1.5b-q4_k_m.gguf" \
  --no-display-prompt --single-turn --log-disable \
  -n 80 --temp 0 -p "$prompt")
```

The argument set is **OS-agnostic** — only shell quoting differs. No platform-specific branches for the inference call itself.

#### Cold-start latency per call (no warm cache)

| Model | RAM needed | Disk load (NVMe) | 50-tok gen (CPU) | Total per call |
|---|---|---|---|---|
| Qwen2.5-Coder-0.5B Q4_K_M | ~1 GB | ~1–2 s | ~2–3 s | **~3–5 s** |
| Qwen2.5-Coder-1.5B Q4_K_M | ~2 GB | ~2–3 s | ~3–5 s | **~5–8 s** |
| Phi-4-mini 3.8B Q4_K_M | ~4 GB | ~5–8 s | ~6–12 s | **~11–20 s** |

Since there is no warm state, every call incurs model-load cost. For the "produce one shell command" task with ≤80 output tokens, the 1.5B model is ideal: fast enough for a dev CLI, quality sufficient for grounded command generation.

#### Strengths
- Zero external runtime dependencies (C++ static binary, AVX2 CPU-only build)
- Works fully offline after setup
- Identical invocation from PowerShell and bash (same flags, same exe path logic)
- No daemon, no server, no open port, no background process
- Tiny binary footprint: ~9 MB download, ~15 MB extracted
- Active project; releases ship multiple times per week
- Windows (x64/arm64) + Linux (x64/arm64) + macOS all covered

#### Weaknesses / Caveats
- **Windows SmartScreen:** Downloaded unsigned `.exe` gets `Zone.Identifier = 3` (internet-marked).  
  Setup script must call `Unblock-File` on `llama-cli.exe` and each DLL to remove the mark,  
  or the OS will block execution with a security warning on first run.
- **Windows DLLs:** The CPU build ships `ggml.dll` + `llama.dll` alongside the EXE — the full ZIP must be extracted, not just the EXE alone. All three files go to `$DOTFILES\cache\bin\`.
- **Cold start per call:** 3–8 s depending on model — acceptable for a CLI tool the user explicitly invoked, but no warm path. This is the main trade-off vs. Ollama.
- **Linux chmod:** `chmod +x` required after download; trivial but must be in setup script.
- **Per-OS binary selection:** Setup script must detect OS+arch (`$env:PROCESSOR_ARCHITECTURE` on Windows, `uname -m` on Linux) to select the correct release archive URL.

#### Verdict
✅ **Leading candidate.** Best tradeoff: tiny binary, zero dependencies, truly one-shot, scriptable identically from both shells, offline-first.

---

### SC-2 — ONNX Runtime GenAI Self-Contained

#### Option (a): model-qa/model-chat C++ binary

No official prebuilt standalone C++ CLI binary is published in `onnxruntime-genai` releases. The `model-qa` example exists as a buildable sample in the repo, not a downloadable artifact. Building it requires ONNX Runtime SDK + C++ toolchain + CMake — far too much friction for a dotfiles setup script.

**Verdict:** ❌ Not viable. Would require Jose (or CI) to build and host the binary.

#### Option (b): Python script using `onnxruntime_genai`

- Install: `pip install onnxruntime-genai` (~100 MB package)
- Model: `microsoft/Phi-4-mini-instruct-onnx` from HuggingFace (~2.3 GB download)
- Invocation: `python dotfiles-agent.py "<prompt>"` — Python interpreter + model load per call
- Cold start per call: **8–20 s** (Python startup + full model deserialisation each call)
- DirectML acceleration: available on Windows for GPU path; not available in WSL
- Offline after install: yes

**vs. llama-cli:** ONNX GenAI is strictly worse on cold-start latency (Python overhead adds 2–5 s before model even loads), requires Python/pip, and provides no benefit unless the user specifically needs DirectML GPU acceleration or prefers the ONNX-format Phi models.

**Verdict:** ⚠️ Valid only if DirectML GPU acceleration is a hard requirement. Not appropriate for the "minimal, no-daemon, portable" goal. If Jose wants ONNX/DirectML, wrap in a thin `bin/dotfiles-agent.py` and call from PowerShell via `python`; but this is the ONNX specialist path, not the primary recommendation.

---

### SC-3 — Single-File and Other Static Options

#### llamafile (Cosmopolitan Libc)

**What:** A single executable that bundles the llama.cpp runtime using [Cosmopolitan](https://justine.lol/cosmopolitan/) — one file runs on Linux, macOS, and Windows from the same binary. The model can optionally be bundled inside the file (making it truly one artifact), or loaded from an external path like any GGUF file.

- **Runtime-only llamafile:** ~7 MB (runtime without model)
- **Model-bundled llamafile:** runtime + GGUF = e.g., Qwen2.5-Coder-0.5B Q4_K_M → ~579 MB; Qwen2.5-Coder-1.5B → ~993 MB
- **Windows 4 GB mmap limit:** llamafile uses `mmap` to load the bundled model region. On Windows, this fails for files larger than ~4 GB due to a PE + mmap interaction. For small models (0.5B ≈ 579 MB, 1.5B ≈ 993 MB), this is **well under the limit** and works fine. Models ≥2 GB bundled risk this issue on Windows. (Using llamafile as a runtime-only binary with an external GGUF sidesteps this entirely but removes the single-file advantage.)
- **Windows execution:** rename `.llamafile` → `.exe` (or run directly in newer versions). SmartScreen still applies — same `Unblock-File` treatment needed as llama-cli.
- **Linux:** `chmod +x` + run directly.
- **Invocation:** `./model.llamafile -p "<prompt>" --no-display-prompt -n 80 --temp 0` — same flags as llama-cli (it IS llama.cpp underneath).
- **Project status (mid-2026):** Originally Mozilla-backed; maintained by Justine Tunney. Slower release cadence than llama.cpp main. Model architecture support follows llama.cpp with a lag.
- **Pros:** Truly single-file distribution (runtime bundled in model file). No separate binary download — one file download covers everything.
- **Cons:** Cannot swap models without downloading a new llamafile per model. Bundled-model path defeats the "shared engine, swappable model" design the dotfiles repo wants. SmartScreen requires the same installer intervention as llama-cli. The single-file advantage is less compelling when the installer already manages a cache dir.

**Verdict:** 🔄 Notable and technically elegant. For the dotfiles use case (cache dir, swappable model, separate engine), llama-cli provides more flexibility with comparable simplicity. Llamafile's main win (single download = everything) is only relevant if we commit to one specific model forever. Worth revisiting if the repo decides to ship a pinned tiny model with zero configuration.

#### llama-cpp-python

Python package embedding llama.cpp as a C extension. Prebuilt wheels exist for Windows + Linux. Adds Python/pip dependency with no benefit over llama-cli if Python isn't otherwise required. Per-call latency is comparable (C++ inference underneath), but startup includes Python interpreter load.

**Verdict:** ❌ Adds friction without benefit. Use `llama-cli` binary directly.

#### .NET options (LLamaSharp / Microsoft.ML.OnnxRuntimeGenAI)

- **LLamaSharp:** .NET 8+ wrapper around llama.cpp. Viable for an in-process C# tool but adds .NET runtime as a dependency. More complex than calling `llama-cli` as a subprocess.
- **Microsoft.ML.OnnxRuntimeGenAI (NuGet):** In-process .NET path for ONNX models. Same dependency story.
- Neither is relevant for bash/PowerShell scripting context — they target .NET host processes.

**Verdict:** ❌ Not applicable for the current shell-script invocation pattern.

---

### SC-4 — Model Choice for Self-Contained Setup

Task: short natural-language prompt → ONE shell command, grounded in registered tools/aliases. Output budget: ≤80 tokens. Latency budget: ideally <10 s per call on CPU. Constraint: GGUF format (llama-cli compatible).

| Model | Params | Q4_K_M GGUF size | RAM needed | License | Shell task quality | Cold start (CPU) |
|---|---|---|---|---|---|---|
| **Qwen2.5-Coder-1.5B-Instruct** | 1.5B | **~986 MB** | ~2 GB | Apache 2.0 | ★★★★☆ | ~5–8 s |
| **Qwen2.5-Coder-0.5B-Instruct** | 0.5B | **~572 MB** | ~1 GB | Apache 2.0 | ★★★☆☆ | ~3–5 s |
| Phi-4-mini-instruct | 3.8B | ~1.89 GB | ~4 GB | MIT | ★★★★★ | ~11–20 s |
| Llama-3.2-1B-Instruct | 1B | ~700 MB | ~2 GB | Llama 3.2 | ★★★☆☆ | ~4–6 s |
| SmolLM2-1.7B-Instruct | 1.7B | ~1.2 GB | ~2.5 GB | Apache 2.0 | ★★★☆☆ | ~5–8 s |

**Primary model: `Qwen2.5-Coder-1.5B-Instruct Q4_K_M` (~986 MB)**  
- Apache 2.0 license: no per-machine ToS, zero friction on fresh machines  
- Shell/code-specialized training; outperforms many 7B general models on shell/bash tasks per published benchmarks  
- 32K context window: ample for serialised tools.json + aliases.json (≈2–4 KB)  
- ~5–8 s total per call on a modern laptop CPU: acceptable for an explicit user query  
- Source: `Qwen/Qwen2.5-Coder-1.5B-Instruct-GGUF` on HuggingFace

**Tiny fallback: `Qwen2.5-Coder-0.5B-Instruct Q4_K_M` (~572 MB)**  
- Same HuggingFace org (`Qwen/Qwen2.5-Coder-0.5B-Instruct-GGUF`), same Apache 2.0 license  
- For machines with ≤4 GB RAM, tight disk, or where ~3 s latency is preferred over quality  
- Runs at >30 tokens/s on any modern CPU  
- Quality is adequate for simple, well-grounded command lookups; higher hallucination risk on complex queries

**Why NOT Phi-4-mini as primary here:**  
Phi-4-mini (3.8B, ~1.89 GB) delivers the highest quality but cold-start is 11–20 s per call on CPU — unacceptable for a terminal workflow where the user expects a quick response. Phi-4-mini was the right pick for Ollama (warm cache = 1–4 s after load); without a daemon, the cold-start penalty makes it the wrong choice.

---

### SC-5 — Distribution & Portability Mechanics

#### Cache layout (under `$env:DOTFILES`, NOT in git)

```
$env:DOTFILES\
  cache\
    bin\
      llama-cli.exe          # Windows PE binary
      ggml.dll               # required alongside llama-cli.exe (Windows)
      llama.dll              # required alongside llama-cli.exe (Windows)
      llama-cli              # Linux ELF binary (chmod +x on setup)
    models\
      qwen25coder-1.5b-q4_k_m.gguf   # primary model (~986 MB)
      qwen25coder-0.5b-q4_k_m.gguf   # fallback model (~572 MB, optional)
```

Add `cache/` to `.gitignore`. Git LFS is explicitly wrong here: LFS would force every clone to download 1–2 GB of binary model data — unacceptable for a dotfiles repo that should clone in seconds.

#### Download-on-first-run flow

`dotfiles agent --setup` (or auto-triggered on first `dotfiles agent` call with no binary/model found):

1. **Detect OS + arch:**
   - Windows: `$env:PROCESSOR_ARCHITECTURE` → `AMD64` or `ARM64`
   - Linux/WSL: `uname -m` → `x86_64` or `aarch64`
2. **Select release archive URL** (pinned build number, e.g., `b9196`):
   - Windows x64: `https://github.com/ggml-org/llama.cpp/releases/download/b9196/llama-b9196-bin-win-cpu-x64.zip`
   - Linux x64:   `https://github.com/ggml-org/llama.cpp/releases/download/b9196/llama-b9196-bin-ubuntu-x64.tar.gz`
   - Linux arm64: `https://github.com/ggml-org/llama.cpp/releases/download/b9196/llama-b9196-bin-ubuntu-arm64.tar.gz`
3. **Download + verify SHA256** (`Get-FileHash` on PowerShell; `sha256sum` on Linux). Abort if mismatch.
4. **Extract** to `$DOTFILES\cache\bin\`
5. **Platform post-processing:**
   - Windows: `Unblock-File` on `llama-cli.exe`, `ggml.dll`, `llama.dll` → removes `Zone.Identifier` stream, prevents SmartScreen execution block. (Execution policy does NOT apply to `.exe` — only `.ps1`.)
   - Linux: `chmod +x "$DOTFILES/cache/bin/llama-cli"`
6. **Download GGUF model:**
   `https://huggingface.co/Qwen/Qwen2.5-Coder-1.5B-Instruct-GGUF/resolve/main/qwen2.5-coder-1.5b-instruct-q4_k_m.gguf`
7. **Verify model SHA256** against pinned expected value.

#### Offline behavior

- Once binary + model are in cache: **fully offline**. No network calls during inference.
- If cache missing at invocation time: print clear error + setup instructions. Do NOT hang silently.
- `dotfiles explain` JSON-only fallback is always available offline regardless of cache state.

#### Windows SmartScreen and execution policy

- SmartScreen applies to downloaded unsigned `.exe` files (Zone.Identifier = 3 from internet download).
- `Unblock-File` in the setup script removes the mark; no admin rights required.
- PowerShell execution policy does NOT affect native `.exe` files.
- The setup script itself is a `.ps1`; the existing bootstrap execution-policy bypass already covers it.

#### Linux / WSL notes

- Ubuntu x64 build targets glibc 2.35+ → works on Ubuntu 22.04+ and WSL2 running Ubuntu 22.04/24.04.
- Alpine/musl: not covered by the Ubuntu build; a musl-static variant may exist in releases — out of scope for typical dev machine.
- WSL2 on Windows: the Linux binary runs natively inside WSL; no need to call the Windows `.exe` from bash.

---

### SC-6 — Clear Recommendation (Self-Contained, No-Daemon)

#### Primary: `llama-cli` + `Qwen2.5-Coder-1.5B-Instruct Q4_K_M`

| Attribute | Value |
|---|---|
| Engine | `llama-cli` prebuilt CPU binary (ggml-org/llama.cpp releases) |
| Binary download | ~9 MB compressed / ~15 MB extracted (Win: exe + 2 DLLs; Linux: single binary) |
| Model | `Qwen2.5-Coder-1.5B-Instruct Q4_K_M` GGUF |
| Model download | ~986 MB from HuggingFace |
| License | Apache 2.0 (engine: MIT; model: Apache 2.0) — no per-machine ToS friction |
| Cold start per call | ~5–8 s on modern laptop CPU (SSD) |
| Offline | ✅ Fully offline after one-time setup |
| No daemon | ✅ One-shot subprocess; exits when done |
| Python | ❌ Not required |
| Portability | Windows x64/arm64 + Linux x64/arm64 + WSL2 |
| Shell invocation | Identical args from PowerShell and bash |

#### Lighter fallback: same engine + `Qwen2.5-Coder-0.5B-Instruct Q4_K_M`

- Switch only the model path; same llama-cli binary, same flags
- ~3–5 s per call, ~572 MB on disk
- Suitable for machines with ≤4 GB RAM or where latency < quality

#### Self-Contained Options Comparison Table

| Option | Binary size | Model size | Cold start | Daemon? | Python? | Win SmartScreen | Linux | Verdict |
|---|---|---|---|---|---|---|---|---|
| **llama-cli + Qwen 1.5B** | ~9 MB zip | ~986 MB | 5–8 s | ❌ | ❌ | Unblock-File | chmod +x | ✅ **Primary** |
| llama-cli + Qwen 0.5B | ~9 MB zip | ~572 MB | 3–5 s | ❌ | ❌ | Unblock-File | chmod +x | ✅ Fallback |
| llamafile + Qwen 0.5B | ~579 MB (1 file) | bundled | 3–5 s | ❌ | ❌ | Unblock-File | chmod +x | 🔄 Notable |
| ONNX GenAI Python (Phi-4-mini) | via pip | ~2.3 GB | 8–20 s | ❌ | ✅ required | N/A | via Python | ⚠️ DirectML specialist |
| llama-cli + Phi-4-mini 3.8B | ~9 MB zip | ~1.89 GB | 11–20 s | ❌ | ❌ | Unblock-File | chmod +x | ❌ Too slow CPU |
| Ollama + any model | installer | varies | 1–4 s warm | ✅ required | ❌ | via winget | via curl | ❌ Rejected by Jose |

---
> **⚠️ The sections below describe the previous Ollama-based recommendation.**  
> **They are SUPERSEDED by the self-contained analysis above following Jose's rejection of Ollama.**  
> Kept for reference; do not implement.

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
