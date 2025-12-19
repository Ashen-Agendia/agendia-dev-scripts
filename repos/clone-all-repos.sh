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

# Verificar dependencias
echo "🔍 Verificando dependencias..."
echo ""

missing_deps=()

if ! command_exists gh; then
    missing_deps+=("gh")
fi

if ! command_exists jq; then
    missing_deps+=("jq")
fi

if [ ${#missing_deps[@]} -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Faltan las siguientes dependencias: ${missing_deps[*]}${NC}"
    echo ""
    echo "Por favor instala las dependencias ejecutando:"
    echo "  ./install-system-deps.sh"
    echo ""
    echo "O instala manualmente:"
    for dep in "${missing_deps[@]}"; do
        case $dep in
            gh)
                echo "  - GitHub CLI: https://github.com/cli/cli/blob/trunk/docs/install_linux.md"
                ;;
            jq)
                echo "  - jq: https://stedolan.github.io/jq/download/"
                ;;
        esac
    done
    exit 1
fi

echo -e "${GREEN}✅ Todas las dependencias están instaladas${NC}"
echo ""

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

