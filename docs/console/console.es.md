# Trabajar en la consola — Guía para desarrolladores (Español)

> Fecha: 2026-06-05  
> [← Volver al índice](README.md) · [English](console.en.md)

---

## Tabla de contenidos

1. [Filosofía](#filosofía)
2. [Navegar y listar archivos](#navegar-y-listar-archivos)
3. [Ver e inspeccionar archivos](#ver-e-inspeccionar-archivos)
4. [Buscar código y archivos](#buscar-código-y-archivos)
5. [Búsqueda difusa con fzf](#búsqueda-difusa-con-fzf)
6. [Saltar entre directorios (zoxide)](#saltar-entre-directorios-zoxide)
7. [Git en el día a día](#git-en-el-día-a-día)
8. [GitHub desde la terminal](#github-desde-la-terminal)
9. [Trabajar con JSON / YAML](#trabajar-con-json--yaml)
10. [Sistema y procesos](#sistema-y-procesos)
11. [Versiones de Node (volta)](#versiones-de-node-volta)
12. [Tu prompt](#tu-prompt)
13. [Alias de conveniencia entre shells](#alias-de-conveniencia-entre-shells)
14. [Recetas — Flujos de trabajo reales](#recetas--flujos-de-trabajo-reales)
15. [Tabla resumen](#tabla-resumen)
16. [Para aprender más](#para-aprender-más)

---

## Filosofía

Este repositorio de dotfiles instala un conjunto de **herramientas CLI modernas** que reemplazan las utilidades Unix clásicas que ya conoces — pero son más rápidas, más inteligentes y más amigables. La clave está en que los mismos alias funcionan de forma idéntica tanto en **Windows PowerShell 7+** como en **bash/zsh en Linux/macOS/WSL2**. Las herramientas están conectadas de manera que escribir `ll`, `cat`, `find`, `grep` o `cd` utiliza automáticamente el reemplazo moderno cuando está instalado, y cae de vuelta al comportamiento por defecto de la plataforma cuando no lo está.

El objetivo: no tienes que pensar en qué sistema operativo estás. Abre una terminal y ponte a trabajar.

> **Notas por plataforma** aparecen a lo largo de esta guía como:  
> 🪟 **Windows** — notas específicas de PowerShell  
> 🐧 **Unix/WSL** — notas específicas de bash/zsh

---

## Navegar y listar archivos

### `eza` — `ls` moderno

**Reemplaza:** `ls`, `dir`  
**Qué añade:** Iconos (Nerd Font), columnas de estado de Git, tipos de archivo con color, vista en árbol, listado consciente de `.gitignore`.

Los siguientes alias están definidos en `shared/aliases.json` y funcionan en ambas plataformas:

| Alias | Se expande a | Qué hace |
|---|---|---|
| `ls` | `eza --icons --group-directories-first` | Listado por defecto, dirs primero |
| `ll` | `eza -la --icons --group-directories-first` | Listado largo con archivos ocultos |
| `la` | `eza -a --icons` | Todos los archivos incluyendo dotfiles (compacto) |
| `l` | `eza --icons` | Listado compacto |
| `lt` | `eza --tree --level=2 --icons` | Vista en árbol, 2 niveles de profundidad |

#### Ejemplos

```bash
# Listado estándar — directorios primero, iconos por tipo de archivo
ls

# Listado largo con permisos, tamaño, fecha y archivos ocultos
ll

# Mostrar todos los dotfiles del directorio actual
la

# Vista en árbol del directorio actual (2 niveles)
lt

# Vista en árbol de una ruta concreta, 3 niveles
eza --tree --level=3 src/

# Ordenar por tamaño de archivo descendente
eza -la --sort=size --reverse

# Mostrar columna de estado Git (rama, modificados, en staging)
eza -la --git
```

#### Salida esperada (ll)

```
drwxr-xr-x  - usuario  3 Jun 10:00 📁 src
drwxr-xr-x  - usuario  3 Jun 09:00 📁 node_modules
.rw-r--r-- 1.2k usuario  3 Jun 10:05 📄 package.json
.rw-r--r--  432 usuario  2 Jun 15:00 📄 README.md
```

> 🪟 **Windows:** Cae de vuelta a `Get-ChildItem -Force` si eza no está instalado.  
> 🐧 **Unix:** Cae de vuelta a `ls -la` / `ls --color=auto`.

---

## Ver e inspeccionar archivos

### `bat` — `cat` con resaltado de sintaxis

**Reemplaza:** `cat`  
**Qué añade:** Resaltado de sintaxis para más de 200 lenguajes, numeración de líneas, indicadores de cambios Git, paginación.

El alias `cat` se expande a `bat --style=plain` (salida limpia, sin numeración ni bordes — compatible con tuberías).

#### Ejemplos

```bash
# Ver un archivo (alias: salida plana, sin decoraciones)
cat package.json

# Ver con números de línea e indicadores de cambios Git
bat -n package.json

# Ver con interfaz completa (numeración + cabecera + cuadrícula)
bat --style=full README.md

# Elegir un tema
bat --theme=TwoDark src/index.ts

# Listar todos los temas disponibles
bat --list-themes

# Comparar dos versiones de un archivo (salida de diff resaltada)
bat --diff src/utils.ts

# Paginar un archivo grande
bat --paging=always server.log

# Resaltar un rango específico de líneas
bat -r 10:30 src/index.ts
```

> 🪟 **Windows:** `bat` está disponible como `bat`. Sin peculiaridades de nombre binario.  
> 🐧 **Unix:** En Ubuntu < 22.04 el binario se instala como `batcat`; `bootstrap/install.sh` crea un enlace simbólico `~/.local/bin/bat` para que el alias funcione automáticamente.

#### Combinación potente — bat como previsualizador de fzf

```bash
# Previsualizar archivos de forma interactiva (ver también: sección fzf)
fzf --preview 'bat --color=always --style=numbers {}'
```

---

## Buscar código y archivos

### `ripgrep` (`rg`) — `grep` rápido

**Reemplaza:** `grep`  
**Qué añade:** Búsquedas dramáticamente más rápidas, respeta `.gitignore` por defecto, coincidencias en color, filtros por tipo de archivo.

El alias `grep` se expande a `rg` en ambas plataformas.

#### Ejemplos

```bash
# Búsqueda básica — todos los archivos en el árbol del directorio actual
grep "TODO"

# Sin distinguir mayúsculas/minúsculas
grep -i "fixme"

# Buscar solo en tipos de archivo específicos
rg "useState" -g "*.tsx"
rg "import" -g "*.{ts,tsx}"

# Mostrar 2 líneas de contexto antes y después de cada coincidencia
rg "error" -C 2

# Solo antes / solo después
rg "throw" -B 3
rg "catch" -A 5

# Buscar un patrón regex
rg "fn\s+\w+\(" --type rust

# Listar solo los nombres de archivos que contienen el patrón
rg -l "TODO"

# Contar coincidencias por archivo
rg -c "import"

# Invertir la coincidencia — líneas que NO contienen el patrón
rg -v "test" src/

# Buscar incluyendo archivos normalmente ignorados por .gitignore
rg --no-ignore "secret"

# Salida de cadena sin procesar, sin color (útil en scripts)
rg -N --no-heading "version" package.json
```

#### Combinación potente — rg en fzf

```bash
# Buscar resultados de forma interactiva y saltar al archivo:línea
rg --line-number "" | fzf --delimiter ':' --preview 'bat --color=always {1} -r {2}:'
```

---

### `fd` — `find` rápido

**Reemplaza:** `find`  
**Qué añade:** Sintaxis intuitiva, consciente de `.gitignore`, ejecución en paralelo, patrones regex/glob.

El alias `find` se expande a `fd`.

#### Ejemplos

```bash
# Encontrar todos los archivos TypeScript
find -e ts

# Encontrar archivos por patrón de nombre
find "config"

# Buscar en un directorio específico
find -e json packages/

# Encontrar solo directorios
find -t d src

# Encontrar archivos modificados en los últimos 2 días
find --changed-within 2d

# Encontrar y ejecutar un comando en cada resultado
find -e log --exec rm {}

# Búsqueda con distinción de mayúsculas
find -s "README"

# Incluir archivos ocultos e ignorados
find -HI ".env"
```

> 🐧 **Unix:** En Debian/Ubuntu el paquete apt instala el binario como `fdfind`; `bootstrap/install.sh` crea un enlace simbólico `~/.local/bin/fd` para que el alias `find` funcione de forma transparente.

#### Combinación potente — fd en fzf

```bash
# Seleccionar un archivo TypeScript de forma interactiva y abrirlo
fd -e ts | fzf --preview 'bat --color=always {}'
```

---

## Búsqueda difusa con fzf

### `fzf` — buscador difuso interactivo

**Qué es:** Una interfaz de búsqueda difusa universal para cualquier cosa que produzca líneas de texto.  
**Integración con el shell:** Conectada automáticamente por los perfiles — no se necesita configuración tras la instalación.

#### Atajos de teclado (conectados automáticamente)

| Tecla | Acción |
|---|---|
| `Ctrl+R` | Búsqueda difusa interactiva en el historial de comandos |
| `Ctrl+T` | Selector de archivos difuso — inserta la ruta elegida en el cursor |
| `Alt+C` | `cd` difuso a un subdirectorio |

#### Uso independiente

```bash
# Seleccionar de una lista de archivos
fzf

# Seleccionar con previsualización de bat
fzf --preview 'bat --color=always --style=numbers {}'

# Pasar cualquier lista a fzf
echo -e "opción1\nopción2\nopción3" | fzf

# Selección múltiple (Tab para marcar, Enter para confirmar)
fd -e ts | fzf -m

# Pasar el archivo seleccionado a un editor
code $(fzf --preview 'bat --color=always {}')
```

#### Búsqueda en historial (`Ctrl+R`)

Pulsa `Ctrl+R` en tu shell. Aparece una lista a pantalla completa de tu historial de comandos. Escribe para filtrar; pulsa Enter para ejecutar el comando seleccionado.

```
> git push
  git push origin main
  git push --force-with-lease
  git push --set-upstream origin feature/mi-rama
```

#### Combinaciones potentes

```bash
# Buscar código con rg, previsualizar coincidencias con bat
rg --line-number "TODO" | fzf \
  --delimiter ':' \
  --preview 'bat --color=always --highlight-line {2} {1}'

# Matar un proceso de forma interactiva
ps aux | fzf | awk '{print $2}' | xargs kill

# Cambiar de rama git de forma interactiva
git branch | fzf | xargs git checkout

# Seleccionar y abrir un archivo modificado recientemente
fd --changed-within 7d | fzf --preview 'bat --color=always {}'
```

---

## Saltar entre directorios (zoxide)

### `zoxide` — `cd` inteligente

**Reemplaza:** `cd` para directorios frecuentes  
**Qué añade:** Saltos de directorio basados en frecuencia y recencia — aprende qué directorios visitas más y te permite saltar a ellos con un nombre parcial.

La integración con el shell se conecta automáticamente por los perfiles (`zoxide init` se ejecuta al iniciar la sesión).

#### Comandos

```bash
# Saltar al directorio más frecuente que coincida con "dotfiles"
z dotfiles

# Saltar al directorio más frecuente que coincida con "src" bajo "miproyecto"
z miproyecto src

# Salto interactivo con fzf (zi = zoxide interactivo)
zi

# Añadir el directorio actual manualmente a la base de datos
zoxide add .

# Mostrar la base de datos (todos los directorios rastreados + puntuaciones)
zoxide query --list

# Eliminar un directorio de la base de datos
zoxide remove /ruta/a/directorio/antiguo
```

#### Flujo de trabajo

La primera vez que haces `cd` a un directorio, zoxide empieza a rastrearlo. Tras unas cuantas visitas, `z <parcial>` saltará directamente allí:

```bash
cd ~/projects/mi-aplicacion-genial   # primera visita — registrada
# ... trabajas unos días ...
z genial                              # → salta a ~/projects/mi-aplicacion-genial
```

> 🐧 **Unix:** Disponible en Ubuntu 22.10+ vía apt; los sistemas más antiguos obtienen zoxide mediante el script oficial de instalación (gestionado automáticamente por `bootstrap/install.sh`).

---

## Git en el día a día

### Atajos de Git (de `shared/aliases.json`)

Todos los alias de git funcionan de forma idéntica en Windows y Unix:

| Alias | Se expande a | Cuándo usarlo |
|---|---|---|
| `g` | `git` | Prefijo git corto |
| `gst` | `git status` | Ver qué ha cambiado |
| `ga` | `git add` | Añadir archivos al staging |
| `gc` | `git commit` | Hacer commit (añade `-m "msg"` o abre el editor) |
| `gp` | `git push` | Subir al remoto |
| `gl` | `git log --oneline --graph --decorate` | Historial visual |
| `gd` | `git diff` | Cambios sin staging |

#### Ejemplos

```bash
# Flujo de trabajo diario completo
gst                          # ¿qué cambió?
ga src/feature.ts            # añadir archivo específico al staging
ga .                         # añadir todo al staging
gc -m "feat: añadir widget"  # commit con mensaje
gp                           # push

# Historial en forma de grafo
gl

# Ver cambios en staging
gd --staged

# Ver diferencias respecto a la rama main
gd main

# Guardar cambios temporalmente y restaurar
g stash
g stash pop
```

### `delta` — mejores diffs de Git

**Reemplaza:** El paginador integrado de git  
**Qué añade:** Resaltado de sintaxis, números de línea, vista en paralelo, mejor visualización de conflictos de fusión.

Delta se configura automáticamente como paginador de git. No se invoca directamente — potencia cada `git diff`, `git log -p` y `git show`.

```bash
# Todos estos usan delta automáticamente:
gd                           # diff sin staging
gd --staged                  # diff con staging
git log -p                   # historial de commits con parches
git show HEAD                # último commit
git show abc1234             # commit específico

# Diff en paralelo (vista lado a lado)
git diff --word-diff
```

#### Salida esperada

```diff
───────────────────────────────────────────
Archivo: src/index.ts
───────────────────────────────────────────
  10 │  10 │  const saludo = "hola";
  11 │     │- console.log(saludo)
     │  11 │+ console.log(saludo + "!");
  12 │  12 │
```

---

## GitHub desde la terminal

### `gh` — CLI de GitHub

**Qué es:** La CLI oficial de GitHub. Gestiona repositorios, pull requests, issues, ejecuciones de Actions y más sin abrir el navegador.

#### Autenticación

```bash
# Primera vez: autenticarse
gh auth login

# Verificar el estado de autenticación actual
gh auth status
```

#### Repositorios

```bash
# Clonar un repositorio
gh repo clone propietario/repo

# Crear un nuevo repositorio desde el directorio actual
gh repo create mi-proyecto --public

# Ver el repositorio en el navegador
gh repo view --web
```

#### Pull Requests

```bash
# Crear un PR desde la rama actual
gh pr create --title "feat: añadir búsqueda" --body "Añade búsqueda difusa a la UI"

# Crear un PR en borrador
gh pr create --draft

# Listar PRs abiertos
gh pr list

# Ver el PR de la rama actual
gh pr view

# Abrir el PR en el navegador
gh pr view --web

# Descargar un PR localmente
gh pr checkout 42

# Fusionar un PR
gh pr merge 42 --squash
```

#### Issues

```bash
# Crear un issue
gh issue create --title "Bug: el login falla" --body "Pasos para reproducir..."

# Listar issues
gh issue list
gh issue list --assignee @me

# Ver un issue
gh issue view 15
```

#### Actions / Ejecuciones de workflows

```bash
# Listar las ejecuciones de workflows recientes
gh run list

# Seguir una ejecución en tiempo real
gh run watch

# Ver los logs de una ejecución
gh run view --log

# Volver a ejecutar los trabajos fallidos
gh run rerun --failed
```

#### Combinación potente — gh + jq

```bash
# Listar PRs en JSON y extraer título + número
gh pr list --json number,title | jq '.[] | "\(.number): \(.title)"' -r

# Encontrar todos los issues abiertos asignados a ti
gh issue list --assignee @me --json number,title,labels | jq '.[] | .title'
```

---

## Trabajar con JSON / YAML

### `jq` — procesador JSON

**Qué es:** Un procesador JSON ligero y flexible para la línea de comandos.

#### Ejemplos

```bash
# Imprimir un archivo JSON con formato
jq '.' package.json

# Extraer un campo específico
jq '.name' package.json

# Extraer un campo anidado
jq '.scripts.build' package.json

# Obtener todas las claves del nivel superior
jq 'keys' package.json

# Filtrar elementos de un array
jq '.dependencies | keys[]' package.json

# Salida de cadena sin procesar (sin comillas)
jq -r '.version' package.json

# Construir un nuevo objeto a partir de campos
jq '{nombre: .name, ver: .version}' package.json

# Filtrar array por condición
echo '[{"name":"a","active":true},{"name":"b","active":false}]' \
  | jq '[.[] | select(.active == true)]'

# Procesar respuesta de una API
curl -s https://api.github.com/repos/sharkdp/bat/releases/latest \
  | jq '{etiqueta: .tag_name, fecha: .published_at, url: .html_url}'
```

#### Combinación potente — gh + jq

```bash
# Mostrar solo títulos de PRs desde la salida JSON
gh pr list --json number,title,headRefName \
  | jq -r '.[] | "#\(.number) \(.headRefName): \(.title)"'
```

---

### `yq` — procesador YAML / JSON / TOML

**Qué es:** Como `jq` pero funciona de forma nativa con YAML, JSON y TOML (fork de mikefarah).

> 🐧 **Solo Unix/WSL.** `yq` se instala desde GitHub releases en Linux mediante `bootstrap/install.sh`. No está disponible en la lista de paquetes winget de Windows.

```bash
# Leer un campo YAML
yq '.services.web.image' docker-compose.yml

# Leer varios campos
yq '.name, .version' Chart.yaml

# Actualizar un campo en el propio archivo
yq -i '.version = "2.0.0"' Chart.yaml

# Convertir YAML a JSON
yq -o=json '.' docker-compose.yml | jq '.'

# Convertir JSON a YAML
cat data.json | yq -P '.'

# Fusionar dos archivos YAML
yq '. * load("override.yml")' base.yml
```

---

## Sistema y procesos

### `duf` — uso de disco gráfico

**Reemplaza:** `df`  
**Qué añade:** Tabla con colores y barras de uso, agrupación por punto de montaje.

> 🐧 **Solo Unix/WSL.** Se instala vía apt en Linux. En Windows usa `df` (que cae de vuelta a `Get-PSDrive`).

```bash
# Mostrar todos los puntos de montaje
duf

# Mostrar solo discos locales
duf --only local
```

### Alias de disco, procesos y sistema

Estos alias funcionan en ambas plataformas (implementación PowerShell vs implementación Unix):

| Alias | Comando Unix | Equivalente Windows |
|---|---|---|
| `df` | `df -h` | `Get-PSDrive` |
| `du` | `du -sh` | `Get-ChildItem -Recurse \| Measure-Object -Sum Length` |
| `top` | `htop` (o `top`) | `Get-Process \| Sort-Object CPU -Descending \| Select -First 20` |
| `ps` | `ps aux` | `Get-Process` |
| `kill` | `kill <pid>` | `Stop-Process <pid>` |
| `env` | `env` | `Get-ChildItem Env:` |
| `export` | `export NOMBRE=VALOR` | `$env:NOMBRE = "VALOR"` |

#### Ejemplos

```bash
# Comprobar el uso de disco del directorio actual
du .

# Mostrar todas las variables de entorno
env

# Listar procesos en ejecución
ps

# Matar un proceso por PID
kill 12345

# Definir una variable de entorno (sesión actual)
export NODE_ENV=production    # Unix
```

```powershell
# Equivalente en Windows
$env:NODE_ENV = "production"
```

### `gsudo` / `sudo` — elevación de privilegios

**Qué es:** Ejecutar un comando con privilegios elevados sin salir de la terminal.

> 🪟 **Windows:** `gsudo` (alias `sudo`) eleva de forma integrada — sin ventana separada, prompt de UAC en línea.  
> 🐧 **Unix:** `sudo` estándar.

```bash
# Elevar un único comando
sudo apt update          # Unix
sudo choco install ...   # Windows (vía gsudo)

# Abrir un shell elevado
sudo -s               # Unix: shell de root
sudo pwsh             # Windows: PowerShell elevado
```

---

## Versiones de Node (volta)

### `volta` — gestor de versiones de Node.js

**Reemplaza:** `nvm`, `n`, `fnm`  
**Qué añade:** Fijado por proyecto mediante `package.json`, sin shims de shell, compatible con npm/yarn/pnpm.

> 🪟 **Windows:** Se instala vía winget. Funciona en PowerShell.  
> 🐧 **Unix/WSL:** No está en `apt.json` — instalar por separado desde [volta.sh](https://volta.sh) si es necesario.

```bash
# Instalar el último Node LTS
volta install node

# Instalar una versión específica
volta install node@20

# Instalar una versión específica de npm
volta install npm@10

# Fijar la versión de Node para el proyecto actual (escribe en package.json)
volta pin node@20
volta pin npm@10

# Comprobar qué está instalado
volta list

# Ejecutar un comando puntual con una versión específica
volta run --node 18 node --version
```

Tras `volta pin node@20`, el `package.json` contendrá:

```json
{
  "volta": {
    "node": "20.x.x",
    "npm": "10.x.x"
  }
}
```

Cualquiera que clone el repositorio y tenga Volta instalado usará automáticamente la versión fijada — sin el baile de sincronización del `.nvmrc`.

---

## Tu prompt

El prompt de tu shell está gestionado por un **motor de temas** que muestra de un vistazo el estado de git, versiones de lenguajes, tiempo de ejecución y código de salida.

> 🪟 **Windows PowerShell:** [Oh My Posh](https://ohmyposh.dev) — configurado mediante `powershell/themes/dotfiles.omp.json`. Tema: Tokyo Night.  
> 🐧 **Unix/WSL bash/zsh:** [Starship](https://starship.rs) — instalado mediante el script oficial, configurado mediante `~/.config/starship.toml`.

Ambos se inicializan automáticamente mediante los perfiles. No tienes que hacer nada — simplemente abre una terminal y verás el prompt con estilo.

Qué muestra tu prompt:
- Directorio actual (abreviado)
- Rama Git + estado (en staging / modificados / sin seguimiento)
- Versión de Node.js (cuando estás en un proyecto Node)
- Versión de Python (cuando estás en un entorno virtual)
- Tiempo de ejecución del comando (para comandos > 2 s)
- Indicador de código de salida (verde ✔ / rojo ✘)

> 🔧 La personalización del tema del prompt es responsabilidad de los archivos de configuración del prompt — no se cubre en esta guía. Consulta `powershell/themes/` y `powershell/prompt.ps1` para el lado Windows.

---

## Alias de conveniencia entre shells

Todos están definidos en `shared/aliases.json` y funcionan en ambas plataformas:

### Navegación

| Alias | Qué hace |
|---|---|
| `..` | Subir un directorio |
| `...` | Subir dos directorios |
| `....` | Subir tres directorios |
| `up N` | Subir N directorios (función: `up 4`) |
| `cdot` | `cd` a la raíz del repositorio dotfiles (`$DOTFILES`) |
| `z <parcial>` | Saltar a un directorio frecuente (zoxide) |
| `zi` | Salto interactivo con zoxide (fzf) |

```bash
# Navegación rápida
..              # cd ..
...             # cd ../..
....            # cd ../../..
up 4            # cd ../../../../
cdot            # cd a ~/dotfiles (o donde apunte $DOTFILES)
```

### Operaciones con archivos

| Alias | Qué hace |
|---|---|
| `mkdir <ruta>` | Crear directorio incluyendo todos los padres (comportamiento `-p`) |
| `mkcd <ruta>` | Crear directorio y hacer `cd` en él |
| `touch <archivo>` | Crear archivo o actualizar la fecha de modificación |
| `open <ruta>` | Abrir archivo o URL con la aplicación por defecto |

```bash
# Crear una estructura de directorios anidada y entrar en ella
mkcd src/components/ui

# Abrir el directorio actual en el explorador de archivos / Finder
open .

# Abrir una URL en el navegador
open https://github.com
```

### Gestión del shell

| Alias | Qué hace |
|---|---|
| `reload` | Recargar el perfil del shell (recoge cambios de alias) |
| `which <cmd>` | Localizar un ejecutable en el PATH |
| `history` | Mostrar el historial de comandos |
| `export NOMBRE=VALOR` | Definir una variable de entorno (estilo Unix) |
| `env` | Listar todas las variables de entorno |

```bash
# Tras editar shared/aliases.json y reconstruir los alias:
reload

# Encontrar dónde está un binario
which git
which node

# Buscar en el historial
history | grep "docker"
```

### Utilidades de texto

| Alias | Qué hace |
|---|---|
| `head -n N <archivo>` | Mostrar las primeras N líneas |
| `tail -n N <archivo>` | Mostrar las últimas N líneas |

```bash
# Mostrar las primeras 20 líneas de un log
head -n 20 app.log

# Seguir un log en tiempo real (Unix)
tail -f app.log
```

---

## Recetas — Flujos de trabajo reales

### 🔍 Encontrar y editar un archivo rápidamente

```bash
# 1. Usar fd para listar archivos TypeScript, fzf para seleccionar uno, abrir en VS Code
code $(fd -e ts | fzf --preview 'bat --color=always {}')

# 2. Alternativamente — buscar por contenido, luego seleccionar la coincidencia
rg -l "useEffect" | fzf --preview 'bat --color=always {}'
```

### 📜 Buscar en el historial de Git de forma interactiva

```bash
# Buscar mensajes de commit con fzf, ver el diff con delta
git log --oneline | fzf --preview 'git show --color=always {1}' | awk '{print $1}' | xargs git show
```

### 🌐 Explorar la respuesta de una API JSON

```bash
# Obtener, formatear y explorar de forma interactiva
curl -s https://api.github.com/repos/sharkdp/bat/releases \
  | jq '.[0:5] | .[] | {etiqueta: .tag_name, fecha: .published_at}' \
  | bat --language=json
```

### 🌿 Limpiar ramas de Git fusionadas

```bash
# Listar ramas fusionadas, seleccionar las que eliminar de forma interactiva
git branch --merged main \
  | grep -v "^\* " \
  | fzf -m \
  | xargs git branch -d
```

### 🚀 Entrar en un proyecto y ponerse a trabajar

```bash
# 1. Saltar al directorio del proyecto con zoxide
z miapp

# 2. Comprobar el estado de git
gst

# 3. Ver el historial reciente
gl

# 4. Iniciar una funcionalidad
ga .
gc -m "feat: estructura inicial"
gp
```

### 🔎 Encontrar archivos grandes en el repositorio

```bash
# Encontrar archivos > 1MB, ordenados por tamaño
fd --size +1mb | xargs du -sh | sort -rh | head -20
```

### 📦 Inspeccionar el árbol de dependencias de un package.json

```bash
# Listar todas las dependencias directas en una tabla
jq -r '.dependencies | to_entries[] | "\(.key)\t\(.value)"' package.json \
  | column -t

# Comprobar si un paquete está en devDependencies
jq '.devDependencies | has("typescript")' package.json
```

### 🏃 Seguir una ejecución de GitHub Actions en directo

```bash
# Hacer push e inmediatamente seguir la ejecución
gp
gh run watch
```

---

## Tabla resumen

| Herramienta | Comando principal | Qué hace |
|---|---|---|
| `eza` | `ll` | Listado largo con iconos y archivos ocultos |
| `bat` | `cat <archivo>` | Vista de archivo con resaltado de sintaxis |
| `fd` | `find -e ts` | Buscar archivos TypeScript |
| `rg` | `grep "patrón"` | Buscar código rápidamente |
| `fzf` | `Ctrl+R` | Búsqueda difusa en el historial |
| `zoxide` | `z <parcial>` | Saltar a un directorio frecuente |
| `delta` | *(automático, potencia git diff)* | Diffs con resaltado de sintaxis |
| `jq` | `jq '.name' archivo.json` | Extraer campo JSON |
| `yq` | `yq '.clave' archivo.yml` | Extraer campo YAML (Unix) |
| `duf` | `duf` | Uso de disco gráfico (Unix) |
| `git`+alias | `gl` / `gst` / `gd` | Historial, estado y diff en formato visual |
| `gh` | `gh pr create` | Crear un pull request |
| `volta` | `volta install node` | Instalar una versión de Node.js |
| `gsudo`/`sudo` | `sudo <cmd>` | Elevar un comando |
| `oh-my-posh` | *(automático)* | Prompt con estilo en Windows |
| `starship` | *(automático)* | Prompt con estilo en Unix/WSL |

---

## Para aprender más

| Herramienta | Página oficial / Documentación |
|---|---|
| eza | <https://github.com/eza-community/eza> |
| bat | <https://github.com/sharkdp/bat> |
| fd | <https://github.com/sharkdp/fd> |
| ripgrep | <https://github.com/BurntSushi/ripgrep> |
| fzf | <https://github.com/junegunn/fzf> |
| zoxide | <https://github.com/ajeetdsouza/zoxide> |
| delta | <https://github.com/dandavison/delta> |
| jq | <https://stedolan.github.io/jq/manual/> |
| yq (mikefarah) | <https://github.com/mikefarah/yq> |
| duf | <https://github.com/muesli/duf> |
| Oh My Posh | <https://ohmyposh.dev> |
| Starship | <https://starship.rs> |
| gsudo | <https://github.com/gerardog/gsudo> |
| volta | <https://volta.sh> |
| gh CLI | <https://cli.github.com/manual/> |
