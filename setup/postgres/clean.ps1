# ============================================================================
# Script de Limpieza para PostgreSQL (Windows)
# ============================================================================
# Este script limpia completamente PostgreSQL: contenedores, volúmenes, redes, datos
# 
# Uso:
#   .\clean.ps1 [-Environment ENTORNO] [-RemoveImages] [-RemoveData]
#
# Parámetros:
#   -Environment      Entorno: local, dev, staging, prod (default: dev)
#   -RemoveImages     También eliminar las imágenes de Docker (default: false)
#   -RemoveData       También eliminar directorios de datos (data/, logs/, backups/) (default: true)
#   -Help             Mostrar ayuda
# ============================================================================

param(
    [string]$Environment = "dev",
    [switch]$RemoveImages,
    [switch]$RemoveData = $true,
    [switch]$Help
)

$ErrorActionPreference = "Stop"

function Write-Info { Write-Host "ℹ️  $args" -ForegroundColor Cyan }
function Write-Success { Write-Host "✅ $args" -ForegroundColor Green }
function Write-Warning { Write-Host "⚠️  $args" -ForegroundColor Yellow }
function Write-Error { Write-Host "❌ $args" -ForegroundColor Red }

if ($Help) {
    Write-Host @"
Script de Limpieza para PostgreSQL (Windows)

Uso: .\clean.ps1 [-Environment ENTORNO] [-RemoveImages] [-RemoveData] [-Help]

Parámetros:
  -Environment      Entorno: local, dev, staging, prod (default: dev)
  -RemoveImages     También eliminar las imágenes de Docker (default: false)
  -RemoveData       Eliminar directorios de datos (data/, logs/, backups/) (default: true)
  -Help             Mostrar esta ayuda

Ejemplos:
  .\clean.ps1                           # Limpiar entorno dev (mantiene imágenes)
  .\clean.ps1 -Environment prod         # Limpiar entorno prod
  .\clean.ps1 -RemoveImages             # También eliminar imágenes de Docker
  .\clean.ps1 -RemoveData:`$false        # No eliminar datos locales
"@
    exit 0
}

# Validar entorno
if ($Environment -notmatch "^(local|dev|staging|prod)$") {
    Write-Error "Entorno inválido: $Environment. Debe ser: local, dev, staging, o prod"
    exit 1
}

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$SCRIPTS_ROOT = Split-Path -Parent (Split-Path -Parent $SCRIPT_DIR)

# Buscar directorio de configuración
$ROOT_DIR = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $SCRIPT_DIR))

$searchPaths = @(
    "$ROOT_DIR\agendia-infra\setup\postgres",
    "$PWD\..\..\..\agendia-infra\setup\postgres",
    "$PWD\agendia-infra\setup\postgres",
    "agendia-infra\setup\postgres"
)

$POSTGRES_CONFIG_DIR = $null
foreach ($path in $searchPaths) {
    # Buscar cualquier archivo docker-compose*.yml
    $composeFiles = @("docker-compose.dev.yml", "docker-compose.yml")
    foreach ($composeFile in $composeFiles) {
        $configPath = Join-Path $path $composeFile
        if (Test-Path $configPath) {
            $POSTGRES_CONFIG_DIR = (Resolve-Path $path).Path
            break
        }
    }
    if ($POSTGRES_CONFIG_DIR) {
        break
    }
}

if (-not $POSTGRES_CONFIG_DIR) {
    Write-Error "No se encontró agendia-infra/setup/postgres/docker-compose*.yml"
    Write-Error "Asegúrate de que el repositorio agendia-infra esté disponible"
    exit 1
}

Write-Host ""
Write-Warning "⚠️  ADVERTENCIA: Este script eliminará TODOS los contenedores, volúmenes y datos de PostgreSQL"
Write-Warning "   Entorno: $Environment"
Write-Warning "   Directorio: $POSTGRES_CONFIG_DIR"
Write-Host ""

# En modo no interactivo, omitir confirmación
$confirmation = $null
try {
    $confirmation = Read-Host "¿Estás seguro de que deseas continuar? (escribe 'si' para confirmar)"
} catch {
    # Modo no interactivo, continuar automáticamente
    Write-Info "Modo no interactivo detectado, continuando..."
    $confirmation = "si"
}

if ($confirmation -ne "si") {
    Write-Info "Operación cancelada."
    exit 0
}

Write-Host ""
Write-Info "🧹 Iniciando limpieza de PostgreSQL..."
Write-Info "   Directorio de trabajo: $POSTGRES_CONFIG_DIR"
Write-Info "   Entorno: $Environment"
Write-Host ""

# Cambiar al directorio de configuración
Set-Location $POSTGRES_CONFIG_DIR

# Determinar archivo docker-compose según entorno
$COMPOSE_FILE = switch ($Environment) {
    "local" { "docker-compose.dev.yml" }  # Por ahora local usa dev también
    "dev" { "docker-compose.dev.yml" }
    "staging" { "docker-compose.staging.yml" }
    "prod" { "docker-compose.prod.yml" }
    default { "docker-compose.dev.yml" }  # Default: dev
}

if (-not (Test-Path (Join-Path $POSTGRES_CONFIG_DIR $COMPOSE_FILE))) {
    Write-Warning "Archivo docker-compose no encontrado: $COMPOSE_FILE. Intentando limpiar de todas formas..."
}

# 1. Detener y eliminar contenedores
Write-Info "🛑 Paso 1: Deteniendo y eliminando contenedores..."
try {
    docker-compose -f $COMPOSE_FILE down -v 2>&1 | Out-Null
    Write-Success "Contenedores detenidos y eliminados"
} catch {
    Write-Warning "Algunos contenedores pueden no haber sido eliminados (puede que no existan)"
}

Write-Host ""

# 2. Eliminar contenedores por nombre (por si acaso)
Write-Info "🗑️  Paso 2: Eliminando contenedores por nombre..."
$containers = @(
    "agendia-postgres"
)

foreach ($container in $containers) {
    try {
        docker rm -f $container 2>&1 | Out-Null
        Write-Success "   Contenedor eliminado: $container"
    } catch {
        # Ignorar si el contenedor no existe
    }
}

Write-Host ""

# 3. Eliminar volúmenes de Docker
Write-Info "🗑️  Paso 3: Eliminando volúmenes de Docker..."
try {
    $volumes = docker volume ls --filter "name=postgres" --format "{{.Name}}" 2>&1
    if ($volumes) {
        $volumes | ForEach-Object {
            docker volume rm $_ 2>&1 | Out-Null
            Write-Success "   Volumen eliminado: $_"
        }
    } else {
        Write-Info "   No se encontraron volúmenes de PostgreSQL"
    }
} catch {
    Write-Warning "No se pudieron eliminar algunos volúmenes (puede que no existan)"
}

Write-Host ""

# 4. Eliminar redes
Write-Info "🗑️  Paso 4: Eliminando redes..."
try {
    $networks = docker network ls --filter "name=agendia" --format "{{.Name}}" 2>&1
    if ($networks) {
        $networks | ForEach-Object {
            if ($_ -match "postgres" -or $_ -match "agendia-network") {
                docker network rm $_ 2>&1 | Out-Null
                Write-Success "   Red eliminada: $_"
            }
        }
    } else {
        Write-Info "   No se encontraron redes de PostgreSQL"
    }
} catch {
    Write-Warning "No se pudieron eliminar algunas redes (puede que no existan)"
}

Write-Host ""

# 5. Eliminar imágenes (opcional)
if ($RemoveImages) {
    Write-Info "🗑️  Paso 5: Eliminando imágenes de Docker..."
    try {
        $images = docker images --filter "reference=postgres:15-alpine" --format "{{.ID}}" 2>&1
        if ($images) {
            $images | ForEach-Object {
                docker rmi -f $_ 2>&1 | Out-Null
                Write-Success "   Imagen eliminada: $_"
            }
        } else {
            Write-Info "   No se encontraron imágenes de PostgreSQL"
        }
    } catch {
        Write-Warning "No se pudieron eliminar algunas imágenes"
    }
    Write-Host ""
} else {
    Write-Info "⏭️  Paso 5: Omitiendo eliminación de imágenes (usa -RemoveImages para eliminarlas)"
    Write-Host ""
}

# 6. Eliminar directorios de datos locales (opcional)
if ($RemoveData) {
    Write-Info "🗑️  Paso 6: Eliminando directorios de datos locales..."
    $dataDirs = @(
        "data/postgres",
        "logs",
        "backups"
    )
    
    foreach ($dir in $dataDirs) {
        $dirPath = Join-Path $POSTGRES_CONFIG_DIR $dir
        if (Test-Path $dirPath) {
            try {
                Remove-Item -Path $dirPath -Recurse -Force -ErrorAction Stop
                Write-Success "   Directorio eliminado: $dir"
            } catch {
                Write-Warning "   No se pudo eliminar: $dir ($_)"
            }
        } else {
            Write-Info "   Directorio no existe: $dir"
        }
    }
    Write-Host ""
} else {
    Write-Info "⏭️  Paso 6: Manteniendo directorios de datos locales (usa -RemoveData para eliminarlos)"
    Write-Host ""
}

# Resumen final
Write-Host ""
Write-Success "🎉 Limpieza de PostgreSQL completada!"
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host ""
Write-Info "📋 Resumen:"
Write-Host "   ✅ Contenedores eliminados"
Write-Host "   ✅ Volúmenes de Docker eliminados"
Write-Host "   ✅ Redes eliminadas"
if ($RemoveImages) {
    Write-Host "   ✅ Imágenes eliminadas"
} else {
    Write-Host "   ⏭️  Imágenes mantenidas"
}
if ($RemoveData) {
    Write-Host "   ✅ Datos locales eliminados"
} else {
    Write-Host "   ⏭️  Datos locales mantenidos"
}
Write-Host ""
Write-Info "💡 Próximos pasos:"
Write-Host "   1. Verifica que tu .env.$Environment tenga las credenciales correctas"
Write-Host "   2. Ejecuta el script de instalación nuevamente:"
Write-Host "      .\install.ps1 -Environment $Environment"
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
