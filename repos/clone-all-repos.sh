#!/bin/bash

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Función para verificar si un comando existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Función para instalar dependencias
install_dependencies() {
    local missing_deps=()
    
    if ! command_exists gh; then
        missing_deps+=("gh")
    fi
    
    if ! command_exists jq; then
        missing_deps+=("jq")
    fi
    
    if [ ${#missing_deps[@]} -eq 0 ]; then
        return 0
    fi
    
    echo -e "${YELLOW}⚠️  Faltan las siguientes dependencias: ${missing_deps[*]}${NC}"
    echo ""
    
    # Detectar el sistema operativo y gestor de paquetes
    if command_exists apt-get; then
        # Debian/Ubuntu
        echo -e "${YELLOW}Intentando instalar dependencias con apt-get...${NC}"
        sudo apt-get update
        if [[ " ${missing_deps[@]} " =~ " gh " ]]; then
            if ! sudo apt-get install -y gh; then
                echo -e "${RED}❌ No se pudo instalar gh. Por favor instálalo manualmente:${NC}"
                echo "   curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg"
                echo "   echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main\" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null"
                echo "   sudo apt update && sudo apt install gh"
            fi
        fi
        if [[ " ${missing_deps[@]} " =~ " jq " ]]; then
            sudo apt-get install -y jq
        fi
    elif command_exists yum; then
        # CentOS/RHEL/Fedora (versiones antiguas)
        echo -e "${YELLOW}Intentando instalar dependencias con yum...${NC}"
        if [[ " ${missing_deps[@]} " =~ " gh " ]]; then
            if ! sudo yum install -y gh; then
                echo -e "${RED}❌ No se pudo instalar gh. Por favor instálalo manualmente desde: https://github.com/cli/cli/blob/trunk/docs/install_linux.md${NC}"
            fi
        fi
        if [[ " ${missing_deps[@]} " =~ " jq " ]]; then
            sudo yum install -y jq
        fi
    elif command_exists dnf; then
        # Fedora
        echo -e "${YELLOW}Intentando instalar dependencias con dnf...${NC}"
        if [[ " ${missing_deps[@]} " =~ " gh " ]]; then
            if ! sudo dnf install -y gh; then
                echo -e "${RED}❌ No se pudo instalar gh. Por favor instálalo manualmente desde: https://github.com/cli/cli/blob/trunk/docs/install_linux.md${NC}"
            fi
        fi
        if [[ " ${missing_deps[@]} " =~ " jq " ]]; then
            sudo dnf install -y jq
        fi
    elif command_exists brew; then
        # macOS
        echo -e "${YELLOW}Intentando instalar dependencias con brew...${NC}"
        if [[ " ${missing_deps[@]} " =~ " gh " ]]; then
            brew install gh
        fi
        if [[ " ${missing_deps[@]} " =~ " jq " ]]; then
            brew install jq
        fi
    else
        echo -e "${RED}❌ No se detectó un gestor de paquetes compatible.${NC}"
        echo ""
        echo "Por favor instala las dependencias manualmente:"
        if [[ " ${missing_deps[@]} " =~ " gh " ]]; then
            echo "  - gh: https://github.com/cli/cli/blob/trunk/docs/install_linux.md"
        fi
        if [[ " ${missing_deps[@]} " =~ " jq " ]]; then
            echo "  - jq: https://stedolan.github.io/jq/download/"
        fi
        return 1
    fi
    
    echo ""
    # Verificar nuevamente después de la instalación
    local still_missing=()
    for dep in "${missing_deps[@]}"; do
        if ! command_exists "$dep"; then
            still_missing+=("$dep")
        fi
    done
    
    if [ ${#still_missing[@]} -gt 0 ]; then
        echo -e "${RED}❌ Aún faltan dependencias: ${still_missing[*]}${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✅ Todas las dependencias instaladas correctamente${NC}"
    return 0
}

# Verificar e instalar dependencias
echo "🔍 Verificando dependencias..."
echo ""

if ! install_dependencies; then
    echo -e "${RED}❌ Error: No se pudieron instalar todas las dependencias necesarias.${NC}"
    exit 1
fi

# Verificar que gh está autenticado
if ! gh auth status >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  GitHub CLI no está autenticado.${NC}"
    echo "Por favor ejecuta: gh auth login"
    exit 1
fi

echo ""
echo "Clonando todos los repositorios de Ashen-Agendia..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_ROOT="$(dirname "$SCRIPT_DIR")"
ROOT_DIR="$(dirname "$SCRIPTS_ROOT")"

echo "📁 Los repositorios se clonarán en: $ROOT_DIR"
echo ""

cd "$ROOT_DIR" || exit 1

gh repo list Ashen-Agendia --limit 9999 --json url | jq -r '.[].url' | while read url; do
    repo_name=$(basename "$url" .git)
    if [ ! -d "$repo_name" ]; then
        echo "Clonando $repo_name..."
        git clone "$url"
    else
        echo "Ya existe: $repo_name (omitiendo)"
    fi
done

echo ""
echo -e "${GREEN}¡Listo! Todos los repositorios han sido clonados.${NC}"

