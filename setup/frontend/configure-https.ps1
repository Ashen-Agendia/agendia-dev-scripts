# ============================================================================
# Script para configurar e iniciar frontend completo con Docker
# Incluye: shell, template, SSL generation, nginx build y configuración
# ============================================================================

param(
    [switch]$SkipNetwork,
    [switch]$SkipSSL,
    [switch]$SkipBuild,
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
Script para configurar e iniciar frontend completo con Docker
Incluye: shell, template, SSL generation, nginx build y configuración

Uso: .\configure-https.ps1 [opciones]

Opciones:
  -SkipNetwork    No crear/conectar red Docker
  -SkipSSL        No generar certificados SSL
  -SkipBuild      No construir imagen de nginx
  -Help           Mostrar esta ayuda
"@
}

if ($Help) {
    Show-Help
    exit 0
}

Write-Info "🚀 Configurando frontend completo (shell, template, SSL, nginx build, nginx)..."

$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$frontendDir = Join-Path $projectRoot "agendia-infra" "setup" "frontend"
$reverseProxyDir = Join-Path $projectRoot "agendia-reverse-proxy"

if (-not (Test-Path $frontendDir)) {
    Write-Error "Directorio no encontrado: $frontendDir"
    exit 1
}

if (-not (Test-Path $reverseProxyDir)) {
    Write-Error "Directorio reverse-proxy no encontrado: $reverseProxyDir"
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

# Paso 2: Configurar .env.dev del reverse-proxy
Write-Info "Configurando .env.dev del reverse-proxy..."
$ENV_FILE = Join-Path $reverseProxyDir ".env.dev"
if (-not (Test-Path $ENV_FILE)) {
    $envExample = Join-Path $reverseProxyDir "env.dev.example"
    if (Test-Path $envExample) {
        Copy-Item $envExample $ENV_FILE
    } else {
        $envExampleAlt = Join-Path $reverseProxyDir ".env.example"
        if (Test-Path $envExampleAlt) {
            Copy-Item $envExampleAlt $ENV_FILE
        } else {
            Write-Warning "No se encontró env.dev.example, creando .env.dev con valores por defecto"
            @"
DOMAIN_NAME=localhost
AGENDIA_IP=127.0.0.1
FRONTEND_HOST=agendia-frontend-shell
FRONTEND_PORT=3000
BACKEND_HOST=agendia-api-gateway
BACKEND_PORT=8080
INFISICAL_HOST=agendia-infisical
INFISICAL_PORT=8080
INFISICAL_DOMAIN=infisical.localhost
SHELL_HOST=agendia-frontend-shell
SHELL_PORT=3000
SHELL_DOMAIN=shell.localhost
TEMPLATE_HOST=agendia-frontend-template
TEMPLATE_PORT=3001
TEMPLATE_DOMAIN=template.localhost
API_GATEWAY_HOST=agendia-api-gateway
API_GATEWAY_PORT=8080
TEMPLATE_MS_HOST=agendia-backend-template-ms
TEMPLATE_MS_PORT=4001
"@ | Out-File -FilePath $ENV_FILE -Encoding utf8
        }
    }
    Write-Success ".env.dev creado"
} else {
    Write-Info ".env.dev ya existe"
}

# Paso 3: Generar certificados SSL si no existen
if (-not $SkipSSL) {
    $SSL_SCRIPT = Join-Path $reverseProxyDir "scripts\generate-ssl.ps1"
    if (Test-Path $SSL_SCRIPT) {
        Write-Info "Generando certificados SSL..."
        & $SSL_SCRIPT
        Write-Success "Certificados SSL generados"
    } else {
        Write-Warning "Script generate-ssl.ps1 no encontrado en $SSL_SCRIPT"
        Write-Warning "Los certificados SSL pueden no estar disponibles"
    }
}

# Paso 4: Build de nginx (si no se omite)
if (-not $SkipBuild) {
    Write-Info "Construyendo imagen de nginx..."
    Push-Location $frontendDir
    try {
        docker compose -f docker-compose.dev.yml build nginx 2>&1 | Out-Null
        Write-Success "Imagen de nginx construida"
    } catch {
        Write-Warning "Error al construir nginx: $_"
    } finally {
        Pop-Location
    }
}

# Paso 5: Iniciar frontends (shell y template)
Write-Info "Iniciando frontends (shell y template)..."
Push-Location $frontendDir
try {
    docker compose -f docker-compose.dev.yml up -d shell template
    Start-Sleep -Seconds 5
    Write-Success "Frontends iniciados"
} catch {
    Write-Error "Error al iniciar frontends: $_"
    exit 1
} finally {
    Pop-Location
}

# Paso 6: Iniciar nginx
Write-Info "Iniciando nginx (reverse-proxy)..."
Push-Location $frontendDir
try {
    docker compose -f docker-compose.dev.yml up -d nginx
    Start-Sleep -Seconds 3
    
    $nginxRunning = docker ps --format '{{.Names}}' 2>&1 | Select-String -Pattern "^agendia-nginx$" -Quiet
    if ($nginxRunning) {
        Write-Success "Nginx iniciado correctamente"
    } else {
        Write-Warning "Nginx no está corriendo, revisa los logs"
    }
} catch {
    Write-Warning "Error al iniciar nginx: $_"
} finally {
    Pop-Location
}

Write-Success "🎉 Configuración de frontend completada"
Write-Host ""
Write-Info "🌐 Servicios disponibles:"
Write-Info "   Shell:    http://localhost:3000"
Write-Info "   Template: http://localhost:3001"
Write-Info "   HTTPS:    https://localhost:8443"
Write-Info "   API:      https://api.localhost:8443"
Write-Host ""
Write-Info "📦 Servicios en Docker Desktop: agendia-frontend"
Write-Info "   - shell"
Write-Info "   - template"
Write-Info "   - nginx"
Write-Host ""
Write-Info "💡 Para regenerar SSL: bash $reverseProxyDir\scripts\generate-ssl.ps1"
