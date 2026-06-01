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
