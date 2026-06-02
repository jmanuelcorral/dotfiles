# dotfiles

[English](#english) · [Español](#español)

---

<a id="english"></a>

## English

Portable terminal configuration for **Windows (PowerShell 7+)** and **Unix/WSL/macOS (bash/zsh)**.

Clone once. Install once. Sync everywhere.

---

### Requirements

| Requirement | Notes |
|---|---|
| **PowerShell 7+** | Windows: [install from Microsoft](https://aka.ms/powershell) |
| **Git** | Must be on PATH before running the installer |
| **Nerd Font — MesloLGS NF** | Required for icons and the Oh My Posh prompt to render correctly |

> **Font note:** The Windows installer (`install.ps1`) installs **Meslo Nerd Font** automatically via `oh-my-posh font install Meslo` (or Scoop as fallback). After installation you **must** set the font in your terminal:
>
> - **Windows Terminal** → Settings → Profile → Appearance → Font face → `MesloLGS NF`
> - **VS Code integrated terminal** → `"terminal.integrated.fontFamily": "MesloLGS NF"`

---

### Quick Install

> **Prerequisite:** Git must be installed and on your PATH before running the one-liner — it is the only dependency the installer cannot self-install. [Download Git](https://git-scm.com/download/win).

#### Windows (PowerShell 7+)

```powershell
# One-liner
irm https://raw.githubusercontent.com/jmanuelcorral/dotfiles/master/bootstrap/install.ps1 | iex
```

Manual clone + run:
```powershell
git clone https://github.com/jmanuelcorral/dotfiles.git $HOME\dotfiles
. $HOME\dotfiles\bootstrap\install.ps1
```

#### Linux / WSL / macOS

```bash
# One-liner
curl -fsSL https://raw.githubusercontent.com/jmanuelcorral/dotfiles/master/bootstrap/install.sh | bash
```

Manual clone + run:
```bash
git clone https://github.com/jmanuelcorral/dotfiles.git ~/dotfiles
~/dotfiles/bootstrap/install.sh
```

---

### What You Get

| Feature | Description |
|---|---|
| **Oh My Posh prompt** | Tokyo Night theme with git status, time, exit code |
| **Linux-style aliases** | `ls`, `ll`, `grep`, `cat`, `touch` work in PowerShell |
| **Modern CLI tools** | `eza`, `bat`, `zoxide`, `fd`, `fzf`, `ripgrep` installed & aliased |
| **PSReadLine tuned** | History search, syntax highlighting, better keybindings |
| **Tab completions** | For `git`, `gh`, `winget`, `scoop`, and more |
| **WSL bash/zsh parity** | Shared aliases and config for bash & zsh |
| **`dotfiles` CLI helper** | `dotfiles help|list|version|register|update|edit` |
| **Extensible** | Register your own scripts in one command |
| **Idempotent** | Safe to re-run — skips what's already installed |

---

### Registering Your Own Tooling

Use `dotfiles register` to add your personal scripts to PATH and the help index:

```powershell
# 1. Drop your script in bin/
#    e.g. bin/gituseswitch

# 2. Register it
dotfiles register gituseswitch --description "Switch git user configs"

# 3. It's now on PATH and shows in dotfiles help
dotfiles help
```

Registered tools survive re-installs and are listed by `dotfiles list`.

---

### Re-installing / Updating

The install scripts are **idempotent** — safe to re-run at any time:

Check the installed dotfiles version:

```powershell
dotfiles version
```

Update with a fast-forward pull, version report, changelog snippet, and idempotent bootstrap re-run:

```powershell
dotfiles update
```

```powershell
# Windows
. $env:DOTFILES\bootstrap\install.ps1
```

```bash
# Unix / WSL
$DOTFILES/bootstrap/install.sh
```

---

### Customizing

| What | How |
|---|---|
| Add a PowerShell module | Drop a `.ps1` file in `powershell/modules/` — auto-loads |
| Add a shell alias | Edit `shared/aliases.json` — picked up by both shells |
| Add a package | Edit `packages/winget.json`, `packages/scoop.json`, or `packages/apt.json` |

---

### Repo Structure

```
dotfiles/
├── bootstrap/          # Install scripts (install.ps1 · install.sh)
├── bin/                # Personal scripts added to PATH (dotfiles.ps1, gituseswitch, …)
├── powershell/         # PowerShell config: profile, modules, themes
│   └── themes/         # Oh My Posh theme (dotfiles.omp.json — Tokyo Night)
├── shell/              # Bash/Zsh config (bashrc, zshrc, common aliases)
├── shared/             # Cross-shell data: aliases.json, tools.json
├── packages/           # Package lists: winget.json · scoop.json · apt.json
└── docs/               # Documentation, cheatsheet, research notes
```

---

### Credits & Sources

- **Oh My Posh** — prompt engine: <https://ohmyposh.dev>
- **Nerd Fonts / Meslo Nerd Font** — icon-patched fonts: <https://www.nerdfonts.com> (OFL licence)
- **Research basis** — tooling decisions documented in [`docs/research/terminal-tooling-2026.md`](docs/research/terminal-tooling-2026.md)
- Modern CLI tools: [eza](https://github.com/eza-community/eza), [bat](https://github.com/sharkdp/bat), [zoxide](https://github.com/ajeetdsouza/zoxide), [fd](https://github.com/sharkdp/fd), [fzf](https://github.com/junegunn/fzf), [ripgrep](https://github.com/BurntSushi/ripgrep)

---

### License

MIT — do whatever you want.

---

---

<a id="español"></a>

## Español

Configuración de terminal portable para **Windows (PowerShell 7+)** y **Unix/WSL/macOS (bash/zsh)**.

Clona una vez. Instala una vez. Sincroniza en cualquier máquina.

---

### Requisitos

| Requisito | Notas |
|---|---|
| **PowerShell 7+** | Windows: [instalar desde Microsoft](https://aka.ms/powershell) |
| **Git** | Debe estar en el PATH antes de ejecutar el instalador |
| **Nerd Font — MesloLGS NF** | Necesaria para que los iconos y el prompt de Oh My Posh se muestren correctamente |

> **Nota sobre la fuente:** El instalador de Windows (`install.ps1`) instala **Meslo Nerd Font** automáticamente mediante `oh-my-posh font install Meslo` (o Scoop como alternativa). Tras la instalación **debes** configurar la fuente en tu terminal:
>
> - **Windows Terminal** → Configuración → Perfil → Apariencia → Fuente → `MesloLGS NF`
> - **Terminal integrada de VS Code** → `"terminal.integrated.fontFamily": "MesloLGS NF"`

---

### Instalación rápida

> **Prerequisito:** Git debe estar instalado y en el PATH antes de ejecutar el comando — es la única dependencia que el instalador no puede instalar por sí mismo. [Descargar Git](https://git-scm.com/download/win).

#### Windows (PowerShell 7+)

```powershell
# Una sola línea
irm https://raw.githubusercontent.com/jmanuelcorral/dotfiles/master/bootstrap/install.ps1 | iex
```

Clonar manualmente y ejecutar:
```powershell
git clone https://github.com/jmanuelcorral/dotfiles.git $HOME\dotfiles
. $HOME\dotfiles\bootstrap\install.ps1
```

#### Linux / WSL / macOS

```bash
# Una sola línea
curl -fsSL https://raw.githubusercontent.com/jmanuelcorral/dotfiles/master/bootstrap/install.sh | bash
```

Clonar manualmente y ejecutar:
```bash
git clone https://github.com/jmanuelcorral/dotfiles.git ~/dotfiles
~/dotfiles/bootstrap/install.sh
```

---

### Qué obtienes

| Característica | Descripción |
|---|---|
| **Prompt Oh My Posh** | Tema Tokyo Night con estado git, hora y código de salida |
| **Alias estilo Linux** | `ls`, `ll`, `grep`, `cat`, `touch` funcionan en PowerShell |
| **Herramientas CLI modernas** | `eza`, `bat`, `zoxide`, `fd`, `fzf`, `ripgrep` instaladas y con alias |
| **PSReadLine optimizado** | Búsqueda en historial, resaltado de sintaxis, atajos mejorados |
| **Completado con Tab** | Para `git`, `gh`, `winget`, `scoop` y más |
| **Paridad bash/zsh en WSL** | Alias y config compartidos para bash y zsh |
| **Herramienta CLI `dotfiles`** | `dotfiles help|list|version|register|update|edit` |
| **Extensible** | Registra tus propios scripts con un solo comando |
| **Idempotente** | Seguro para volver a ejecutar — omite lo que ya está instalado |

---

### Registrar tus propias herramientas

Usa `dotfiles register` para añadir tus scripts personales al PATH y al índice de ayuda:

```powershell
# 1. Coloca tu script en bin/
#    p. ej. bin/gituseswitch

# 2. Regístralo
dotfiles register gituseswitch --description "Cambiar configuraciones de usuario de git"

# 3. Ya está en el PATH y aparece en dotfiles help
dotfiles help
```

Las herramientas registradas sobreviven a las reinstalaciones y se listan con `dotfiles list`.

---

### Reinstalar / Actualizar

Los scripts de instalación son **idempotentes** — seguros para volver a ejecutar en cualquier momento:

Comprueba la versión instalada de dotfiles:

```powershell
dotfiles version
```

Actualiza con fast-forward pull, reporte de versión, extracto del changelog y reinstalación idempotente:

```powershell
dotfiles update
```

```powershell
# Windows
. $env:DOTFILES\bootstrap\install.ps1
```

```bash
# Unix / WSL
$DOTFILES/bootstrap/install.sh
```

---

### Personalización

| Qué | Cómo |
|---|---|
| Añadir un módulo de PowerShell | Coloca un archivo `.ps1` en `powershell/modules/` — se carga automáticamente |
| Añadir un alias de shell | Edita `shared/aliases.json` — ambos shells lo recogen |
| Añadir un paquete | Edita `packages/winget.json`, `packages/scoop.json` o `packages/apt.json` |

---

### Estructura del repositorio

```
dotfiles/
├── bootstrap/          # Scripts de instalación (install.ps1 · install.sh)
├── bin/                # Scripts personales añadidos al PATH (dotfiles.ps1, gituseswitch, …)
├── powershell/         # Config de PowerShell: perfil, módulos, temas
│   └── themes/         # Tema Oh My Posh (dotfiles.omp.json — Tokyo Night)
├── shell/              # Config Bash/Zsh (bashrc, zshrc, alias comunes)
├── shared/             # Datos entre shells: aliases.json, tools.json
├── packages/           # Listas de paquetes: winget.json · scoop.json · apt.json
└── docs/               # Documentación, cheatsheet, notas de investigación
```

---

### Créditos y fuentes

- **Oh My Posh** — motor de prompt: <https://ohmyposh.dev>
- **Nerd Fonts / Meslo Nerd Font** — fuentes con iconos: <https://www.nerdfonts.com> (licencia OFL)
- **Base de investigación** — decisiones de herramientas documentadas en [`docs/research/terminal-tooling-2026.md`](docs/research/terminal-tooling-2026.md)
- Herramientas CLI modernas: [eza](https://github.com/eza-community/eza), [bat](https://github.com/sharkdp/bat), [zoxide](https://github.com/ajeetdsouza/zoxide), [fd](https://github.com/sharkdp/fd), [fzf](https://github.com/junegunn/fzf), [ripgrep](https://github.com/BurntSushi/ripgrep)

---

### Licencia

MIT — haz lo que quieras.
