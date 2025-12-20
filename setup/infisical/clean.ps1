# ============================================================================
# Script de Limpieza para Infisical (Windows)
# ============================================================================
# Este script limpia completamente Infisical: contenedores, volúmenes, redes, datos
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
Script de Limpieza para Infisical (Windows)

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
  .\clean.ps1 -RemoveData:$false        # No eliminar datos locales
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
    "$ROOT_DIR\agendia-infra\setup\infisical",
    "$PWD\..\..\..\agendia-infra\setup\infisical",
    "$PWD\agendia-infra\setup\infisical",
    "agendia-infra\setup\infisical"
)

$INFISICAL_CONFIG_DIR = $null
foreach ($path in $searchPaths) {
    # Buscar cualquier archivo docker-compose*.yml
    $composeFiles = @("docker-compose.dev.yml", "docker-compose.yml")
    foreach ($composeFile in $composeFiles) {
        $configPath = Join-Path $path $composeFile
        if (Test-Path $configPath) {
            $INFISICAL_CONFIG_DIR = (Resolve-Path $path).Path
            break
        }
    }
    if ($INFISICAL_CONFIG_DIR) {
        break
    }
}

if (-not $INFISICAL_CONFIG_DIR) {
    Write-Error "No se encontró agendia-infra/setup/infisical/docker-compose*.yml"
    Write-Error "Asegúrate de que el repositorio agendia-infra esté disponible"
    exit 1
}

Write-Host ""
Write-Warning "⚠️  ADVERTENCIA: Este script eliminará TODOS los contenedores, volúmenes y datos de Infisical"
Write-Warning "   Entorno: $Environment"
Write-Warning "   Directorio: $INFISICAL_CONFIG_DIR"
Write-Host ""

$confirmation = Read-Host "¿Estás seguro de que deseas continuar? (escribe 'si' para confirmar)"

if ($confirmation -ne "si") {
    Write-Info "Operación cancelada."
    exit 0
}

Write-Host ""
Write-Info "🧹 Iniciando limpieza de Infisical..."
Write-Info "   Directorio de trabajo: $INFISICAL_CONFIG_DIR"
Write-Info "   Entorno: $Environment"
Write-Host ""

# Cambiar al directorio de configuración
Set-Location $INFISICAL_CONFIG_DIR

# Determinar archivo docker-compose según entorno
# Lógica escalable: cuando se agreguen otros entornos, se usarán automáticamente
$COMPOSE_FILE = switch ($Environment) {
    "local" { "docker-compose.dev.yml" }  # Por ahora local usa dev también
    "dev" { "docker-compose.dev.yml" }
    "staging" { "docker-compose.staging.yml" }
    "prod" { "docker-compose.prod.yml" }
    default { "docker-compose.dev.yml" }  # Default: dev
}

if (-not (Test-Path (Join-Path $INFISICAL_CONFIG_DIR $COMPOSE_FILE))) {
    Write-Warning "Archivo docker-compose no encontrado: $COMPOSE_FILE. Intentando limpiar de todas formas..."
}

# Determinar archivo .env para docker-compose (opcional, para referencias)
$ENV_FILE = if ($Environment -eq "local") { ".env" } else { ".env.$Environment" }

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
    "agendia-infisical-backend",
    "agendia-infisical-db",
    "agendia-infisical-redis"
)

foreach ($container in $containers) {
    try {
        $exists = docker ps -a --filter "name=$container" --format "{{.Names}}" 2>&1
        if ($exists -and $exists -match $container) {
            docker rm -f $container 2>&1 | Out-Null
            Write-Success "  Eliminado: $container"
        }
    } catch {
        # Ignorar errores si el contenedor no existe
    }
}

Write-Host ""

# 3. Eliminar volúmenes relacionados
Write-Info "🗑️  Paso 3: Eliminando volúmenes de Docker..."
try {
    $volumes = docker volume ls --filter "name=infisical" --format "{{.Name}}" 2>&1
    if ($volumes) {
        foreach ($volume in ($volumes -split "`n")) {
            $volume = $volume.Trim()
            if ($volume) {
                try {
                    docker volume rm $volume 2>&1 | Out-Null
                    Write-Success "  Volumen eliminado: $volume"
                } catch {
                    Write-Warning "  No se pudo eliminar volumen: $volume (puede estar en uso)"
                }
            }
        }
    } else {
        Write-Info "  No se encontraron volúmenes con nombre 'infisical'"
    }
} catch {
    Write-Warning "Error al listar volúmenes (puede que no existan)"
}

Write-Host ""

# 4. Eliminar redes
Write-Info "🌐 Paso 4: Eliminando redes de Docker..."
try {
    $networks = docker network ls --filter "name=infisical" --format "{{.Name}}" 2>&1
    if ($networks) {
        foreach ($network in ($networks -split "`n")) {
            $network = $network.Trim()
            if ($network -and $network -ne "NETWORK") {
                try {
                    docker network rm $network 2>&1 | Out-Null
                    Write-Success "  Red eliminada: $network"
                } catch {
                    Write-Warning "  No se pudo eliminar red: $network (puede estar en uso)"
                }
            }
        }
    } else {
        Write-Info "  No se encontraron redes con nombre 'infisical'"
    }
} catch {
    Write-Warning "Error al listar redes (puede que no existan)"
}

Write-Host ""

# 5. Eliminar imágenes (opcional)
if ($RemoveImages) {
    Write-Info "🖼️  Paso 5: Eliminando imágenes de Docker..."
    $images = @(
        "infisical/infisical:latest-postgres",
        "postgres:15-alpine",
        "redis:7-alpine"
    )
    
    foreach ($image in $images) {
        try {
            $exists = docker images $image --format "{{.Repository}}:{{.Tag}}" 2>&1
            if ($exists -and $exists -match $image) {
                docker rmi -f $image 2>&1 | Out-Null
                Write-Success "  Imagen eliminada: $image"
            }
        } catch {
            Write-Warning "  No se pudo eliminar imagen: $image"
        }
    }
    Write-Host ""
} else {
    Write-Info "⏭️  Paso 5: Omitido (manteniendo imágenes). Usa -RemoveImages para eliminarlas."
    Write-Host ""
}

# 6. Eliminar directorios de datos (opcional)
if ($RemoveData) {
    Write-Info "📁 Paso 6: Eliminando directorios de datos locales..."
    
    $dataDirs = @(
        "data",
        "logs",
        "backups"
    )
    
    foreach ($dir in $dataDirs) {
        $dirPath = Join-Path $INFISICAL_CONFIG_DIR $dir
        if (Test-Path $dirPath) {
            try {
                Remove-Item -Path $dirPath -Recurse -Force -ErrorAction Stop
                Write-Success "  Directorio eliminado: $dir"
            } catch {
                Write-Warning "  No se pudo eliminar directorio: $dir (puede estar en uso)"
                Write-Warning "    Intenta eliminarlo manualmente: $dirPath"
            }
        } else {
            Write-Info "  Directorio no existe: $dir"
        }
    }
    Write-Host ""
} else {
    Write-Info "⏭️  Paso 6: Omitido (manteniendo datos locales). Usa -RemoveData para eliminarlos."
    Write-Host ""
}

# 7. Limpiar sistema de Docker (opcional, comentado por seguridad)
# Write-Info "🧹 Paso 7: Limpiando sistema de Docker..."
# docker system prune -f 2>&1 | Out-Null
# Write-Success "Sistema de Docker limpiado"
# Write-Host ""

Write-Host ""
Write-Success "🎉 Limpieza completada!"
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host ""
Write-Info "📋 Resumen:"
Write-Host "   ✅ Contenedores eliminados"
Write-Host "   ✅ Volúmenes eliminados"
Write-Host "   ✅ Redes eliminadas"
if ($RemoveImages) {
    Write-Host "   ✅ Imágenes eliminadas"
} else {
    Write-Host "   ℹ️  Imágenes conservadas"
}
if ($RemoveData) {
    Write-Host "   ✅ Datos locales eliminados"
} else {
    Write-Host "   ℹ️  Datos locales conservados"
}
Write-Host ""
Write-Info "🚀 Próximos pasos:"
Write-Host "   1. Verifica que tu .env.$Environment tenga el ENCRYPTION_KEY correcto (32 caracteres hexadecimales = 16 bytes)"
Write-Host "   2. Ejecuta el script de instalación: .\install.ps1 -Environment $Environment"
Write-Host "   3. El script usará automáticamente el archivo: $COMPOSE_FILE"
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host ""
