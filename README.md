# 🛠️ agendia-dev-scripts

Scripts de desarrollo para gestionar repositorios, microfrontends, microservicios y BFFs de Agendia.

> **Nota:** Este repositorio se llamará `agendia-dev-scripts` cuando se suba a GitHub, siguiendo el estándar de nombres `agendia-*`.

## 📋 Índice

- [Estructura del Proyecto](#estructura-del-proyecto)
- [Gestión de Repositorios](#gestión-de-repositorios)
- [Gestión de Microfrontends](#gestión-de-microfrontends)
- [Crear Nuevo Microfrontend](#crear-nuevo-microfrontend)
- [Uso en Windows](#uso-en-windows)

---

## 📁 Estructura del Proyecto

El proyecto está organizado en carpetas modulares según el tipo de componente:

```
agendia-dev-scripts/
├── README.md                    # Este archivo
├── .gitignore                   # Archivos ignorados (logs, PIDs, etc.)
│
├── microfrontends/              # Scripts para gestionar MFs
│   ├── install-all-mf.sh       # Instalar dependencias de todos los MFs
│   ├── start-all-mf.sh         # Iniciar todos los MFs (Bash)
│   ├── start-all-mf.ps1         # Iniciar todos los MFs (PowerShell)
│   ├── stop-all-mf.sh          # Detener todos los MFs (Bash)
│   ├── stop-all-mf.ps1         # Detener todos los MFs (PowerShell)
│   ├── list-all-mf.sh          # Listar MFs corriendo (Bash)
│   ├── list-all-mf.ps1         # Listar MFs corriendo (PowerShell)
│   ├── restart-all-mf.sh       # Reiniciar todos los MFs (Bash)
│   └── restart-all-mf.ps1      # Reiniciar todos los MFs (PowerShell)
│
├── microservices/               # Scripts para gestionar MSs (futuro)
│   └── (scripts futuros)
│
├── bffs/                        # Scripts para gestionar BFFs (futuro)
│   └── (scripts futuros)
│
├── repos/                       # Scripts para gestionar repositorios
│   ├── clone-all-repos.sh      # Clonar todos los repos
│   └── update-all-repos.sh     # Actualizar todos los repos
│
└── templates/                   # Scripts para crear desde templates
    └── create-mf.sh            # Crear nuevo microfrontend
```

---

## 📦 Gestión de Repositorios

### `repos/clone-all-repos.sh`

Clona todos los repositorios de la organización Ashen-Agendia que aún no estén clonados localmente.

```bash
./repos/clone-all-repos.sh
```

**Requisitos:**
- `gh` (GitHub CLI) instalado y autenticado
- `jq` instalado

---

### `repos/update-all-repos.sh`

Actualiza todos los repositorios clonados ejecutando `git pull` en cada uno.

```bash
./repos/update-all-repos.sh
```

**Nota:** Solo actualiza directorios que contengan un repositorio git (carpeta `.git`).

---

## 🚀 Gestión de Microfrontends

### Instalar Dependencias

#### `microfrontends/install-all-mf.sh`

Instala las dependencias de todos los microfrontends automáticamente.

```bash
./microfrontends/install-all-mf.sh
```

**Características:**
- Solo instala en directorios que existan y tengan `package.json`
- Muestra un resumen al final con éxitos, saltados y fallidos

---

### Iniciar Microfrontends

#### `microfrontends/start-all-mf.sh` / `microfrontends/start-all-mf.ps1`

Inicia todos los microfrontends en modo desarrollo en background.

**Bash:**
```bash
./microfrontends/start-all-mf.sh
```

**PowerShell:**
```powershell
./microfrontends/start-all-mf.ps1
```

**Características:**
- Inicia todos los MFs en paralelo
- Guarda los logs en `logs/` (en la raíz del proyecto de scripts)
- Guarda los PIDs en `.mf-pids` (en la raíz del proyecto de scripts) para poder detenerlos después
- Muestra un resumen de los iniciados, saltados y fallidos

---

### Detener Microfrontends

#### `microfrontends/stop-all-mf.sh` / `microfrontends/stop-all-mf.ps1`

Detiene todos los microfrontends que están corriendo.

**Bash:**
```bash
./microfrontends/stop-all-mf.sh
```

**PowerShell:**
```powershell
./microfrontends/stop-all-mf.ps1
```

**Características:**
- Lee los PIDs desde `.mf-pids` y detiene los procesos
- Si no encuentra el archivo, intenta detener procesos en los puertos comunes (3000-3010)
- Muestra un resumen de los procesos detenidos

---

### Listar Microfrontends

#### `microfrontends/list-all-mf.sh` / `microfrontends/list-all-mf.ps1`

Lista todos los microfrontends que están corriendo actualmente.

**Bash:**
```bash
./microfrontends/list-all-mf.sh
```

**PowerShell:**
```powershell
./microfrontends/list-all-mf.ps1
```

**Características:**
- Lee los PIDs desde `.mf-pids` y verifica qué procesos están corriendo
- Muestra el estado de cada MF (corriendo, detenido, no iniciado)
- Muestra el puerto en el que está corriendo cada MF (si está disponible)
- Muestra un resumen con la cantidad de MFs corriendo, detenidos y no iniciados

---

### Reiniciar Microfrontends

#### `microfrontends/restart-all-mf.sh` / `microfrontends/restart-all-mf.ps1`

Reinicia todos los microfrontends que están corriendo actualmente.

**Bash:**
```bash
./microfrontends/restart-all-mf.sh
```

**PowerShell:**
```powershell
./microfrontends/restart-all-mf.ps1
```

**Características:**
- Lee los PIDs desde `.mf-pids` y detiene solo los procesos que están corriendo
- Reinicia automáticamente los microfrontends que estaban activos
- No reinicia los que no estaban corriendo (solo los que estaban activos)
- Útil para aplicar cambios de configuración sin tener que hacer stop y start manualmente
- Muestra un resumen de los reiniciados, no encontrados y fallidos

---

## ✨ Crear Nuevo Microfrontend

### `templates/create-mf.sh`

Crea un nuevo microfrontend desde el template base con configuración automática.

```bash
./templates/create-mf.sh <nombre-mf>
```

**Ejemplo:**
```bash
./templates/create-mf.sh agenda
```

**⚠️ Importante:** Solo pasa el nombre del MF **sin** el prefijo `agendia-mf-`. El script agregará automáticamente el prefijo.

- ✅ Correcto: `./templates/create-mf.sh agenda` → crea `agendia-mf-agenda`
- ❌ Incorrecto: `./templates/create-mf.sh agendia-mf-agenda` → crearía `agendia-mf-agendia-mf-agenda`

**💡 Si el repositorio ya está clonado:**
- Si el directorio ya existe, el script solo actualizará los archivos de configuración necesarios
- No sobrescribirá tu código existente
- Útil para configurar repositorios ya clonados

**Características:**
- ✅ Detecta automáticamente un puerto disponible (desde 3001)
- ✅ Crea el `.env.dev` con el puerto correcto
- ✅ Actualiza automáticamente el shell (`routes.config.ts` y `.env.dev`)
- ✅ Configura todos los archivos necesarios
- ✅ Limpia archivos temporales

**Qué hace el script:**

1. **Encuentra un puerto disponible** automáticamente
2. **Copia el template** `agendia-template-mf` a `agendia-mf-<nombre>`
3. **Actualiza `package.json`** con el nuevo nombre
4. **Actualiza `vite.config.ts`** con el nuevo nombre y puerto
5. **Actualiza `src/config/root.config.ts`** con la configuración del MF
6. **Crea `.env.dev`** con las variables de entorno
7. **Actualiza el shell** automáticamente:
   - Agrega la variable de entorno al `.env.dev` del shell
   - Registra el MF en `routes.config.ts`
8. **Limpia** `node_modules`, `dist` y `.git`

**Próximos pasos después de crear:**

```bash
cd agendia-mf-<nombre>
npm install
npm run dev
```

**Nota:** El microfrontend ya está registrado en el shell. Solo necesitas reiniciar el shell para que lo detecte.

---

## 💻 Uso en Windows

### Scripts Bash (.sh)

Puedes ejecutar los scripts Bash usando:

- **Git Bash** (incluido con Git for Windows)
- **WSL** (Windows Subsystem for Linux)

### Scripts PowerShell (.ps1)

Los scripts PowerShell están optimizados para Windows y funcionan mejor en este entorno:

```powershell
./microfrontends/start-all-mf.ps1
./microfrontends/stop-all-mf.ps1
./microfrontends/list-all-mf.ps1
./microfrontends/restart-all-mf.ps1
```

**Recomendación:** En Windows, usa los scripts PowerShell (`.ps1`) para mejor compatibilidad.

---

## 🔍 Archivos Generados

Los scripts generan algunos archivos temporales en la raíz del proyecto de scripts:

- **`.mf-pids`**: Contiene los PIDs de los procesos corriendo (para poder detenerlos)
- **`logs/`**: Directorio con los logs de cada microfrontend

Estos archivos están en `.gitignore` y no se deben commitear.

---

## 🚧 Scripts Futuros

La estructura está preparada para futuros scripts:

- **`microservices/`**: Scripts para gestionar microservicios (instalar, iniciar, detener, etc.)
- **`bffs/`**: Scripts para gestionar BFFs (instalar, iniciar, detener, etc.)
- **`templates/`**: Más scripts para crear componentes desde templates (create-ms.sh, create-bff.sh, etc.)

---

## 📝 Notas

- Todos los scripts asumen que están en un monorepo donde los repositorios están en el directorio padre del proyecto de scripts.
- Los scripts detectan automáticamente las rutas correctas, así que puedes ejecutarlos desde cualquier ubicación dentro del proyecto de scripts.
- Los archivos de logs y PIDs se comparten entre todos los scripts del mismo tipo (todos los scripts de MFs comparten el mismo `.mf-pids` y `logs/`).
