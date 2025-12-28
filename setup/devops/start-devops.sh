#!/bin/bash

echo "🚀 Iniciando DevOps Dashboard (backend y frontend)..."
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_ROOT="$(dirname "$SCRIPT_DIR")"
ROOT_DIR="$(dirname "$SCRIPTS_ROOT")"

DEVOPS_DIR="$ROOT_DIR/agendia-infra/setup/devops"
BACKEND_ROOT="$DEVOPS_DIR/backend"
BACKEND_DIR="$BACKEND_ROOT/Agendia.DevOps.Api"
FRONTEND_DIR="$DEVOPS_DIR/frontend"

PIDS_FILE="$SCRIPTS_ROOT/.devops-pids"
LOGS_DIR="$SCRIPTS_ROOT/logs/devops"

BACKEND_PORT=6001
FRONTEND_PORT=6002

STARTED=0
FAILED=0

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

check_and_install_nodejs() {
    if ! command_exists node; then
        warning "Node.js no está instalado. Intentando instalar..."
        local pm=$(detect_package_manager)
        
        if [ "$pm" = "apt" ]; then
            curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
            sudo apt-get install -y nodejs
        elif [ "$pm" = "dnf" ]; then
            sudo dnf install -y nodejs npm
        elif [ "$pm" = "yum" ]; then
            curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
            sudo yum install -y nodejs
        elif [ "$pm" = "brew" ]; then
            brew install node
        else
            error "No se pudo instalar Node.js automáticamente. Instala manualmente desde https://nodejs.org/"
            return 1
        fi
    fi
    
    local node_version=$(node --version | sed 's/v//' | cut -d'.' -f1)
    if [ "$node_version" -lt 18 ]; then
        error "Node.js versión ${node_version} detectada, se requiere 18+"
        return 1
    fi
    
    success "Node.js $(node --version) instalado"
    return 0
}

detect_package_manager() {
    if command_exists apt-get; then
        echo "apt"
    elif command_exists dnf; then
        echo "dnf"
    elif command_exists yum; then
        echo "yum"
    elif command_exists brew; then
        echo "brew"
    else
        echo "unknown"
    fi
}

check_and_install_dotnet() {
    if ! command_exists dotnet; then
        warning ".NET SDK no está instalado. Intentando instalar..."
        
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            if [ "$ID" = "ubuntu" ] || [ "$ID" = "debian" ]; then
                wget https://dot.net/v1/dotnet-install.sh -O dotnet-install.sh
                chmod +x dotnet-install.sh
                ./dotnet-install.sh --channel 8.0
                rm dotnet-install.sh
                
                export PATH="$HOME/.dotnet:$PATH"
                export DOTNET_ROOT="$HOME/.dotnet"
                
                if ! command_exists dotnet; then
                    error "No se pudo instalar .NET SDK automáticamente. Instala manualmente desde https://dotnet.microsoft.com/download"
                    return 1
                fi
            else
                error "No se pudo instalar .NET SDK automáticamente para este sistema. Instala manualmente desde https://dotnet.microsoft.com/download"
                return 1
            fi
        else
            error "No se pudo instalar .NET SDK automáticamente. Instala manualmente desde https://dotnet.microsoft.com/download"
            return 1
        fi
    fi
    
    local dotnet_version=$(dotnet --version | cut -d'.' -f1)
    if [ "$dotnet_version" -lt 8 ]; then
        warning ".NET SDK versión ${dotnet_version} detectada, se requiere 8.0+"
        return 1
    fi
    
    success ".NET SDK $(dotnet --version) instalado"
    return 0
}

info "Verificando dependencias..."
if ! check_and_install_nodejs; then
    exit 1
fi

if ! command_exists npm; then
    error "npm no está instalado"
    exit 1
fi

if ! check_and_install_dotnet; then
    exit 1
fi

echo ""

if [ ! -d "$DEVOPS_DIR" ]; then
    error "Directorio DevOps no encontrado: $DEVOPS_DIR"
    exit 1
fi

if [ ! -d "$BACKEND_DIR" ]; then
    error "Directorio backend no encontrado: $BACKEND_DIR"
    exit 1
fi

if [ ! -d "$FRONTEND_DIR" ]; then
    error "Directorio frontend no encontrado: $FRONTEND_DIR"
    exit 1
fi

if [ -f "$PIDS_FILE" ]; then
    warning "Archivo de PIDs existente encontrado. Los procesos anteriores pueden estar corriendo."
    warning "Ejecuta ./stop-devops.sh primero si quieres detener procesos anteriores."
    rm "$PIDS_FILE"
fi

mkdir -p "$LOGS_DIR"

info "Iniciando backend..."
cd "$BACKEND_DIR" || exit 1

if [ ! -f "$BACKEND_ROOT/.env" ]; then
    warning ".env no encontrado en $BACKEND_ROOT"
    warning "Por favor crea el archivo .env en el directorio backend"
fi

dotnet restore > /dev/null 2>&1
dotnet build > /dev/null 2>&1

BACKEND_LOG="$LOGS_DIR/backend.log"
BACKEND_ERR="$LOGS_DIR/backend.error.log"

dotnet run > "$BACKEND_LOG" 2> "$BACKEND_ERR" &
BACKEND_PID=$!

if kill -0 $BACKEND_PID 2>/dev/null; then
    echo "$BACKEND_PID:backend" >> "$PIDS_FILE"
    success "Backend iniciado (PID: $BACKEND_PID, Puerto: $BACKEND_PORT)"
    ((STARTED++))
    
    info "Esperando a que el backend esté listo..."
    for i in {1..30}; do
        if lsof -ti:$BACKEND_PORT >/dev/null 2>&1; then
            success "Backend listo"
            break
        fi
        sleep 1
    done
else
    error "Error iniciando backend"
    ((FAILED++))
fi

cd "$ROOT_DIR" || exit 1

info "Iniciando frontend..."

DESIGN_SYSTEM_DIR="$ROOT_DIR/agendia-design-system"

if [ -d "$DESIGN_SYSTEM_DIR" ]; then
    if [ ! -d "$DESIGN_SYSTEM_DIR/dist" ]; then
        info "Construyendo design-system..."
        cd "$DESIGN_SYSTEM_DIR" || exit 1
        if [ -d "node_modules" ]; then
            npm run build
        else
            info "Instalando dependencias de design-system..."
            npm install
            if [ $? -eq 0 ]; then
                npm run build
            fi
        fi
        cd "$ROOT_DIR" || exit 1
    fi
fi

cd "$FRONTEND_DIR" || exit 1

if [ ! -d "$FRONTEND_DIR/node_modules" ]; then
    info "Instalando dependencias de frontend..."
    npm install
fi

if [ ! -f "$FRONTEND_DIR/.env" ]; then
    warning ".env no encontrado en $FRONTEND_DIR"
    warning "Por favor crea el archivo .env en el directorio frontend"
fi

FRONTEND_LOG="$LOGS_DIR/frontend.log"
FRONTEND_ERR="$LOGS_DIR/frontend.error.log"

npm run dev > "$FRONTEND_LOG" 2> "$FRONTEND_ERR" &
FRONTEND_PID=$!

if kill -0 $FRONTEND_PID 2>/dev/null; then
    echo "$FRONTEND_PID:frontend" >> "$PIDS_FILE"
    success "Frontend iniciado (PID: $FRONTEND_PID, Puerto: $FRONTEND_PORT)"
    ((STARTED++))
    
    info "Esperando a que el frontend esté listo..."
    for i in {1..60}; do
        if grep -q "Local:\|ready in\|Network:" "$FRONTEND_LOG" 2>/dev/null; then
            success "Frontend listo"
            break
        fi
        sleep 1
    done
else
    error "Error iniciando frontend"
    ((FAILED++))
fi

cd "$ROOT_DIR" || exit 1

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Resumen:"
echo "   ✅ Iniciados: $STARTED"
if [ $FAILED -gt 0 ]; then
    echo "   ❌ Fallidos: $FAILED"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $STARTED -gt 0 ]; then
    echo ""
    success "DevOps Dashboard iniciado"
    echo "   Backend: http://localhost:$BACKEND_PORT"
    echo "   Frontend: http://localhost:$FRONTEND_PORT"
    echo "   Swagger: http://localhost:$BACKEND_PORT/swagger"
    echo ""
    echo "💡 Revisa los logs en logs/devops/ para ver el output de cada servicio."
    echo "   Usa ./stop-devops.sh para detener los servicios."
fi

