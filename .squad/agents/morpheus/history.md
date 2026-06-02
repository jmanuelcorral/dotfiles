# Morpheus — History

## Seed Context

- **Project:** dotfiles — portable terminal/shell configuration repo
- **Stack:** PowerShell (latest), Git, Python, Node.js, bash/zsh (WSL), Oh My Posh
- **Goals:** portable config reusable across PCs; one-line install from repo; Linux-style aliases in PowerShell; fix Oh My Posh errors; setup script that absorbs the user's own tooling (e.g. gituseswitch); CLI help for most-used commands.
- **Requested by:** Copilot (git user.name)

## Learnings

### 2026-06-01 — Repository Architecture Established

**Decisions made:**

1. **Directory structure:** Separated by shell type (`powershell/`, `shell/`) rather than by function, because shell-specific code dominates. Cross-shell data lives in `shared/`.

2. **Load contract:** System profile files become thin stubs that set `$DOTFILES` and source the repo. This keeps the repo as single source of truth and makes portability trivial — just change the path in the stub.

3. **Module loading order:** Explicit order (aliases → psreadline → prompt → completions) because later modules depend on earlier ones. Drop-in modules in `modules/` load last alphabetically.

4. **Idempotency pattern:** Guard all profile modifications with marker comments (`# dotfiles bootstrap`). Check existence before acting. Always backup before modifying.

5. **Cross-shell aliases:** Defined once in `shared/aliases.json`, consumed by both shells. Each shell generates native syntax from the same source.

6. **User tool registration:** `bin/` for scripts + `shared/tools.json` for metadata. The `dotfiles` CLI reads this for the help system.

**Rationale:** Small composable modules over monolith profiles. Symmetric structure where sensible (both shells have a main entry + modules), divergent where necessary (PowerShell-specific PSReadLine, bash-specific shopt).

### 2026-06-02 — Local AI Agent Architecture Plan

**Context:** Jose requested a local AI agent feature (`dotfiles agent` and `dotfiles explain`) for the CLI. Oracle delivered research recommending Ollama + Phi-4-mini. Morpheus produced an architectural plan.

**Key learnings:**

1. **Ollama as universal backend:** Ollama's OpenAI-compatible REST API at `localhost:11434` is callable identically from PowerShell (`Invoke-RestMethod`) and bash/WSL (`curl + jq`). WSL2's localhost sharing means Windows-side Ollama serves both shells without configuration.

2. **Offline-first is non-negotiable:** `explain` must work day-0 with no model — pure registry lookup from `aliases.json`/`tools.json`. AI is enhancement, not dependency. This pattern should apply to future features.

3. **Shared prompt assets:** Single `shared/agent/system-prompt.txt` and `few-shot.json` consumed by both shells prevents drift. Shell wrappers handle HTTP mechanics differently but share the prompt template.

4. **Opt-in heavy dependencies:** Ollama is ~300 MB + 2.3 GB model. Auto-installing would violate user trust. Use explicit flags (`-IncludeAgent`, `--include-agent`) and lazy model pull on first use.

5. **Graceful degradation matrix:** Plan all failure modes upfront: (a) Ollama not installed, (b) server down, (c) model not pulled, (d) timeout. Each has defined behavior and message.

6. **Phased implementation with clear ownership:** Breaking work into 6 phases with Squad agent assignments (Switch → Trinity → Tank → Oracle) makes the plan actionable and prevents scope creep.

**Plan location:** `docs/plans/local-agent-plan.md`

### 2026-06-02 — Self-Contained Agent Architecture Revision (Ollama Rejected)

**Context:** Jose rejected Ollama (always-on daemon). Required a self-contained design with one-shot subprocess invocation.

**Key learnings:**

1. **One-shot subprocess vs. REST daemon:** Without a warm cache, cold-start latency is the dominant factor. Switched from Phi-4-mini (11–20 s cold) to Qwen2.5-Coder-1.5B (5–8 s cold) — acceptable for an explicit CLI query.

2. **Same invocation from both shells:** `llama-cli` flags are OS-agnostic: `--no-display-prompt --single-turn --log-disable -n 80 --temp 0`. Only shell quoting differs. This keeps the prompt-building contract truly shared.

3. **Setup as explicit opt-in:** `dotfiles agent --setup` triggers download, not bootstrap/install. User explicitly requests the 1 GB download. Lazy trigger on first `agent` call also works with user prompt.

4. **Windows-specific friction:** Downloaded `.exe` gets `Zone.Identifier = 3` from SmartScreen. `Unblock-File` is required. Also, `ggml.dll` + `llama.dll` must accompany the exe — all three extracted to the same directory.

5. **Model choice matters for cold-start:** Phi-4-mini is quality-best but 11–20 s per call is unacceptable without warm cache. Qwen2.5-Coder-1.5B provides 90% of the quality at 50% of the latency. The 0.5B fallback covers low-RAM machines.

6. **Explain is fully offline now:** Removed the `-Ai` enrichment path. `explain` does registry lookup only — no model invocation. Simpler, faster, always works.

**Revised plan location:** `docs/plans/local-agent-plan.md` (v2, self-contained)
