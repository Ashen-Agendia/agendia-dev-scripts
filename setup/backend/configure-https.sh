#!/bin/bash
# ============================================================================
# Script para configurar e iniciar backend con Docker (completo)
# Incluye: API Gateway y template-ms
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
BACKEND_DIR="$PROJECT_ROOT/agendia-infra/setup/backend"

if [ ! -d "$BACKEND_DIR" ]; then
    error "Directorio no encontrado: $BACKEND_DIR"
    exit 1
fi

info "🚀 Configurando backend completo (API Gateway, auth-ms y template-ms)..."

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

# Paso 2: Iniciar backend (auth-ms y template-ms primero, luego API Gateway)
info "Iniciando backend (auth-ms, template-ms y API Gateway)..."
cd "$BACKEND_DIR"

# Iniciar servicios dependientes
info "Iniciando auth-ms..."
docker compose -f docker-compose.dev.yml up -d auth-ms

info "Iniciando template-ms..."
docker compose -f docker-compose.dev.yml up -d template-ms

# Esperar a que los servicios estén listos
info "Esperando a que los servicios estén listos..."
sleep 10

# Luego API Gateway
info "Iniciando API Gateway..."
docker compose -f docker-compose.dev.yml up -d api-gateway

# Esperar un poco para que los servicios inicien
sleep 10

# Verificar que los servicios estén corriendo
info "Verificando servicios..."
if docker ps --format '{{.Names}}' | grep -q "^agendia-api-gateway$"; then
    success "API Gateway iniciado correctamente"
else
    warning "API Gateway no está corriendo, revisa los logs"
fi

if docker ps --format '{{.Names}}' | grep -q "^agendia-backend-template-ms$"; then
    success "Template MS iniciado correctamente"
else
    warning "Template MS no está corriendo, revisa los logs"
fi

if docker ps --format '{{.Names}}' | grep -q "^agendia-ms-auth$"; then
    success "Auth MS iniciado correctamente"
else
    warning "Auth MS no está corriendo, revisa los logs"
fi

success "🎉 Configuración de backend completada"
echo ""
info "🌐 Servicios disponibles:"
info "   API Gateway: http://localhost:8080"
info "   Template MS: http://localhost:4001"
info "   Auth MS:     http://localhost:8082 (interno: 8081)"
info "   Health checks:"
info "     - API Gateway: http://localhost:8080/health"
info "     - Template MS: http://localhost:4001/health"
info "     - Auth MS:     http://localhost:8082/health"
info "     - Via Gateway: http://localhost:8080/auth/health"
echo ""
info "📦 Servicios en Docker Desktop: agendia-backend"
info "   - api-gateway"
info "   - template-ms"
info "   - auth-ms"
echo ""
info "💡 Nota: Los servicios pueden tardar unos minutos en compilar la primera vez"
info "   Revisa los logs con: docker logs agendia-api-gateway"
