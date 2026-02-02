# ============================================================================
# Script para configurar e iniciar frontend completo con Docker
# Incluye: shell, template, docs, storybook, devops-dashboard, SSL, nginx build y configuración
# ============================================================================

param(
    [switch]$SkipNetwork,
    [switch]$SkipSSL,
    [switch]$SkipBuild,
    [switch]$Help
)

$ErrorActionPreference = "Stop"

function Write-Info { 
    Write-Host ("ℹ️  " + $args) -ForegroundColor Cyan
}
function Write-Success { 
    Write-Host ("✅ " + $args) -ForegroundColor Green
}
function Write-Warning { 
    Write-Host ("⚠️  " + $args) -ForegroundColor Yellow
}
function Write-Error { 
    Write-Host ("❌ " + $args) -ForegroundColor Red
}

function Show-Help {
    $helpText = "Script para configurar e iniciar frontend completo con Docker`n" +
                "Incluye: shell, template, docs, storybook, devops-dashboard, SSL, nginx build y configuración`n`n" +
                "Uso: .\configure-https.ps1 [opciones]`n`n" +
                "Opciones:`n" +
                "  -SkipNetwork    No crear/conectar red Docker`n" +
                "  -SkipSSL        No generar certificados SSL`n" +
                "  -SkipBuild      No construir imagen de nginx`n" +
                "  -Help           Mostrar esta ayuda"
    Write-Host $helpText
}

if ($Help) {
    Show-Help
    exit 0
}

Write-Info "🚀 Configurando frontend completo (shell, template, docs, storybook, devops, SSL, nginx build, nginx)..."

# Buscar raíz del proyecto de forma robusta
$currentDir = $PSScriptRoot
$projectRoot = $null
while ($currentDir -ne $null -and $currentDir -ne "") {
    if (Test-Path (Join-Path $currentDir "agendia-docs")) {
        $projectRoot = $currentDir
        break
    }
    $currentDir = Split-Path -Parent $currentDir
}

if ($null -eq $projectRoot) {
    Write-Error "No se pudo encontrar la raíz del proyecto (buscando agendia-docs)"
    exit 1
}

$frontendDir = Join-Path $projectRoot "agendia-infra" "setup" "frontend"
$reverseProxyDir = Join-Path $projectRoot "agendia-reverse-proxy"

if (-not (Test-Path "$frontendDir")) {
    Write-Error "Directorio no encontrado: $frontendDir"
    exit 1
}

if (-not (Test-Path "$reverseProxyDir")) {
    Write-Error "Directorio reverse-proxy no encontrado: $reverseProxyDir"
    exit 1
}

# Paso 1: Verificar/Crear red Docker
if (-not $SkipNetwork) {
    Write-Info "Verificando red Docker agendia-network..."
    $networkExists = (docker network ls --filter name=agendia-network --format "{{.Name}}" 2>&1)
    if (-not $networkExists -or $networkExists -ne "agendia-network") {
        Write-Info "Creando red agendia-network..."
        docker network create agendia-network 2>&1 | Out-Null
        Write-Success "Red agendia-network creada"
    } else {
        Write-Success "Red agendia-network existe"
    }
}

# Paso 2: Usar env centralizado en la raíz del workspace
Write-Info "Usando env centralizado en la raíz (.env.local/.env.dev)..."
$rootEnvLocal = Join-Path $projectRoot ".env.local"
$rootEnvDev = Join-Path $projectRoot ".env.dev"
if (-not (Test-Path $rootEnvLocal) -and -not (Test-Path $rootEnvDev)) {
    Write-Error "No se encontró $rootEnvLocal ni $rootEnvDev. Crea uno desde .env.local.example/.env.dev.example en la raíz."
    exit 1
}

# Paso 3: Generar certificados SSL si no existen
if (-not $SkipSSL) {
    $SSL_SCRIPT = Join-Path $reverseProxyDir "scripts\generate-ssl.ps1"
    if (Test-Path "$SSL_SCRIPT") {
        Write-Info "Generando certificados SSL..."
        & "$SSL_SCRIPT"
        Write-Success "Certificados SSL generados"
    } else {
        Write-Warning "Script generate-ssl.ps1 no encontrado en $SSL_SCRIPT"
        Write-Warning "Los certificados SSL pueden no estar disponibles"
    }
}

# Paso 4: Build de nginx (si no se omite)
if (-not $SkipBuild) {
    Write-Info "Construyendo imagen de nginx..."
    Push-Location "$frontendDir"
    try {
        docker compose -f docker-compose.dev.yml build nginx 2>&1 | Out-Null
        Write-Success "Imagen de nginx construida"
    } catch {
        Write-Warning "Error al construir nginx: $_"
    } finally {
        Pop-Location
    }
}

# Paso 5: Iniciar devops-api (backend)
Write-Info "Iniciando devops-api (backend)..."
$backendSetupDir = Join-Path $projectRoot "agendia-infra\setup\backend"
Push-Location "$backendSetupDir"
try {
    docker compose -f docker-compose.dev.yml up -d devops-api
    Write-Success "DevOps API iniciada"
} catch {
    Write-Warning "Error al iniciar devops-api: $_"
} finally {
    Pop-Location
}

# Paso 6: Iniciar frontends (incluye devops-dashboard, docs, storybook)
Write-Info "Iniciando frontends (shell, template, docs, storybook, devops)..."
Push-Location "$frontendDir"
try {
    docker compose -f docker-compose.dev.yml up -d shell template docs storybook devops-dashboard
    Start-Sleep -Seconds 5
    Write-Success "Frontends iniciados"
} catch {
    Write-Error ("Error al iniciar frontends: " + $_)
    exit 1
} finally {
    Pop-Location
}

# Paso 7: Iniciar nginx
Write-Info "Iniciando nginx (reverse-proxy)..."
Push-Location "$frontendDir"
try {
    docker compose -f docker-compose.dev.yml up -d nginx
    Start-Sleep -Seconds 3
    
    $nginxRunning = (docker ps --format '{{.Names}}' 2>&1 | Select-String -Pattern "^agendia-nginx$" -Quiet)
    if ($nginxRunning) {
        Write-Success "Nginx iniciado correctamente"
    } else {
        Write-Warning "Nginx no está corriendo, revisa los logs"
    }
} catch {
    Write-Warning ("Error al iniciar nginx: " + $_)
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
Write-Info "   Docs:     https://docs.localhost:8443"
Write-Info "   Design:   https://design.localhost:8443"
Write-Info "   DevOps:   https://devops.localhost:8443"
Write-Host ""
Write-Info "📦 Servicios en Docker Desktop: agendia-frontend"
Write-Info "   - shell"
Write-Info "   - template"
Write-Info "   - docs"
Write-Info "   - storybook"
Write-Info "   - devops-dashboard"
Write-Info "   - nginx"
Write-Host ""
Write-Host ("💡 Para regenerar SSL: bash " + $reverseProxyDir + "\scripts\generate-ssl.ps1")
