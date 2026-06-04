# dotfiles — Decisions Log

> Architectural decisions, active contracts, and team guidelines for AI agents.

---

## #12 — 2026-06-04: AGENTS.md as canonical agent onboarding contract

**By:** Morpheus

**What:** Added AGENTS.md to the repo root (following https://agents.md convention) as the primary onboarding document for AI coding agents. It references .squad/decisions.md for architectural changes and documents the load contract, parity conventions, and idempotency rules in one place.

**Why:** Without a single-file entry point, agents were discovering the load contract piecemeal from docs/ARCHITECTURE.md, decisions.md, and individual agent charters. AGENTS.md surfaces the non-negotiables (thin-stub pattern, shared/aliases.json single-source, POSIX-first common.sh, guard-every-tool rule) immediately, reducing drift from new agents that don't read the full decisions log.

**Impact:** All future AI agents working in this repo should treat AGENTS.md as their first read, and .squad/decisions.md as the authoritative source for active architectural decisions. The dotfiles-architecture SKILL.md in skills/ provides the same knowledge in portable skill format for agents working in derived or companion projects.

---

## #11 — 2026-06-02: Switch Phase 1 + Phase 2 Complete

**Date:** 2026-06-02  
**Author:** Switch  
**Status:** Done — awaiting Trinity (Phase 3) and Tank (Phase 4)

### Files Created

| File | Purpose |
|------|---------|
| `shared/agent/system-prompt.txt` | Shell-agnostic prompt template with `{{SHELL_TYPE}}`, `{{TOOLS_BLOCK}}`, `{{ALIASES_BLOCK}}` |
| `shared/agent/few-shot.json` | 6 example pairs grounded in real aliases (ll, gst, gl, fd, rg) |
| `shared/agent-config.json` | Engine version, model URLs, defaults |
| `powershell/modules/dotfiles-agent.psm1` | Install-AgentEngine, Get-AgentPaths, Test-AgentReady |
| `shell/lib/agent.sh` | install_agent_engine(), agent_paths(), agent_ready(); Phase 4 placeholder |

### Files Modified

| File | Changes |
|------|---------|
| `bin/dotfiles.ps1` | Added Invoke-Explain, Invoke-Agent, explain+agent dispatch, $Arg2 param, updated help text |
| `shell/common.sh` | Added explain) and agent) cases; updated usage string |
| `.gitignore` | Added `cache/` and `cache/*` |

### Pinned Engine

| Item | Value |
|------|-------|
| Release tag | `b9469` |
| Windows x64 | `https://github.com/ggml-org/llama.cpp/releases/download/b9469/llama-b9469-bin-win-cpu-x64.zip` |
| Linux x64 | `https://github.com/ggml-org/llama.cpp/releases/download/b9469/llama-b9469-bin-ubuntu-x64.tar.gz` |

### Pinned Models

| Model | URL |
|-------|-----|
| Primary (1.5B Q4_K_M) | `https://huggingface.co/Qwen/Qwen2.5-Coder-1.5B-Instruct-GGUF/resolve/main/qwen2.5-coder-1.5b-instruct-q4_k_m.gguf` |
| Fallback (0.5B Q4_K_M) | `https://huggingface.co/Qwen/Qwen2.5-Coder-0.5B-Instruct-GGUF/resolve/main/qwen2.5-coder-0.5b-instruct-q4_k_m.gguf` |

### SHA256 Strategy

All `sha256` fields are `null` in `agent-config.json`. Computing SHA256 of ~1 GB GGUF files without downloading them is impractical. Integrity is verified by:
1. File size within ±10% of `size_mb`  
2. `llama-cli --version` succeeding after extraction

To harden supply chain: run setup once, compute `sha256sum cache/models/*.gguf` and `sha256sum cache/bin/*.zip`, then write those values back into `agent-config.json`.

### Verification Results

- `bin/dotfiles.ps1` parses cleanly (no syntax errors)
- `powershell/modules/dotfiles-agent.psm1` parses cleanly
- `shell/common.sh` passes `bash -n`
- `shell/lib/agent.sh` passes `bash -n`
- `shared/agent-config.json` valid JSON (`jq .`)
- `shared/agent/few-shot.json` valid JSON (`jq .`)
- `dotfiles explain ll` runs offline and prints alias note + Windows/Unix forms

---

## #10 — 2026-06-04: `dotfiles skills` Subcommand Contract

**Date:** 2026-06-04  
**Author:** Switch  
**Status:** ACTIVE  

### Summary

Adds a `skills` subcommand to the `dotfiles` CLI (both `bin/dotfiles.ps1` and `shell/common.sh`) that makes the repo's reusable agent skills installable into any project with one command.

### Contract

#### Subcommand Signatures

```
dotfiles skills list
dotfiles skills path
dotfiles skills install [target]
```

| Form | Action |
|------|--------|
| `dotfiles skills list` | Scan `<repo>/skills/*/SKILL.md`, print each folder name and its `description:` frontmatter field (best-effort parse). |
| `dotfiles skills path` | Print the absolute path of `<repo>/skills/`. |
| `dotfiles skills install [target]` | Copy every `skills/<name>/` folder recursively into `<target>/.copilot/skills/`. Default `target` = current working directory. Idempotent: overwrites existing files. Reports each skill with `✓`. Prints summary count and destination. |
| `dotfiles skills` (bare) | Print usage for the three forms. |

#### Guard

If the `skills/` directory does not exist:
- PowerShell: `Write-Host "⚠ skills/ directory not found"` and return (no exit 1).
- Bash: `echo "dotfiles: skills/ directory not found"` to stderr and `return 1`.

#### Skills Directory Layout

```
<repo>/
└── skills/
    └── <name>/
        └── SKILL.md    ← frontmatter: name, description, domain, confidence, source
```

Each skill folder is self-contained. The `SKILL.md` file uses YAML-style frontmatter with at minimum a `description:` field. The `dotfiles skills list` parser extracts this with a regex (PowerShell) or `grep -m1 + sed` (bash) — no YAML parser dependency.

#### Parity Rule

Both implementations must remain in sync (Decision #3). When the skill list or install behavior changes, update `bin/dotfiles.ps1` and `shell/common.sh` together.

#### Destination Layout After Install

```
<target>/
└── .copilot/
    └── skills/
        ├── bootstrap-idempotency/
        │   └── SKILL.md
        └── dotfiles-cli-extension/
            └── SKILL.md
```

#### Idempotency

`Copy-Item -Recurse -Force` (PowerShell) and `cp -R` (bash) are used — existing skill files are overwritten. Skills are repo-owned and should not be user-edited in the target project.

### Rationale

- Skills live in the dotfiles repo as authoritative source. Projects consume them by copying into `.copilot/skills/` — the standard Copilot skills drop location.
- One command (`dotfiles skills install`) vs. manual `cp` reduces friction and makes the operation discoverable.
- Idempotency matches the repo's hard rule for all install operations.
- Default target = `$PWD`/`$(pwd)` is the most common case (install into current project root).

### Files Changed

| File | Change |
|------|--------|
| `bin/dotfiles.ps1` | Added `Invoke-Skills` function + `'skills'` dispatch case + updated help/usage |
| `shell/common.sh` | Added `skills)` case + updated `*)` usage line |
| `skills/bootstrap-idempotency/SKILL.md` | New skill document |
| `skills/dotfiles-cli-extension/SKILL.md` | New skill document |
| `docs/cheatsheet.md` | Added three `dotfiles skills` rows |
| `README.md` | Added skills section (English + Spanish) |

---

## #9 — 2026-06-02: Switch Versioning Decision

**Date:** 2026-06-02
**Author:** Switch
**Status:** Proposed

### Decision

Use a root `VERSION` file containing one SemVer value as the single source of truth for the dotfiles version. Keep human-readable release notes in root `CHANGELOG.md` using Keep a Changelog-style headings.

### Rationale

This keeps version lookup shell-agnostic, works before any package tooling is installed, and avoids coupling the repo to tags, package managers, or a release tool.

### Update behavior

`dotfiles update` in both PowerShell and bash/zsh captures the current version, runs `git pull --ff-only`, reads the new version, prints `dotfiles: vOLD → vNEW` or `dotfiles: vNEW (already up to date)`, prints the new changelog section when available, and reruns the platform installer idempotently so new bootstrap changes are applied.

---

## #8 — 2026-06-02: tank-phase4-done — Phase 4 Inference (bash/zsh) Complete

**Date:** 2026-06-02  
**Owner:** Tank  
**Phase:** 4 — `dotfiles agent "<query>"` inference for bash/zsh

### Files Changed

| File | Change |
|------|--------|
| `shell/lib/agent.sh` | Replaced PHASE 4 PLACEHOLDER with `_agent_build_prompt`, `_agent_postprocess`, and `dotfiles_agent` |
| `shell/common.sh` | Replaced PHASE 4 PLACEHOLDER stub; wired `dotfiles_agent "$subarg" "${extraflag:-}"` with `--run` pass-through; updated usage text |
| `.squad/agents/tank/history.md` | Appended Phase 4 learnings |

### Parity Confirmation with Trinity (Phase 3)

#### Prompt serialization — byte-for-byte match

| Contract item | Trinity (PS) | Tank (bash/zsh) |
|---|---|---|
| `{{SHELL_TYPE}}` | `"windows-powershell"` | `"unix-bash"` / `"unix-zsh"` (ZSH_VERSION check) |
| `{{TOOLS_BLOCK}}` | `"- {name}: {description}"` per tool, `"(none registered)"` if empty | identical via jq |
| `{{ALIASES_BLOCK}}` | `"- {key}: {_note} [win: …] [unix: …]"`, skip `_`-prefixed keys, omit absent brackets | identical via jq |
| System ChatML | `<\|im_start\|>system\n{TrimEnd}\n<\|im_end\|>\n` | `printf '<\|im_start\|>system\n%s\n<\|im_end\|>\n'` — trailing newlines stripped by `$()` |
| Few-shot pairs | `<\|im_start\|>{role}\n{content}\n<\|im_end\|>\n` each | identical via `jq -r` |
| User + assistant | `<\|im_start\|>user\n{q}\n<\|im_end\|>\n<\|im_start\|>assistant\n` | identical via `printf` |

#### llama-cli flags — exact match

```
"$ENGINE" -m "$MODEL" -f "$PROMPTFILE" --no-display-prompt -no-cnv --log-disable -n "$N_PREDICT" --temp "$TEMP"
```
Wrapped with `timeout "${TIMEOUT}s" ...`; temp file cleaned with `rm -f` at every exit path.

#### Post-processing — exact match

Same three steps as Trinity: strip `` ``` `` fence blocks (toggle on/off), trim whitespace, strip leading `$ ` or `> `, return first non-empty line.

#### Exit codes — exact match

| Code | Condition |
|------|-----------|
| 0 | Success |
| 1 | `# Cannot build:` prefix or empty output |
| 2 | Engine binary missing (`! -x $AGENT_ENGINE`) |
| 3 | No model file found |
| 4 | `timeout` exit 124 → mapped to 4 |

#### Clipboard — graceful degradation

Tries `clip.exe` (WSL), then `xclip -selection clipboard`, then `wl-copy`. All guarded with `command -v`; all wrapped `|| true`.

### Verification Results

- `bash -n shell/lib/agent.sh` → exit 0 ✓  
- `bash -n shell/common.sh` → exit 0 ✓  
- Engine-absent test: `dotfiles_agent "list files by size"` prints  
  `"Agent engine not installed. Run: dotfiles agent --setup"` and returns 2 ✓  
- Prompt dump confirmed: `{{SHELL_TYPE}}` → `unix-bash`, `{{TOOLS_BLOCK}}` → `(none registered)`,  
  `{{ALIASES_BLOCK}}` → all 34 alias entries with correct bracket omission (e.g. `explorer` has `[win: …]` only, no `[unix: …]`). ChatML structure verified head + tail. ✓  

### Notes

- `zsh -n` not available in Git Bash environment; code uses only POSIX constructs + `local` (supported by both bash 3.2+ and zsh 5+), `[ ]`, `${:-}`, `command -v` guards — no bashisms.
- Multi-line block substitution uses awk `ENVIRON[]` (POSIX) rather than `awk -v` (which rejects multi-line values per POSIX).

---

## #7 — 2026-06-02: Decision Record — Trinity Phase 3 Complete

**Date:** 2026-06-02  
**Author:** Trinity (PowerShell engineer)  
**Status:** Done — NOT committed

### Files Changed

| File | Change |
|------|--------|
| `powershell/modules/dotfiles-agent.psm1` | Added `Invoke-AgentQuery` (exported) + private helpers `_Build-AgentPrompt`, `_Post-ProcessAgentOutput`, `_Format-ProcArg`; updated `Export-ModuleMember` |
| `bin/dotfiles.ps1` | Replaced PHASE 3 PLACEHOLDER with real inference wiring in `Invoke-Agent`; updated usage message and .SYNOPSIS |

### Prompt Serialization Contract

> **Tank must reproduce this exactly in bash for cross-shell parity.**

#### Template fill (system-prompt.txt)

| Placeholder | Replacement |
|-------------|-------------|
| `{{SHELL_TYPE}}` | `windows-powershell` (literal string) |
| `{{TOOLS_BLOCK}}` | One line per tool: `"- {name}: {description}"`. Empty → `"(none registered)"` |
| `{{ALIASES_BLOCK}}` | One line per alias key (skip keys starting with `_`): `"- {key}: {_note} [win: {windows}] [unix: {unix}]"`. Omit `[win: ...]` when `windows` field absent. Omit `[unix: ...]` when `unix` field absent. |

#### ChatML envelope

```
<|im_start|>system
{filled-system-prompt}
<|im_end|>
<|im_start|>{role}
{content}
<|im_end|>
... (repeat for every object in few-shot.json)
<|im_start|>user
{query}
<|im_end|>
<|im_start|>assistant
```

- Line ending: `\n` (LF) throughout — use `\n` not `\r\n`.
- Encoding: UTF-8, **no BOM**.
- Prompt written to a temp file; passed via `-f` flag (avoids all shell quoting issues).
- The final line `<|im_start|>assistant\n` has NO closing tag — the model appends its completion here.

### llama-cli Invocation (build b9469)

```
llama-cli \
  -m <model_path> \
  -f <prompt_tempfile> \
  --no-display-prompt \
  -no-cnv \
  --log-disable \
  -n <n_predict> \
  --temp <temp>
```

- `-no-cnv`: disables built-in conversation wrapper → raw completion against our ChatML.
- `--no-display-prompt`: suppresses prompt echo from stdout.
- `--log-disable`: silences llama.cpp diagnostic chatter.
- `-n` / `--temp`: from `agent-config.json` `.defaults` (n_predict=80, temp=0).
- stderr is redirected away (`2>$null` or piped to null); only stdout is post-processed.

**Model resolution priority:**
`-Model` param → `$env:DOTFILES_AGENT_MODEL` → `PrimaryModel` (if exists) → `FallbackModel`

**Timeout resolution priority:**
`-TimeoutSeconds` param → `$env:DOTFILES_AGENT_TIMEOUT` → `agent-config.json` `.defaults.timeout_seconds` (60 s)

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success — command generated and printed |
| 1 | `# Cannot build:` response from model, or no output |
| 2 | Engine binary (`llama-cli.exe`) missing |
| 3 | No model `.gguf` file found |
| 4 | Inference timed out |

### Output Post-Processing

1. Strip ` ``` ` fenced blocks (and the ` ```lang ` line).
2. Take the FIRST non-empty line from remaining text.
3. Strip a leading `$ ` or `> ` shell-prompt marker (regex `^(\$ |> )`).
4. Trim surrounding whitespace.

### UX

- Default (no `--run`): prints command in Cyan; copies to clipboard via `Set-Clipboard` (guarded, never fatal).
- `--run`: prints command, then prompts `Execute? [y/N]` via `Read-Host`; on `y`/`Y` runs via `Invoke-Expression`.

### Verification

- Both files parse with 0 errors (`[Parser]::ParseFile`).
- `Import-Module dotfiles-agent; Get-Command -Module dotfiles-agent` lists `Invoke-AgentQuery`.
- `dotfiles agent "list files by size"` (engine absent) → prints red error, exits 2.
- Prompt dump (94 lines): system block with tools+aliases injected, 6 few-shot pairs, open assistant turn — ChatML well-formed.
