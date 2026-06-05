# dotfiles CLI — Command Reference

[English](commands.en.md) · [Español](commands.es.md)

> **Quick tip:** You already have interactive help built in.  
> Run `dotfiles help` to launch a fuzzy-search browser over every cheatsheet entry and registered tool.  
> Run `dotfiles explain <name>` (e.g. `dotfiles explain ll`) to get an instant, offline definition of any alias or registered script.

---

## Command Quick-Reference

| Command | What it does | Windows | Unix |
|---|---|:---:|:---:|
| `dotfiles help [query]` | Browse the cheatsheet; filter by keyword or launch fzf | ✅ | ✅ |
| `dotfiles list` | List every tool registered in `bin/` | ✅ | ✅ |
| `dotfiles version` | Show version + git commit | ✅ | ✅ |
| `dotfiles register <name>` | Register (or update) a `bin/` script in `shared/tools.json` | ✅ | ⚠️ ¹ |
| `dotfiles update` | Pull latest commits, rerun installer, reload profile | ✅ | ✅ |
| `dotfiles edit` | Open the dotfiles repo in your editor | ✅ | ✅ |
| `dotfiles explain <name>` | Offline alias/tool lookup → falls back to `--help` | ✅ | ✅ |
| `dotfiles agent --setup` | Download llama-cli engine + Qwen2.5-Coder model | ✅ | ✅ |
| `dotfiles agent "<query>"` | Generate a shell command via local AI | ✅ | ✅ |
| `dotfiles agent "<query>" --run` | Generate and optionally execute | ✅ | ✅ |
| `dotfiles skills list` | List available skills | ✅ | ✅ |
| `dotfiles skills path` | Print the `skills/` directory path | ✅ | ✅ |
| `dotfiles skills install [target]` | Copy skills into `<target>/.copilot/skills/` | ✅ | ✅ |

> ¹ `register` is **PowerShell-only** on Unix it prints a message directing you to the PowerShell CLI or to edit `shared/tools.json` directly.

---

## Guides

| Language | Link |
|---|---|
| 🇬🇧 English | [commands.en.md](commands.en.md) |
| 🇪🇸 Español | [commands.es.md](commands.es.md) |

---

## See Also

- [Working in the Console](../console/) — hands-on guide to every tool this repo provisions (eza, bat, fd, rg, fzf, zoxide, delta, jq, gh, volta…)
- [Cheatsheet](../cheatsheet.md) — quick command reference powered by `dotfiles help`
- [Repository README](../../README.md) — install instructions and overview
- [Architecture](../ARCHITECTURE.md) — load contract and directory layout
