# Oracle — History

## Seed Context

- **Project:** dotfiles — portable terminal/shell configuration repo
- **Stack:** PowerShell (latest), Git, Python, Node.js, bash/zsh (WSL), Oh My Posh
- **Goals:** research best-in-class terminal tooling; recommendations must be portable and install cleanly on fresh machines.
- **Requested by:** Copilot (git user.name)

## Learnings

### 2026-06-01 — Terminal Tooling Research

- **Prompt engines:** Oh My Posh wins on Windows/PowerShell (native APIs, richer themes, right-prompt). Starship wins in WSL/Linux (fastest async, single config across all shells). Recommendation: use both — OMP on PowerShell, Starship in WSL.
- **CLI replacements:** All 12 tools researched have winget IDs and scoop names. eza, bat, fd, zoxide are the non-negotiable must-haves. delta, jq, yq are high-value additions. dust/duf/procs/sd are optional quality-of-life.
- **PowerShell modules:** PSReadLine `HistoryAndPlugin` + `ListView` is the key predictive intellisense config. Terminal-Icons requires a Nerd Font. PSFzf provides Ctrl+T / Ctrl+R fuzzy pickers.
- **Package management:** `winget export/import` gives declarative reproducible Windows installs. Scoop covers CLI tools with `scoop install` one-liners. On WSL, apt covers most tools; cargo covers what apt misses.
- **Fonts:** `oh-my-posh font install CaskaydiaCove` installs without admin rights. CaskaydiaCove Nerd Font Mono is the best default for Windows Terminal.
- **Dotfiles management:** chezmoi is the recommended approach for Windows+WSL — native templating, one-liner bootstrap from GitHub, secrets support, idempotent apply. Bare-git is viable for minimalists but requires manual Windows/WSL path handling.

### 2026-06-02 — Local AI Agent Research (dotfiles agent + explain)

- **Optimal SLM for CLI command generation:** Phi-4-mini-instruct (3.8B, MIT, 128K ctx, ~2.3 GB int4) is the best single model at this size class. Qwen2.5-Coder-3B-Instruct is the strongest shell-specialized alternative; Qwen2.5-Coder-1.5B is the ultra-light option.
- **Backend winner: Ollama.** Single binary, `winget install Ollama.Ollama`, REST at `localhost:11434/v1/chat/completions` (OpenAI-compatible). Works identically from PowerShell (`Invoke-RestMethod`) and WSL bash (`curl`). No Python required. Model pull is one command.
- **ONNX GenAI path:** Valid for DirectML/GPU-first scenarios, but adds Python dependency and has no persistent server — 10–20 s cold start per call vs 1–4 s when Ollama keeps model warm.
- **Foundry Local:** Promising Windows-native path (winget + `foundry model run phi-4-mini`, OpenAI REST on `:5272`), but Windows-only — not portable to WSL/Linux. Revisit in 2027.
- **Prompting strategy:** Serialize `tools.json` + `aliases.json` into the system prompt as grounding context; temperature=0; max_tokens=80; hard stop on `\n\n`. Never auto-execute output.
- **Offline-first principle:** `dotfiles explain` fallback reads JSON registry directly — no model needed. AI layer is enhancement, not requirement.
- **Model storage:** Never in git. Download-on-first-run via `ollama pull`. Expose `$env:DOTFILES_AGENT_MODEL` for override. Point `OLLAMA_MODELS` to large drive if needed.

### 2026-06-02 — Self-Contained (No-Daemon) Agent Revision

- **Ollama rejected by Jose.** The daemon/background-server model is a hard no. Prior Decision #7 is superseded.
- **Winning approach: `llama-cli` (llama.cpp prebuilt CPU binary) + GGUF model.** No server, no Python, no always-on process. One-shot subprocess per call. Exits when done.
- **llama.cpp prebuilt binaries:** `ggml-org/llama.cpp` GitHub Releases publish `win-cpu-x64.zip` (~9 MB) and `ubuntu-x64.tar.gz` (~9 MB) on every build. `llama-cli.exe` (~5 MB) + two DLLs on Windows; single binary on Linux. CPU-only AVX2 builds — zero external runtime deps.
- **Model choice revised:** Phi-4-mini (3.8B, ~1.89 GB) is too slow for no-daemon use — cold-start per call is 11–20 s on CPU. **Primary: Qwen2.5-Coder-1.5B Q4_K_M (~986 MB, Apache 2.0) — 5–8 s cold start, shell-specialized, fits comfortably in 2 GB RAM.** Fallback: Qwen2.5-Coder-0.5B Q4_K_M (~572 MB, Apache 2.0) for tight machines — ~3–5 s cold start.
- **llamafile (Cosmopolitan) noted:** single-file runtime-bundled model option; 4 GB Windows mmap limit affects large models only (small Qwen models are fine); SmartScreen still applies. Less flexible than separate engine + model for a multi-model cache. Not the primary pick.
- **ONNX GenAI standalone binary:** no prebuilt C++ CLI artifact exists. Python path viable only for DirectML specialist use case (adds 100 MB pip dep + 8–20 s per-call cold start). Not appropriate as primary.
- **Windows SmartScreen:** downloaded unsigned `.exe` gets Zone.Identifier = 3. Setup script must call `Unblock-File` on all extracted files. Execution policy does NOT apply to native EXEs.
- **Distribution mechanics:** binary + model live in `$DOTFILES\cache\` (gitignored). Download-on-first-run with SHA256 verification. Per-OS/arch URL selection. Offline after setup. JSON-only `dotfiles explain` always works as degraded fallback.
- **Invocation is shell-agnostic:** same `llama-cli` flags from PowerShell and bash; only quoting style differs. No platform branches for the inference call itself.
