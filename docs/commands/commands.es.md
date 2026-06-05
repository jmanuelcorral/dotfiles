# dotfiles CLI — Guía para Desarrolladores (Español)

> Referencia de versión: **v1.0.0** (ver archivo `VERSION` en la raíz)  
> Fecha: 2026-06-05  
> [← Volver al índice](README.md) · [English](commands.en.md)

---

## Tabla de contenidos

1. [Introducción](#introducción)
2. [Primeros pasos y descubrimiento](#primeros-pasos-y-descubrimiento)
3. [Comandos](#comandos)
   - [help](#help)
   - [list](#list)
   - [version](#version)
   - [register](#register)
   - [update](#update)
   - [edit](#edit)
   - [explain](#explain)
   - [agent](#agent)
   - [skills](#skills)
4. [Flujos de trabajo / Recetas](#flujos-de-trabajo--recetas)
5. [Referencias cruzadas](#referencias-cruzadas)

---

## Introducción

El comando `dotfiles` es el punto de entrada único para gestionar tu entorno de terminal una vez que el repositorio está instalado. Está disponible en **ambas** shells:

| Shell | Ubicación | Cómo se carga |
|---|---|---|
| PowerShell 7+ | `bin/dotfiles.ps1` | `bin/` está en `$env:PATH` (añadido por `powershell/profile.ps1`) |
| bash / zsh | `shell/common.sh` — función `dotfiles()` | `common.sh` es cargado por `bash/bashrc.sh` y `zsh/zshrc.sh` |

### Principio de paridad

Cada subcomando está disponible en **ambas** plataformas — PowerShell y bash/zsh — con sintaxis idéntica y el mismo comportamiento general. La única excepción es `register`, que es una operación exclusiva de PowerShell en Unix (ver [register](#register)).

Las diferencias entre plataformas se destacan en cada sección con un bloque de **Notas de plataforma**.

---

## Primeros pasos y descubrimiento

### `dotfiles help` — tu manual integrado

```powershell
dotfiles help
```

Sin argumentos y con **fzf instalado**, lanza un navegador fuzzy interactivo sobre la hoja de referencia completa más tus herramientas registradas. Escribe para filtrar; pulsa Enter para seleccionar una línea; pulsa Esc para salir.

```powershell
dotfiles help git       # filtra a líneas que contengan "git"
dotfiles help stash     # encuentra todas las entradas de stash al instante
```

Sin fzf, se imprime la hoja de referencia completa con encabezados resaltados por color.

### `dotfiles explain` — consulta offline de alias y herramientas

```powershell
dotfiles explain ll     # ¿a qué se expande `ll` en Windows vs Unix?
dotfiles explain gst    # explica el alias git `gst`
```

Esto es **completamente offline** — no requiere ningún modelo. Lee directamente `shared/aliases.json` y `shared/tools.json`. Si el nombre no está en ninguno de los dos registros, ejecuta `<cmd> --help` y muestra las primeras 20 líneas.

---

## Comandos

---

### `help`

**Resumen en una línea:** Navega y busca en la hoja de referencia de comandos y las herramientas registradas.

#### Sintaxis

```
dotfiles help
dotfiles help <consulta>
```

#### Qué hace

Combina `docs/cheatsheet.md` con una sección **"Your Registered Tools"** generada en tiempo real desde `shared/tools.json`, y luego:

- **Con `<consulta>`** — filtra el contenido combinado a las líneas que coincidan con la consulta (coincidencia de subcadena sin distinción de mayúsculas en PowerShell, `rg`/`grep -i` en bash/zsh).
- **Sin consulta + fzf presente** — canaliza todas las líneas a `fzf` para búsqueda fuzzy interactiva.
- **Sin consulta, sin fzf** — imprime el contenido completo con encabezados en color (PowerShell) o mediante `bat`/`cat` (bash/zsh).

#### Ejemplos

```powershell
# Navegación fuzzy interactiva (requiere fzf)
dotfiles help

# Filtrar a entradas relacionadas con git
dotfiles help git

# Encontrar todas las entradas que contienen "stash"
dotfiles help stash
```

Salida esperada (filtrada):

```
| `git stash`          | Stash uncommitted changes       |
| `git stash pop`      | Restore last stash              |
| `git stash list`     | Show all stashes                |
```

#### Notas de plataforma

| Característica | PowerShell | bash/zsh |
|---|---|---|
| Renderizador de respaldo | `Write-Host` con colores | `bat` (si está instalado) o `cat` |
| Motor de grep | `-match` de PowerShell | `rg` (preferido) o `grep -i` |
| Integración fzf | igual | igual |

#### Consejos

- Instala `fzf` para la mejor experiencia — convierte `dotfiles help` en una paleta de comandos con búsqueda.
- `dotfiles help <tema>` es más rápido que hacer grep a la hoja de referencia manualmente.

---

### `list`

**Resumen en una línea:** Lista todas las herramientas que has registrado en `bin/`.

#### Sintaxis

```
dotfiles list
```

#### Qué hace

Lee `shared/tools.json` e imprime cada herramienta registrada con su nombre, descripción y ruta en `bin/`.

- En **PowerShell**: formateado con columnas alineadas y color (nombre en blanco, ruta en gris oscuro).
- En **bash/zsh**: usa `jq` + `column` para salida alineada; recurre a `grep` cuando jq no está disponible.

Si aún no hay herramientas registradas, imprime un consejo para usar `dotfiles register`.

#### Ejemplos

```powershell
dotfiles list
```

Salida esperada (PowerShell):

```
Registered tools in bin/

  gituseswitch            Switch git user identity
                          → bin/gituseswitch
```

```bash
# bash/zsh
dotfiles list
```

Salida esperada (bash):

```
gituseswitch    Switch git user identity
```

#### Notas de plataforma

- En bash/zsh, la alineación de la salida requiere `column` (estándar en la mayoría de Linux/macOS). Si tanto `jq` como `column` están ausentes, los nombres se muestran uno por línea.
- Una lista de herramientas vacía es normal tras una instalación reciente antes de ejecutar cualquier comando `register`.

---

### `version`

**Resumen en una línea:** Muestra la versión actual de dotfiles y el hash del commit de git.

#### Sintaxis

```
dotfiles version
```

#### Qué hace

Lee la versión del archivo `VERSION` en la raíz del repositorio (una línea SemVer) y añade el SHA corto de git cuando el repositorio está disponible. Nunca codifica una cadena de versión — siempre la lee desde el disco.

#### Ejemplos

```powershell
dotfiles version
# dotfiles v1.0.0 (abc1234)
```

```bash
dotfiles version
# dotfiles v1.0.0 (abc1234)
```

Si el repositorio es un zip extraído sin historial de git:

```
dotfiles v1.0.0
```

#### Notas de plataforma

Comportamiento idéntico en ambas shells.

---

### `register`

**Resumen en una línea:** Registra (o actualiza) un script en `bin/` guardando sus metadatos en `shared/tools.json`.

#### Sintaxis

```powershell
# Solo en PowerShell
dotfiles register <nombre>
dotfiles register <nombre> -Description "Descripción corta"
```

#### Qué hace

1. Comprueba si `bin/<nombre>` o `bin/<nombre>.ps1` existe en el disco (advierte pero continúa si no se encuentra).
2. Busca el nombre de la herramienta en `shared/tools.json`.
3. **Upsert**: si el nombre ya existe, actualiza su descripción y ruta; si no, añade una nueva entrada.
4. Guarda el JSON actualizado en `shared/tools.json` (UTF-8).

Tras el registro, la herramienta aparece en `dotfiles list`, en `dotfiles help` (bajo "Your Registered Tools") y es localizable con `dotfiles explain`.

#### Ejemplos

```powershell
# Registrar un nuevo script (el archivo debe estar en bin/)
dotfiles register gituseswitch -Description "Cambiar identidad de usuario git"
#   ✓ Registered: gituseswitch
#   → shared/tools.json updated

# Volver a registrar para actualizar la descripción (idempotente)
dotfiles register gituseswitch -Description "Cambiar identidad git (actualizado)"
#   ✓ Updated   : gituseswitch
#   → shared/tools.json updated

# Registrar sin descripción (el campo quedará vacío)
dotfiles register myscript
```

#### Notas de plataforma

| | PowerShell | bash/zsh |
|---|---|---|
| `register` disponible | ✅ Sí | ❌ No |
| Comportamiento en Unix | — | Imprime error; sugiere usar la CLI de PowerShell o editar `shared/tools.json` directamente |

En Unix:

```bash
dotfiles register myscript
# dotfiles register: use the PowerShell CLI on Windows or edit shared/tools.json directly.
```

**¿Por qué?** El registro escribe JSON con lógica de upsert implementada en el módulo de PowerShell. En Unix, edita `shared/tools.json` directamente siguiendo el esquema:

```json
{
  "tools": [
    {
      "name": "myscript",
      "path": "bin/myscript",
      "description": "Lo que hace"
    }
  ]
}
```

#### Consejos

- El flag `-Description` es opcional, pero proporcionarlo hace que `dotfiles help`, `dotfiles list` y `dotfiles explain` sean mucho más útiles.
- Usa `dotfiles explain <nombre>` justo después de registrar para confirmar que la entrada se ve correctamente.

---

### `update`

**Resumen en una línea:** Actualiza al último commit, reporta cambios de versión, re-ejecuta el instalador y recarga el perfil.

#### Sintaxis

```
dotfiles update
```

#### Qué hace

1. Registra la **versión antigua** desde `VERSION`.
2. Ejecuta `git pull --ff-only origin <rama-actual>` dentro de la raíz del repositorio (solo fast-forward — sin rebase, sin reescrituras inesperadas del historial).
3. Lee la **nueva versión** desde `VERSION`.
4. Reporta: `dotfiles: vANTIGUA → vNUEVA` si hubo actualización, o `dotfiles: vNUEVA (already up to date)` si no hubo cambios.
5. Si la versión cambió, imprime la sección correspondiente de `CHANGELOG.md`.
6. Re-ejecuta el instalador de plataforma (`bootstrap/install.ps1` o `bootstrap/install.sh`) — idempotente, seguro de re-ejecutar siempre.
7. Recarga el perfil de la shell (`$PROFILE` en PowerShell; `exec bash`/`exec zsh` en Unix).

#### Ejemplos

```powershell
dotfiles update
# Pulling latest dotfiles from origin...
# dotfiles: v1.0.0 → v1.1.0
#
# Changelog for v1.1.0
# ### Added
# - dotfiles skills install command
# Re-running installer to apply updates...
# Reloading $PROFILE...
# Done.
```

Ya actualizado:

```powershell
dotfiles update
# Pulling latest dotfiles from origin...
# dotfiles: v1.0.0 (already up to date)
```

#### Notas de plataforma

| Paso | PowerShell | bash/zsh |
|---|---|---|
| Instalador | `bootstrap/install.ps1` | `bootstrap/install.sh` |
| Recarga del perfil | `. $PROFILE` (dot-source) | `exec bash` o `exec zsh` |

#### Problemas comunes

- Si el pull falla (historial divergente, conflictos de merge), `update` se interrumpe — los pasos del instalador y la recarga se omiten. Resuelve el conflicto manualmente con `git status` dentro de `$DOTFILES`.
- `--ff-only` significa que tus commits locales no deben conflictuar con los del upstream. Si tienes commits locales, haz rebase o merge manualmente primero.

---

### `edit`

**Resumen en una línea:** Abre el repositorio dotfiles completo en tu editor.

#### Sintaxis

```
dotfiles edit
```

#### Qué hace

Detecta un editor por orden de prioridad y abre el directorio raíz del repositorio:

**PowerShell:**

1. `$env:EDITOR` (si está definido)
2. `code` (VS Code, si está en PATH)
3. `notepad++` (si está en PATH)
4. `notepad` (siempre disponible en Windows)

**bash/zsh:**

1. `$EDITOR` (si está definido)
2. `$VISUAL` (si está definido)
3. `vi` (fallback)

#### Ejemplos

```powershell
dotfiles edit
# Opening dotfiles in 'code'...
```

```bash
dotfiles edit
# (abre $EDITOR con la ruta $DOTFILES)
```

#### Notas de plataforma

| | PowerShell | bash/zsh |
|---|---|---|
| Editor preferido | VS Code (`code`) | `$EDITOR` / `$VISUAL` |
| Fallback | `notepad` | `vi` |

#### Consejos

- Define `$env:EDITOR = 'code'` (PowerShell) o `export EDITOR=nvim` (bash/zsh) en tu perfil para controlar qué editor se abre.
- `dotfiles edit` abre la **raíz** del repositorio — perfecto para navegar todos los archivos de configuración a la vez en una vista de árbol.

---

### `explain`

**Resumen en una línea:** Muestra la definición y las formas para ambas shells de cualquier alias o herramienta registrada — completamente offline.

#### Sintaxis

```
dotfiles explain <alias-o-herramienta>
```

#### Qué hace

Busca en tres fuentes en orden, deteniéndose en la primera coincidencia:

1. **`shared/aliases.json`** — si el nombre es una clave en el objeto `aliases`, imprime el `_note`, el valor `windows` y el valor `unix` juntos.
2. **`shared/tools.json`** — si el nombre coincide con una herramienta registrada, imprime su descripción y ruta en `bin/`.
3. **`<cmd> --help`** — si el nombre se encuentra en PATH pero no en ninguno de los dos registros, ejecuta `<nombre> --help` y muestra las primeras 20 líneas.

Si no se encuentra nada, sugiere probar `dotfiles help <nombre>`.

> **No se requiere modelo.** `explain` es 100% offline — nunca invoca el agente de IA.

#### Ejemplos

```powershell
# Explicar un alias de aliases.json
dotfiles explain ll

#   ll — Long listing with hidden files
#
#   Windows (PowerShell):
#     eza -la --icons --group-directories-first | Get-ChildItem -Force
#
#   Unix (bash/zsh):
#     eza -la --icons --group-directories-first | ls -la
```

```powershell
# Explicar un alias de git
dotfiles explain gst

#   gst — (detalle del alias desde aliases.json)
#
#   Windows (PowerShell):
#     git status
#
#   Unix (bash/zsh):
#     git status
```

```powershell
# Explicar una herramienta registrada
dotfiles explain gituseswitch

#   gituseswitch — Switch git user identity
#   Path: bin/gituseswitch
```

```powershell
# Recurre a --help para comandos no registrados
dotfiles explain rg

#   'rg' not in registry — showing --help output:
#
#   ripgrep 14.x.x ...
#   ...
```

#### Notas de plataforma

| Característica | PowerShell | bash/zsh |
|---|---|---|
| Análisis JSON | `ConvertFrom-Json` | `jq` (preferido) o fallback con `grep`/`sed` |
| Salida | `Write-Host` con colores | `echo` / `printf` |

Sin `jq` en Unix, el fallback con grep/sed para aliases.json es heurístico — instala `jq` para una salida confiable.

#### Consejos

- `dotfiles explain <alias>` es la forma más rápida de recordar a qué se expande un alias corto como `gl` o `gd`.
- También funciona para cualquier nombre de alias definido en `shared/aliases.json`, aunque estés en la plataforma opuesta.

---

### `agent`

**Resumen en una línea:** Asistente de IA local que genera comandos de shell a partir de lenguaje natural — completamente offline después de la configuración inicial.

#### Sintaxis

```
dotfiles agent --setup
dotfiles agent --setup --fallback
dotfiles agent "<consulta>"
dotfiles agent "<consulta>" --run
```

#### Qué hace

El subcomando `agent` usa un **motor de inferencia local autocontenido** — sin daemon, sin API en la nube, sin Python requerido. Ejecuta `llama-cli` como un subproceso de un solo uso (termina cuando acaba).

##### `--setup` — descarga inicial

Descarga e instala:
- El binario CPU de `llama-cli` desde los Releases de GitHub de `ggml-org/llama.cpp` (tag `b9469`).
- El modelo `Qwen2.5-Coder-1.5B-Instruct Q4_K_M` (~1 GB) desde HuggingFace.

Todo se almacena bajo `cache/` dentro de la raíz del repositorio (en .gitignore):

```
cache/
  bin/
    llama-cli.exe       (Windows x64)
    ggml.dll
    llama.dll
  models/
    qwen2.5-coder-1.5b-instruct-q4_k_m.gguf
```

En **Windows**, el script de configuración llama a `Unblock-File` en los ejecutables extraídos para eliminar la marca de zona de SmartScreen.

##### `--setup --fallback` — modelo más ligero

Igual que `--setup` pero descarga el modelo más pequeño **Qwen2.5-Coder-0.5B** (~469 MB) en su lugar. Útil en máquinas con ≤4 GB de RAM o almacenamiento lento. El tiempo de arranque en frío baja a ~3–5 s.

##### `"<consulta>"` — generar un comando

Construye un prompt a partir de tu consulta más contexto de `shared/aliases.json` y `shared/tools.json`, luego invoca `llama-cli` como subproceso. El comando de shell generado se imprime en la salida estándar.

**Arranque en frío:** ~5–8 s en una CPU de laptop moderna (sin caché caliente — el proceso arranca desde cero en cada llamada).

##### `"<consulta>" --run` — generar y ejecutar opcionalmente

Igual que lo anterior, pero después de generar el comando, pide confirmación antes de ejecutarlo. Puedes revisar el comando sugerido antes de que se ejecute.

#### Ejemplos

```powershell
# Configuración inicial (modelo primario, ~1 GB de descarga)
dotfiles agent --setup

# Modelo más ligero para máquinas con poca RAM
dotfiles agent --setup --fallback

# Generar un comando
dotfiles agent "listar todos los archivos .ps1 modificados en los últimos 7 días"
# Sugerido: Get-ChildItem -Recurse -Filter *.ps1 | Where-Object LastWriteTime -gt (Get-Date).AddDays(-7)

# Generar y ejecutar opcionalmente
dotfiles agent "encontrar todos los comentarios TODO en este repositorio" --run
# Sugerido: rg "TODO" .
# Run this command? [y/N]
```

```bash
# bash/zsh — misma sintaxis
dotfiles agent --setup
dotfiles agent "encontrar archivos grandes de más de 100MB" --run
# Sugerido: find . -size +100M -type f
# Run this command? [y/N]
```

#### Análisis detallado del agente

| Propiedad | Valor |
|---|---|
| Motor | `llama-cli` (`ggml-org/llama.cpp`, tag `b9469`) |
| Modelo primario | Qwen2.5-Coder-1.5B-Instruct Q4_K_M (~1.066 MB) |
| Modelo de respaldo | Qwen2.5-Coder-0.5B-Instruct Q4_K_M (~469 MB) |
| Licencia del motor | MIT |
| Licencia del modelo | Apache 2.0 |
| Daemon requerido | ❌ No — subproceso de un solo uso |
| Python requerido | ❌ No |
| Red tras la configuración | ❌ Completamente offline |
| Arranque en frío | ~5–8 s (primario), ~3–5 s (respaldo) |
| Tokens de salida | 80 (configurable en `shared/agent-config.json`) |

Estructura del caché (todo en .gitignore bajo `cache/`):

```
cache/bin/      → binario llama-cli + librerías compartidas
cache/models/   → archivo(s) de modelo GGUF
```

#### Notas de plataforma

| | Windows PowerShell | bash/zsh (Linux/WSL/macOS) |
|---|---|---|
| Recurso del motor | `llama-b9469-bin-win-cpu-x64.zip` | `llama-b9469-bin-ubuntu-x64.tar.gz` |
| Nombre del binario | `llama-cli.exe` | `llama-cli` |
| SmartScreen | `Unblock-File` llamado automáticamente | N/A |
| Módulo del agente | `powershell/modules/dotfiles-agent.psm1` | `shell/lib/agent.sh` |
| Soporte ARM64 | ✅ (recurso `win-cpu-arm64`) | ❌ (linux-arm64 aún no fijado) |

#### Problemas comunes

- **"Agent module not found"** — ejecuta `dotfiles agent --setup` primero; debe completarse satisfactoriamente.
- **Primera llamada lenta** — 5–8 s es normal para el arranque en frío. Las llamadas posteriores en la misma sesión no están en caché (un solo uso).
- **`explain` vs `agent`** — usa `dotfiles explain` para consultas de alias/herramientas (instantáneo, offline, sin modelo). Usa `dotfiles agent` para generación libre de comandos de shell.

---

### `skills`

**Resumen en una línea:** Lista, localiza e instala guías SKILL.md portátiles en cualquier proyecto.

#### Sintaxis

```
dotfiles skills list
dotfiles skills path
dotfiles skills install
dotfiles skills install <destino>
```

#### Qué hace

Las skills son guías Markdown portátiles (cada una en un archivo `SKILL.md` dentro de un directorio con nombre bajo `skills/`) que enseñan a los agentes de IA conocimiento arquitectónico sobre el repositorio. Se pueden copiar en cualquier proyecto para que Copilot y otras herramientas de IA las aprovechen.

#### Subcomandos

##### `skills list`

Escanea `skills/*/SKILL.md`, extrae el campo de front-matter `description:` de cada uno e imprime una tabla formateada.

```powershell
dotfiles skills list
```

```
Available skills in skills/

  bootstrap-idempotency          Marker guards, backup strategy, re-run safety
  dotfiles-architecture          Load contract, thin-stub pattern, module boundaries
  dotfiles-cli-extension         Adding subcommands to dotfiles CLI (both shells)
  packages-and-tooling           winget/scoop/apt schemas, idempotent install patterns
  powershell-config              PSReadLine, Oh My Posh, alias functions, module guards
  shell-parity                   POSIX-first rules, bash/zsh divergence, common.sh patterns
```

##### `skills path`

Imprime la ruta absoluta del directorio `skills/`.

```powershell
dotfiles skills path
# C:\Users\you\dotfiles\skills
```

Útil para scripts que necesitan referenciar archivos de skills directamente.

##### `skills install [destino]`

Copia **todas** las skills en `<destino>/.copilot/skills/`, creando el directorio si no existe. Cada directorio de skill se copia recursivamente. La operación es segura de re-ejecutar (sobreescribe con `-Force`/`cp -R`).

- **`destino` por defecto** = directorio de trabajo actual.
- **`destino` personalizado** = cualquier ruta de directorio.

```powershell
# Instalar en el proyecto actual
dotfiles skills install

# Instalar en un proyecto específico
dotfiles skills install C:\Projects\myapp
#   ✓ bootstrap-idempotency
#   ✓ dotfiles-architecture
#   ✓ dotfiles-cli-extension
#   ✓ packages-and-tooling
#   ✓ powershell-config
#   ✓ shell-parity
#
#   6 skill(s) installed → C:\Projects\myapp\.copilot\skills
```

```bash
# bash/zsh
dotfiles skills install
dotfiles skills install ~/projects/myapp
```

#### Notas de plataforma

| | PowerShell | bash/zsh |
|---|---|---|
| Separador de destino | `\` | `/` |
| Creación de directorio | `New-Item -Force` | `mkdir -p` |
| Copia | `Copy-Item -Recurse -Force` | `cp -R` |

El formato de la ruta de destino (`<destino>/.copilot/skills/`) es el mismo en ambas plataformas.

---

## Flujos de trabajo / Recetas

### Receta 1: Configurar una máquina nueva

```powershell
# Windows — bootstrap en una línea
irm https://raw.githubusercontent.com/jmanuelcorral/dotfiles/master/bootstrap/install.ps1 | iex

# Verificar que todo está configurado
dotfiles version
dotfiles help
```

```bash
# Linux/WSL/macOS
curl -fsSL https://raw.githubusercontent.com/jmanuelcorral/dotfiles/master/bootstrap/install.sh | bash

dotfiles version
dotfiles help
```

---

### Receta 2: Añadir y registrar un script personal

```powershell
# 1. Crear tu script en bin/
New-Item bin\gituseswitch.ps1
# (editar el archivo)

# 2. Registrarlo
dotfiles register gituseswitch -Description "Cambiar identidad de usuario git"

# 3. Confirmar que está visible
dotfiles list
dotfiles explain gituseswitch
```

En Unix, después de ejecutar el paso de registro en PowerShell (o editar `shared/tools.json` manualmente), los comandos Unix `dotfiles list` y `dotfiles explain` recogerán la entrada automáticamente — comparten el mismo `shared/tools.json`.

---

### Receta 3: Encontrar un comando olvidado

```powershell
# Opción A: Búsqueda fuzzy interactiva
dotfiles help
# Escribe "stash" → ve todas las entradas de stash al instante

# Opción B: Filtro por palabra clave
dotfiles help rebase

# Opción C: Buscar un alias específico
dotfiles explain gl
#   gl — git log --oneline --graph --decorate
```

---

### Receta 4: Configurar el agente de IA local

```powershell
# Windows
dotfiles agent --setup
# Descarga ~1 GB de modelo en cache/models/

# ¿Máquina con poca RAM? Usa el fallback 0.5B (~469 MB)
dotfiles agent --setup --fallback

# Pruébalo
dotfiles agent "mostrar el log de git de los últimos 5 commits como un grafo"
```

```bash
# Linux/WSL/macOS — sintaxis idéntica
dotfiles agent --setup
dotfiles agent "listar todos los contenedores docker incluyendo los detenidos"
```

---

### Receta 5: Instalar skills en otro proyecto

```powershell
# Primero ve al directorio del proyecto destino, luego:
dotfiles skills install
# Todas las skills copiadas en ./.copilot/skills/

# O pasa una ruta absoluta
dotfiles skills install C:\Projects\myapp
```

---

### Receta 6: Actualizar dotfiles a la última versión

```powershell
dotfiles update
# Reporta versión antigua → nueva, muestra changelog, re-ejecuta el instalador, recarga el perfil.
```

---

## Referencias cruzadas

- [Índice de comandos / README](README.md) — tabla de referencia rápida y enlaces a las guías
- [Hoja de referencia](../cheatsheet.md) — el contenido que impulsa `dotfiles help`
- [README del repositorio](../../README.md) — instrucciones de instalación y visión general
- [Arquitectura](../ARCHITECTURE.md) — contrato de carga, patrón stub, estructura de directorios
- `shared/aliases.json` — fuente única de verdad de alias multiplataforma (leída por `explain`)
- `shared/tools.json` — registro de herramientas registradas (leído por `list`, `help`, `explain`)
- `shared/agent-config.json` — configuración del motor e modelo del agente
- `skills/README.md` — cómo crear y publicar skills
