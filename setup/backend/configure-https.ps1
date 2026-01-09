# ============================================================================
# Script para configurar e iniciar backend con Docker (completo)
# Incluye: API Gateway y template-ms
# ============================================================================

param(
    [switch]$SkipNetwork,
    [switch]$Help
)

$ErrorActionPreference = "Stop"

function Write-Info { 
    Write-Host "ℹ️  $args" -ForegroundColor Cyan
}
function Write-Success { 
    Write-Host "✅ $args" -ForegroundColor Green
}
function Write-Warning { 
    Write-Host "⚠️  $args" -ForegroundColor Yellow
}
function Write-Error { 
    Write-Host "❌ $args" -ForegroundColor Red
}

function Show-Help {
    Write-Host @"
Script para configurar e iniciar backend con Docker (completo)
Incluye: API Gateway y template-ms

Uso: .\configure-https.ps1 [opciones]

Opciones:
  -SkipNetwork    No crear/conectar red Docker
  -Help           Mostrar esta ayuda
"@
}

if ($Help) {
    Show-Help
    exit 0
}

Write-Info "🚀 Configurando backend completo (API Gateway y template-ms)..."

$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$backendDir = Join-Path $projectRoot "agendia-infra" "setup" "backend"

if (-not (Test-Path $backendDir)) {
    Write-Error "Directorio no encontrado: $backendDir"
    exit 1
}

# Paso 1: Verificar/Crear red Docker
if (-not $SkipNetwork) {
    Write-Info "Verificando red Docker agendia-network..."
    $networkExists = docker network ls --filter name=agendia-network --format "{{.Name}}" 2>&1
    if (-not $networkExists -or $networkExists -ne "agendia-network") {
        Write-Info "Creando red agendia-network..."
        docker network create agendia-network 2>&1 | Out-Null
        Write-Success "Red agendia-network creada"
    } else {
        Write-Success "Red agendia-network existe"
    }
}

# Paso 2: Iniciar backend (template-ms primero, luego API Gateway)
Write-Info "Iniciando backend (template-ms y API Gateway)..."
Push-Location $backendDir
try {
    # Primero template-ms (API Gateway depende de él)
    Write-Info "Iniciando template-ms..."
    docker compose -f docker-compose.dev.yml up -d template-ms
    
    # Esperar a que template-ms esté listo
    Write-Info "Esperando a que template-ms esté listo..."
    Start-Sleep -Seconds 10
    
    # Luego API Gateway
    Write-Info "Iniciando API Gateway..."
    docker compose -f docker-compose.dev.yml up -d api-gateway
    
    # Esperar un poco para que los servicios inicien
    Start-Sleep -Seconds 10
    
    # Verificar que los servicios estén corriendo
    Write-Info "Verificando servicios..."
    $apiGatewayRunning = docker ps --format '{{.Names}}' 2>&1 | Select-String -Pattern "^agendia-api-gateway$" -Quiet
    if ($apiGatewayRunning) {
        Write-Success "API Gateway iniciado correctamente"
    } else {
        Write-Warning "API Gateway no está corriendo, revisa los logs"
    }
    
    $templateMsRunning = docker ps --format '{{.Names}}' 2>&1 | Select-String -Pattern "^agendia-backend-template-ms$" -Quiet
    if ($templateMsRunning) {
        Write-Success "Template MS iniciado correctamente"
    } else {
        Write-Warning "Template MS no está corriendo, revisa los logs"
    }
} catch {
    Write-Error "Error al iniciar backend: $_"
    exit 1
} finally {
    Pop-Location
}

Write-Success "🎉 Configuración de backend completada"
Write-Host ""
Write-Info "🌐 Servicios disponibles:"
Write-Info "   API Gateway: http://localhost:8080"
Write-Info "   Template MS: http://localhost:4001"
Write-Info "   Health checks:"
Write-Info "     - API Gateway: http://localhost:8080/health"
Write-Info "     - Template MS: http://localhost:4001/health"
Write-Info "     - Via Gateway: http://localhost:8080/template/health"
Write-Host ""
Write-Info "📦 Servicios en Docker Desktop: agendia-backend"
Write-Info "   - api-gateway"
Write-Info "   - template-ms"
Write-Host ""
Write-Info "💡 Nota: Los servicios pueden tardar unos minutos en compilar la primera vez"
Write-Info "   Revisa los logs con: docker logs agendia-api-gateway"
