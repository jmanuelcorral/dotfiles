# skills/ — Portable Agent Skill Guides

Portable SKILL.md guides that capture architectural and domain knowledge so any AI agent can extend this repo correctly. Skills are project-agnostic where possible and can be installed into any project.

---

## Skill Index

| Skill | What it teaches | Owner |
|---|---|---|
| [`dotfiles-architecture`](dotfiles-architecture/SKILL.md) | Load contract, thin-stub pattern, `profile.ps1` dispatch order, module boundaries, idempotency rules, Windows/Unix parity | Morpheus |
| [`powershell-config`](powershell-config/SKILL.md) | PSReadLine options + VT guard, Oh My Posh repo-local theme, alias functions vs `Set-Alias`, module import guards, completers | Trinity |
| [`shell-parity`](shell-parity/SKILL.md) | POSIX-first rules, bash/zsh divergence patterns, `common.sh` constraints, Starship WSL prompt, apt quirk workarounds | Tank |
| [`packages-and-tooling`](packages-and-tooling/SKILL.md) | winget/scoop/apt JSON schemas, idempotent install patterns, tool guard strategy, recommended CLI tool stack | Oracle / Switch |
| [`bootstrap-idempotency`](bootstrap-idempotency/SKILL.md) | Marker-guard pattern, timestamped backup strategy, one-liner self-bootstrap, re-run safety checklist | Switch |
| [`dotfiles-cli-extension`](dotfiles-cli-extension/SKILL.md) | Adding subcommands to the `dotfiles` CLI in both `bin/dotfiles.ps1` and `shell/common.sh`, fzf fallback pattern, `shared/tools.json` integration | Switch |

---

## How to Install

Skills are installed into a target project's `.copilot/skills/` directory, making them available to GitHub Copilot agents working in that project.

### List available skills

```sh
dotfiles skills list
```

### Install all skills into the current project

```sh
dotfiles skills install
# Copies all skills/ entries into ./.copilot/skills/
```

### Install a specific skill into a target project

```sh
dotfiles skills install dotfiles-architecture
# Installs skills/dotfiles-architecture/ → ./.copilot/skills/dotfiles-architecture/

dotfiles skills install powershell-config --target /path/to/other-project
# Installs into /path/to/other-project/.copilot/skills/powershell-config/
```

Skills already present in the target project are skipped unless `--force` is passed.

---

## Notes

- Skills use standard frontmatter (`name`, `description`, `domain`, `confidence`, `source`) matching the `.copilot/skills/` convention.
- The full planned set (listed above) is being authored by the team. Skills marked with an existing file link are complete; others are in progress.
- Skills live in `skills/` (repo root) rather than `.copilot/skills/` so they can be version-controlled with the dotfiles repo and shared outward, not just inward.
