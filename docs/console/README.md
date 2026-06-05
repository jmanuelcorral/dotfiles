# Working in the Console — Guide Index

[English](console.en.md) · [Español](console.es.md)

> This guide teaches you to **use** every tool this dotfiles repo provisions — not just install it.  
> If you're looking for the `dotfiles` CLI reference, see [`docs/commands/`](../commands/).

---

## Tool Inventory

| Tool | Replaces | One-liner | 🪟 Win | 🐧 Unix |
|---|---|---|:---:|:---:|
| **eza** | `ls` / `dir` | `ll` — long list with icons | ✅ | ✅ |
| **bat** | `cat` | `cat file.ts` — syntax-highlighted | ✅ | ✅ |
| **fd** | `find` | `find -e ts src/` — find TypeScript files | ✅ | ✅ |
| **ripgrep** | `grep` | `grep "TODO" -g "*.ts"` — fast search | ✅ | ✅ |
| **fzf** | interactive picker | `Ctrl+R` history · `Ctrl+T` file picker | ✅ | ✅ |
| **zoxide** | `cd` + bookmarks | `z proj` — jump to frecent dir | ✅ | ✅ |
| **delta** | git pager | `git diff` — side-by-side syntax diff | ✅ | ✅ |
| **jq** | manual JSON parsing | `jq '.name' package.json` | ✅ | ✅ |
| **yq** | manual YAML parsing | `yq '.services' docker-compose.yml` | ⚠️ WSL | ✅ |
| **duf** | `df` | `duf` — graphical disk usage | ⚠️ WSL | ✅ |
| **git** + aliases | — | `gl` · `gst` · `ga` · `gc` · `gd` · `gp` | ✅ | ✅ |
| **gh** | browser + GitHub | `gh pr create` · `gh run watch` | ✅ | ✅ |
| **oh-my-posh** | plain prompt | powers the prompt on Windows | ✅ | ❌ |
| **starship** | plain prompt | powers the prompt on Unix/WSL | ❌ | ✅ |
| **gsudo** | UAC dialogs | `sudo <cmd>` — inline elevation | ✅ | ❌ |
| **volta** | nvm / n | `volta install node@lts` · `volta pin node` | ✅ | ⚠️ |

> ⚠️ = available but not the primary platform; WSL = works inside WSL2 Linux.

---

## Guides

| Language | Link |
|---|---|
| 🇬🇧 English | [console.en.md](console.en.md) |
| 🇪🇸 Español | [console.es.md](console.es.md) |

---

## See Also

- [dotfiles CLI Reference](../commands/) — `dotfiles help`, `dotfiles explain`, `dotfiles agent`
- [Cheatsheet](../cheatsheet.md) — searchable quick-reference (`dotfiles help`)
- [Architecture](../ARCHITECTURE.md) — how profiles and aliases are wired
