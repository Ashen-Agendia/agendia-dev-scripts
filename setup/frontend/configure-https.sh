#!/bin/bash
# ============================================================================
# Script para configurar e iniciar frontend completo con Docker
# Incluye: shell, template, SSL generation, nginx build y configuración
# ============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
success() { echo -e "${GREEN}✅ $1${NC}"; }
warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; }

SKIP_NETWORK="${SKIP_NETWORK:-false}"
SKIP_SSL="${SKIP_SSL:-false}"
SKIP_BUILD="${SKIP_BUILD:-false}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
FRONTEND_DIR="$PROJECT_ROOT/agendia-infra/setup/frontend"
REVERSE_PROXY_DIR="$PROJECT_ROOT/agendia-reverse-proxy"

if [ ! -d "$FRONTEND_DIR" ]; then
    error "Directorio no encontrado: $FRONTEND_DIR"
    exit 1
fi

if [ ! -d "$REVERSE_PROXY_DIR" ]; then
    error "Directorio reverse-proxy no encontrado: $REVERSE_PROXY_DIR"
    exit 1
fi

info "🚀 Configurando frontend completo (shell, template, SSL, nginx build, nginx)..."

# Paso 1: Verificar/Crear red Docker
if [ "$SKIP_NETWORK" != "true" ]; then
    info "Verificando red Docker agendia-network..."
    if ! docker network ls | grep -q "agendia-network"; then
        info "Creando red agendia-network..."
        docker network create agendia-network
        success "Red agendia-network creada"
    else
        success "Red agendia-network existe"
    fi
fi

# Paso 2: Configurar .env.dev del reverse-proxy
info "Usando env centralizado en la raíz (.env.local/.env.dev)..."
ROOT_ENV_LOCAL="$PROJECT_ROOT/.env.local"
ROOT_ENV_DEV="$PROJECT_ROOT/.env.dev"
if [ ! -f "$ROOT_ENV_LOCAL" ] && [ ! -f "$ROOT_ENV_DEV" ]; then
    error "No se encontró $ROOT_ENV_LOCAL ni $ROOT_ENV_DEV. Crea uno desde .env.local.example/.env.dev.example en la raíz."
    exit 1
fi

# Paso 3: Generar certificados SSL si no existen
if [ "$SKIP_SSL" != "true" ]; then
    SSL_SCRIPT="$REVERSE_PROXY_DIR/scripts/generate-ssl.sh"
    if [ -f "$SSL_SCRIPT" ]; then
        info "Generando certificados SSL..."
        chmod +x "$SSL_SCRIPT" 2>/dev/null || true
        # generate-ssl.sh auto-detecta ../.env.local o ../.env.dev
        bash "$SSL_SCRIPT" || warning "Error al generar SSL, continuando..."
    else
        warning "Script generate-ssl.sh no encontrado en $SSL_SCRIPT"
        warning "Los certificados SSL pueden no estar disponibles"
    fi
fi

# Paso 4: Build de nginx (si no se omite)
if [ "$SKIP_BUILD" != "true" ]; then
    info "Construyendo imagen de nginx..."
    cd "$FRONTEND_DIR"
    docker compose -f docker-compose.dev.yml build nginx || warning "Error al construir nginx, continuando..."
fi

# Paso 5: Iniciar frontends (shell y template)
info "Iniciando frontends (shell, template y auth)..."
cd "$FRONTEND_DIR"
docker compose -f docker-compose.dev.yml up -d shell template auth-frontend

# Esperar un poco para que los frontends inicien
sleep 5

# Paso 6: Iniciar nginx
info "Iniciando nginx (reverse-proxy)..."
docker compose -f docker-compose.dev.yml up -d nginx
sleep 3

if docker ps --format '{{.Names}}' | grep -q "^agendia-nginx$"; then
    success "Nginx iniciado correctamente"
else
    warning "Nginx no está corriendo, revisa los logs"
fi

success "🎉 Configuración de frontend completada"
echo ""
info "🌐 Servicios disponibles:"
info "   Shell:    http://localhost:3000"
info "   Template: http://localhost:3001"
info "   Auth:     http://localhost:3002"
info "   HTTPS:    https://localhost:8443"
info "   Auth Sub: https://auth.localhost:8443"
info "   API:      https://api.localhost:8443"
echo ""
info "📦 Servicios en Docker Desktop: agendia-frontend"
info "   - shell"
info "   - template"
info "   - auth-frontend"
info "   - nginx"
echo ""
info "💡 Para regenerar SSL: bash $REVERSE_PROXY_DIR/scripts/generate-ssl.sh"
