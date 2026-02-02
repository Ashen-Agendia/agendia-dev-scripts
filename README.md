# 🛠️ agendia-dev-scripts

Scripts de desarrollo para gestionar repositorios, microfrontends, microservicios y BFFs de Agendia.

> **Nota:** Este repositorio se llamará `agendia-dev-scripts` cuando se suba a GitHub, siguiendo el estándar de nombres `agendia-*`.

## 📋 Índice

- [Instalación de Dependencias del Sistema](#instalación-de-dependencias-del-sistema)
- [Estructura del Proyecto](#estructura-del-proyecto)
- [Scripts de Setup](#scripts-de-setup)
- [Gestión de Repositorios](#gestión-de-repositorios)
- [Gestión de Microfrontends](#gestión-de-microfrontends)
- [Gestión de Microservicios](#gestión-de-microservicios)
- [Crear Nuevo Microfrontend](#crear-nuevo-microfrontend)
- [Crear Nuevo Microservicio](#crear-nuevo-microservicio)
- [Uso en Windows](#uso-en-windows)

---

## 🔧 Instalación de Dependencias del Sistema

Antes de usar los scripts, asegúrate de tener todas las dependencias del sistema instaladas.

### Script Automático (Recomendado)

```bash
chmod +x install-system-deps.sh
./install-system-deps.sh
```

Este script detecta e instala automáticamente:
- ✅ **Node.js 18+** y **npm** (para microfrontends)
- ✅ **Java 11+** (requisito de sbt)
- ✅ **sbt** (Scala Build Tool para microservicios)
- ✅ **gh** (GitHub CLI, opcional)
- ✅ **jq** (procesador JSON, opcional)

**Sistemas soportados:** Ubuntu/Debian, Fedora, CentOS/RHEL, macOS

### Verificación Manual

Si prefieres instalar manualmente o verificar las versiones:

```bash
node --version  # Debe ser v18 o superior
npm --version
java -version  # Debe ser 11 o superior
sbt --version
```

**📚 Documentación completa:** Ver [Instalación de Dependencias](../../agendia-docs/docs/setup/instalacion-dependencias.md)

---

## 📁 Estructura del Proyecto

El proyecto está organizado en carpetas modulares según el tipo de componente:

```
agendia-dev-scripts/
├── README.md                    # Este archivo
├── .gitignore                   # Archivos ignorados (logs, PIDs, etc.)
├── install-system-deps.sh        # Instalar dependencias del sistema ⭐
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
├── microservices/               # Scripts para gestionar MSs
│   ├── install-all-ms.sh       # Instalar dependencias de todos los MSs
│   ├── install-all-ms.ps1       # Instalar dependencias de todos los MSs (PowerShell)
│   ├── start-all-ms.sh          # Iniciar todos los MSs (Bash)
│   ├── start-all-ms.ps1         # Iniciar todos los MSs (PowerShell)
│   ├── stop-all-ms.sh           # Detener todos los MSs (Bash)
│   ├── stop-all-ms.ps1          # Detener todos los MSs (PowerShell)
│   ├── list-all-ms.sh           # Listar MSs corriendo (Bash)
│   ├── list-all-ms.ps1          # Listar MSs corriendo (PowerShell)
│   ├── restart-all-ms.sh        # Reiniciar todos los MSs (Bash)
│   └── restart-all-ms.ps1       # Reiniciar todos los MSs (PowerShell)
│
├── bffs/                        # Scripts para gestionar BFFs (futuro)
│   └── (scripts futuros)
│
├── setup/                       # Scripts de setup de infraestructura
│   ├── infisical/              # Scripts para Infisical
│   │   ├── install.sh          # Instalación automática (Bash)
│   │   ├── install.ps1         # Instalación automática (PowerShell)
│   │   ├── clean.sh            # Limpieza completa (Bash)
│   │   ├── clean.ps1           # Limpieza completa (PowerShell)
│   │   └── backup.sh           # Backups
│   ├── postgres/               # Scripts para PostgreSQL
│   │   ├── install.sh          # Instalación automática (Bash)
│   │   ├── install.ps1         # Instalación automática (PowerShell)
│   │   ├── clean.sh            # Limpieza completa (Bash)
│   │   ├── clean.ps1           # Limpieza completa (PowerShell)
│   │   └── backup.sh           # Backups
│   └── devops/                 # Scripts para DevOps Dashboard
│       ├── start-devops.sh     # Iniciar backend y frontend (Bash)
│       ├── start-devops.ps1    # Iniciar backend y frontend (PowerShell)
│       ├── stop-devops.sh      # Detener backend y frontend (Bash)
│       ├── stop-devops.ps1     # Detener backend y frontend (PowerShell)
│       ├── restart-devops.sh   # Reiniciar backend y frontend (Bash)
│       └── restart-devops.ps1  # Reiniciar backend y frontend (PowerShell)
│
├── repos/                       # Scripts para gestionar repositorios
│   ├── clone-all-repos.sh      # Clonar todos los repos
│   └── update-all-repos.sh     # Actualizar todos los repos
│
└── templates/                   # Scripts para crear desde templates
    ├── create-mf.sh            # Crear nuevo microfrontend
    └── create-ms.sh            # Crear nuevo microservicio
```

---

## 🛠️ Scripts de Setup

Scripts automatizados para instalar y configurar servicios de infraestructura (Infisical, PostgreSQL, etc.).

### 📋 Requisitos Previos

- Linux (Ubuntu/Debian recomendado) o Windows
- Acceso sudo/root (Linux) o permisos de administrador (Windows)
- Conexión a internet
- Docker y Docker Compose instalados
- Repositorio `agendia-infra` disponible

---

### 🚀 Uso Rápido

#### Linux/Mac (Bash)

**Infisical:**
```bash
cd agendia-dev-scripts/setup/infisical
chmod +x install.sh backup.sh clean.sh
sudo ./install.sh
```

**PostgreSQL:**
```bash
cd agendia-dev-scripts/setup/postgres
chmod +x install.sh backup.sh clean.sh
sudo ./install.sh
```

**DevOps Dashboard:**
```bash
cd agendia-dev-scripts/setup/devops
chmod +x start-devops.sh stop-devops.sh restart-devops.sh
./start-devops.sh
```

#### Windows (PowerShell)

**Infisical:**
```powershell
cd agendia-dev-scripts\setup\infisical
.\install.ps1
```

**PostgreSQL:**
```powershell
cd agendia-dev-scripts\setup\postgres
.\install.ps1
```

**DevOps Dashboard:**
```powershell
cd agendia-dev-scripts\setup\devops
.\start-devops.ps1
```

---

### 📝 Configuración

#### Archivos .env

Los scripts **NO crean** archivos `.env` automáticamente. Debes crearlos manualmente:

**Linux/Mac:**
```bash
# Agendia usa env centralizado en la raíz
cp .env.dev.example .env.dev
cp .env.local.example .env.local
```

**Windows:**
```powershell
Copy-Item .env.dev.example .env.dev
Copy-Item .env.local.example .env.local
```

#### Entornos

Todos los scripts aceptan parámetro de entorno:
- **Linux/Mac:** `--env ENTORNO`
- **Windows:** `-Environment ENTORNO`

Valores:
- `local`: Desarrollo local
- `dev`: Desarrollo compartido (default)
- `staging`: Pre-producción
- `prod`: Producción

**Ejemplos:**
```bash
# Linux/Mac
sudo ./install.sh --env prod
```

```powershell
# Windows
.\install.ps1 -Environment prod
```

---

### 🔐 Infisical

#### Instalación

**Windows:**
```powershell
.\install.ps1 -Environment dev
```

**Linux:**
```bash
sudo ./install.sh --env dev
```

**Configuración:**
- Usa archivo `docker-compose.{entorno}.yml` (default: `docker-compose.dev.yml`)
- Logs guardados en: `logs/setup/infisical/`
- Puerto: `localhost:5002`
- Redis expuesto en: `localhost:5001`

#### Limpieza

**Windows:**
```powershell
.\clean.ps1 -Environment dev
.\clean.ps1 -Environment dev -RemoveImages  # También eliminar imágenes
.\clean.ps1 -Environment dev -RemoveData:$false  # Mantener datos locales
```

**Linux:**
```bash
./clean.sh --env dev
./clean.sh --env dev --remove-images  # También eliminar imágenes
./clean.sh --env dev --keep-data      # Mantener datos locales
```

**Qué elimina:**
- Contenedores (agendia-infisical-backend, agendia-infisical-db, agendia-infisical-redis)
- Volúmenes de Docker
- Redes
- Opcional: Imágenes de Docker
- Opcional: Directorios de datos locales (data/, logs/, backups/)

---

### 🐘 PostgreSQL

#### Instalación

**Windows:**
```powershell
.\install.ps1 -Environment dev
```

**Linux:**
```bash
sudo ./install.sh --env dev
```

**Configuración:**
- Usa archivo `docker-compose.{entorno}.yml` (default: `docker-compose.dev.yml`)
- Logs guardados en: `logs/setup/postgres/`
- Puerto: `localhost:5003`
- Base de datos: `agendia_dev` (configurable en `.env.dev`)

#### Limpieza

**Windows:**
```powershell
.\clean.ps1 -Environment dev
.\clean.ps1 -Environment dev -RemoveImages  # También eliminar imágenes
.\clean.ps1 -Environment dev -RemoveData:$false  # Mantener datos locales
```

**Linux:**
```bash
./clean.sh --env dev
./clean.sh --env dev --remove-images  # También eliminar imágenes
./clean.sh --env dev --keep-data      # Mantener datos locales
```

**Qué elimina:**
- Contenedores (agendia-postgres)
- Volúmenes de Docker
- Redes
- Opcional: Imágenes de Docker
- Opcional: Directorios de datos locales (data/postgres/, logs/, backups/)

---

### ✅ Checklist de Instalación

#### Antes de Ejecutar install.sh/install.ps1

**1. Requisitos del Sistema:**
- [ ] Linux (Ubuntu/Debian recomendado) o Windows
- [ ] Acceso sudo/root (Linux) o permisos de administrador (Windows)
- [ ] Conexión a internet
- [ ] Docker y Docker Compose instalados
- [ ] Repositorio `agendia-infra` disponible

**2. Preparar Archivos .env:**

**PostgreSQL:**
```bash
# Agendia usa env centralizado en la raíz
cp .env.local.example .env.local
cp .env.dev.example .env.dev

# Editar y completar valores según tu entorno
nano .env.local
```

**Infisical:**
```bash
# Variables de Infisical también viven en /.env.local y /.env.dev (raíz)
```

**3. Ejecutar Scripts:**

Ver sección [Uso Rápido](#-uso-rápido) más arriba.

---

#### Después de la Instalación

**Verificar Instalación:**

**PostgreSQL:**
```bash
docker ps | grep agendia-postgres
docker exec agendia-postgres pg_isready -U postgres
```

**Infisical:**
```bash
docker ps | grep agendia-infisical
curl http://localhost:5002
```

**Verificar Backups Automáticos:**

```bash
# Verificar crontab (Linux)
crontab -l | grep backup.sh

# Verificar logs de backup
tail -f agendia-infra/setup/postgres/backups/backup.log
tail -f agendia-infra/setup/infisical/backups/backup.log
```

---

#### Troubleshooting

**Error: "No se encontró docker-compose.dev.yml"**
- Verificar que `agendia-infra` esté en la ruta correcta
- El script busca en:
  - `../../agendia-infra/setup/{servicio}/`
  - `$(pwd)/agendia-infra/setup/{servicio}/`
  - `/opt/agendia/agendia-infra/setup/{servicio}/` (Linux)

**Error: "Archivo .env no encontrado"**
- Los scripts funcionan sin `.env` usando valores por defecto
- Para producción, crear `.env.{entorno}` manualmente

**Error: "Permission denied"**
- Linux: Ejecutar con `sudo`
- Verificar permisos: `chmod +x install.sh backup.sh clean.sh`
- Windows: Ejecutar PowerShell como administrador si es necesario

**Error: "Invalid key length" (Infisical)**
- Verificar que `INFISICAL_ENCRYPTION_KEY` tenga exactamente 32 caracteres hexadecimales (16 bytes)
- Generar nuevo: `openssl rand -hex 16`
- Limpiar completamente: `.\clean.ps1 -Environment dev` (o `./clean.sh --env dev`) y reinstalar

---

**📚 Documentación completa:** Ver [Scripts de Setup](../../agendia-docs/docs/setup/scripts-setup.md)

---

## 🛠️ Scripts del DevOps Dashboard

Scripts para gestionar el DevOps Dashboard (backend .NET y frontend React).

### Iniciar DevOps Dashboard

#### `setup/devops/start-devops.sh` / `setup/devops/start-devops.ps1`

Inicia el backend .NET y el frontend React del DevOps Dashboard en modo desarrollo.

**Bash:**
```bash
cd agendia-dev-scripts/setup/devops
chmod +x start-devops.sh
./start-devops.sh
```

**PowerShell:**
```powershell
cd agendia-dev-scripts\setup\devops
.\start-devops.ps1
```

**Características:**
- Verifica e instala dependencias automáticamente (Node.js, npm, .NET SDK 8.0+)
- Instala dependencias del frontend si no existen (`node_modules`)
- Usa env centralizado en la raíz (no crea `.env` en subcarpetas)
- Inicia backend en `http://localhost:5000`
- Inicia frontend en `http://localhost:3010`
- Guarda los logs en `logs/devops/`
- Guarda los PIDs en `.devops-pids` para poder detenerlos después
- Espera a que los servicios estén listos antes de continuar

**Requisitos:**
- Node.js 18+
- npm
- .NET SDK 8.0+

---

### Detener DevOps Dashboard

#### `setup/devops/stop-devops.sh` / `setup/devops/stop-devops.ps1`

Detiene el backend y frontend del DevOps Dashboard.

**Bash:**
```bash
cd agendia-dev-scripts/setup/devops
chmod +x stop-devops.sh
./stop-devops.sh
```

**PowerShell:**
```powershell
cd agendia-dev-scripts\setup\devops
.\stop-devops.ps1
```

**Características:**
- Lee los PIDs desde `.devops-pids` y detiene los procesos
- Si no encuentra el archivo, intenta detener procesos en los puertos 5000 y 3010
- Muestra un resumen de los procesos detenidos

---

### Reiniciar DevOps Dashboard

#### `setup/devops/restart-devops.sh` / `setup/devops/restart-devops.ps1`

Reinicia el backend y frontend del DevOps Dashboard.

**Bash:**
```bash
cd agendia-dev-scripts/setup/devops
chmod +x restart-devops.sh
./restart-devops.sh
```

**PowerShell:**
```powershell
cd agendia-dev-scripts\setup\devops
.\restart-devops.ps1
```

**Características:**
- Detiene los servicios actuales
- Espera 2 segundos
- Inicia los servicios nuevamente

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
- Guarda los logs en `logs/mf/` (en la raíz del proyecto de scripts)
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

## ⚙️ Gestión de Microservicios

### Instalar Dependencias

#### `microservices/install-all-ms.sh` / `microservices/install-all-ms.ps1`

Instala/compila las dependencias de todos los microservicios automáticamente.

**Bash:**
```bash
./microservices/install-all-ms.sh
```

**PowerShell:**
```powershell
./microservices/install-all-ms.ps1
```

**Características:**
- Ejecuta `sbt compile` en cada microservicio Scala/Akka HTTP
- Solo compila en directorios que existan y tengan `build.sbt`
- Muestra un resumen al final con éxitos, saltados y fallidos

---

### Iniciar Microservicios

#### `microservices/start-all-ms.sh` / `microservices/start-all-ms.ps1`

Inicia todos los microservicios en modo desarrollo en background.

**Bash:**
```bash
./microservices/start-all-ms.sh
```

**PowerShell:**
```powershell
./microservices/start-all-ms.ps1
```

**Características:**
- Inicia todos los MSs en paralelo
- Guarda los logs en `logs/ms/` (en la raíz del proyecto de scripts)
- Guarda los PIDs en `.ms-pids` (en la raíz del proyecto de scripts) para poder detenerlos después
- Espera a que cada servicio esté realmente levantado (build terminado y servidor online)
- Muestra un resumen de los iniciados, saltados y fallidos
- Soporta servicios Scala/Akka HTTP (sbt) y Node/Nest (npm)

---

### Detener Microservicios

#### `microservices/stop-all-ms.sh` / `microservices/stop-all-ms.ps1`

Detiene todos los microservicios que están corriendo.

**Bash:**
```bash
./microservices/stop-all-ms.sh
```

**PowerShell:**
```powershell
./microservices/stop-all-ms.ps1
```

**Características:**
- Lee los PIDs desde `.ms-pids` y detiene los procesos
- Muestra un resumen de los procesos detenidos

---

### Listar Microservicios

#### `microservices/list-all-ms.sh` / `microservices/list-all-ms.ps1`

Lista todos los microservicios que están corriendo actualmente.

**Bash:**
```bash
./microservices/list-all-ms.sh
```

**PowerShell:**
```powershell
./microservices/list-all-ms.ps1
```

**Características:**
- Lee los PIDs desde `.ms-pids` y verifica qué procesos están corriendo
- Muestra el estado de cada MS (corriendo, detenido, no iniciado)
- Muestra un resumen con la cantidad de MSs corriendo, detenidos y no iniciados

---

### Reiniciar Microservicios

#### `microservices/restart-all-ms.sh` / `microservices/restart-all-ms.ps1`

Reinicia todos los microservicios que están corriendo actualmente.

**Bash:**
```bash
./microservices/restart-all-ms.sh
```

**PowerShell:**
```powershell
./microservices/restart-all-ms.ps1
```

**Características:**
- Lee los PIDs desde `.ms-pids` y detiene solo los procesos que están corriendo
- Reinicia automáticamente los microservicios que estaban activos
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
- ✅ No crea `.env*` en subcarpetas (env centralizado)
- ✅ Actualiza automáticamente el shell (`routes.config.ts`) y agrega la URL del MF a `/.env.local`
- ✅ Configura todos los archivos necesarios
- ✅ Limpia archivos temporales

**Qué hace el script:**

1. **Encuentra un puerto disponible** automáticamente
2. **Copia el template** `agendia-template-mf` a `agendia-mf-<nombre>`
3. **Actualiza `package.json`** con el nuevo nombre
4. **Actualiza `vite.config.ts`** con el nuevo nombre y puerto
5. **Actualiza `src/config/root.config.ts`** con la configuración del MF
6. **No crea `.env` por repo**: imprime las variables para correr el MF en dev
7. **Actualiza el shell** automáticamente:
   - Agrega la variable de entorno a `/.env.local` (raíz)
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

## ⚙️ Crear Nuevo Microservicio

### `templates/create-ms.sh`

Crea un nuevo microservicio desde el template base con configuración automática.

```bash
./templates/create-ms.sh <nombre-ms>
```

**Ejemplo:**
```bash
./templates/create-ms.sh agenda
```

**⚠️ Importante:** Solo pasa el nombre del MS **sin** el prefijo `agendia-ms-`. El script agregará automáticamente el prefijo.

- ✅ Correcto: `./templates/create-ms.sh agenda` → crea `agendia-ms-agenda`
- ❌ Incorrecto: `./templates/create-ms.sh agendia-ms-agenda` → crearía `agendia-ms-agendia-ms-agenda`

**💡 Si el repositorio ya está clonado:**
- Si el directorio ya existe, el script solo actualizará los archivos de configuración necesarios
- No sobrescribirá tu código existente
- Útil para configurar repositorios ya clonados

**Características:**
- ✅ Detecta automáticamente un puerto disponible (desde 4001)
- ✅ Actualiza `application.conf` con el puerto correcto
- ✅ Actualiza `openapi.yaml` con el nombre y puerto del servicio
- ✅ Actualiza `README.md` con la configuración del MS
- ✅ Configura todos los archivos necesarios
- ✅ Limpia archivos temporales

**Qué hace el script:**

1. **Encuentra un puerto disponible** automáticamente (desde 4001)
2. **Copia el template** `agendia-template-ms` a `agendia-ms-<nombre>`
3. **Actualiza `application.conf`** con el nuevo nombre y puerto
4. **Actualiza `openapi.yaml`** con el nombre del servicio y puerto
5. **Actualiza `README.md`** con la configuración del MS
6. **Limpia** archivos temporales (`.git` si aplica)

**Próximos pasos después de crear:**

```bash
cd agendia-ms-<nombre>
sbt compile
sbt run
```

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
./microservices/start-all-ms.ps1
./microservices/stop-all-ms.ps1
```

**Recomendación:** En Windows, usa los scripts PowerShell (`.ps1`) para mejor compatibilidad.

---

## 🔍 Archivos Generados

Los scripts generan algunos archivos temporales en la raíz del proyecto de scripts:

- **`.mf-pids`**: Contiene los PIDs de los procesos de microfrontends corriendo (para poder detenerlos)
- **`.ms-pids`**: Contiene los PIDs de los procesos de microservicios corriendo (para poder detenerlos)
- **`logs/mf/`**: Directorio con los logs de cada microfrontend
- **`logs/ms/`**: Directorio con los logs de cada microservicio

Estos archivos están en `.gitignore` y no se deben commitear.

---

## 🚧 Scripts Futuros

La estructura está preparada para futuros scripts:

- **`bffs/`**: Scripts para gestionar BFFs (instalar, iniciar, detener, etc.)
- **`templates/`**: Más scripts para crear componentes desde templates (create-bff.sh, etc.)

---

## 📝 Notas

- Todos los scripts asumen que están en un monorepo donde los repositorios están en el directorio padre del proyecto de scripts.
- Los scripts detectan automáticamente las rutas correctas, así que puedes ejecutarlos desde cualquier ubicación dentro del proyecto de scripts.
- Los archivos de logs y PIDs se comparten entre todos los scripts del mismo tipo:
  - Todos los scripts de MFs comparten el mismo `.mf-pids` y `logs/mf/`
  - Todos los scripts de MSs comparten el mismo `.ms-pids` y `logs/ms/`
- La lista de microservicios gestionados se define en cada script en la variable `MS_DIRS`. Para agregar un nuevo microservicio, recuerda añadirlo a `MS_DIRS` en los scripts correspondientes.
