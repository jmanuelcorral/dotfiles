# dotfiles

Portable terminal configuration for Windows (PowerShell 7+) and Unix (bash/zsh).

Clone once. Install once. Sync everywhere.

---

## Quick Start

### Windows (PowerShell)

```powershell
# One-liner: clone and install
irm https://raw.githubusercontent.com/josecorral/dotfiles/main/bootstrap/install.ps1 | iex
```

Or manually:
```powershell
git clone https://github.com/josecorral/dotfiles.git D:\gitrepos\personal\dotfiles
. D:\gitrepos\personal\dotfiles\bootstrap\install.ps1
```

### Linux / WSL / macOS

```bash
# One-liner: clone and install
curl -fsSL https://raw.githubusercontent.com/josecorral/dotfiles/main/bootstrap/install.sh | bash
```

Or manually:
```bash
git clone https://github.com/josecorral/dotfiles.git ~/dotfiles
~/dotfiles/bootstrap/install.sh
```

---

## What You Get

| Feature | Description |
|---------|-------------|
| **Linux-style aliases** | `ls`, `ll`, `grep`, `cat`, `touch` work in PowerShell |
| **Oh-My-Posh prompt** | Beautiful prompt with git status, time, etc. |
| **PSReadLine tuned** | History search, syntax highlighting, better keybindings |
| **Tab completions** | For git, gh, winget, scoop, and more |
| **Portable** | Works on any machine — just clone and install |
| **Your own tools** | Register scripts in `bin/` for easy access |
| **CLI help** | `dotfiles help` shows your most-used commands |

---

## Adding Your Own Tools

1. Put your script in `bin/`:
   ```
   bin/gituseswitch      # your custom script
   bin/mybackup.ps1
   ```

2. Register it:
   ```
   dotfiles register gituseswitch --description "Switch git user configs"
   ```

3. Now `dotfiles help` shows it, and it's in your PATH.

---

## Structure

```
powershell/     → PowerShell config (profile, aliases, prompt)
shell/          → Bash/Zsh config (bashrc, zshrc, common aliases)
shared/         → Cross-shell data (alias definitions, tool registry)
bin/            → Your personal scripts (added to PATH)
bootstrap/      → Install scripts (install.ps1, install.sh)
packages/       → Package lists (winget.json, scoop.json, apt.json)
docs/           → Documentation and cheatsheet
```

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the full design.

---

## Re-installing / Updating

The install scripts are **idempotent** — safe to run again:

```powershell
# Windows: re-run to pick up changes
. $env:DOTFILES\bootstrap\install.ps1
```

```bash
# Unix: re-run to pick up changes
$DOTFILES/bootstrap/install.sh
```

---

## Customizing

### Add a PowerShell module
Drop a `.ps1` file in `powershell/modules/` — it auto-loads.

### Add a shell alias
Edit `shared/aliases.json` — both PowerShell and bash/zsh pick it up.

### Add a package
Edit `packages/winget.json`, `packages/scoop.json`, or `packages/apt.json`.

---

## License

MIT — do whatever you want.
