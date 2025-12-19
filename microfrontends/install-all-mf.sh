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

# Verificar que npm esté instalado
if ! command_exists npm; then
    echo -e "${RED}❌ Error: npm no está instalado${NC}"
    echo ""
    echo "Por favor instala Node.js y npm primero ejecutando:"
    echo "  ./install-system-deps.sh"
    echo ""
    echo "O instala manualmente desde: https://nodejs.org/"
    exit 1
fi

echo "Instalando dependencias en todos los microfrontends..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_ROOT="$(dirname "$SCRIPT_DIR")"
ROOT_DIR="$(dirname "$SCRIPTS_ROOT")"

MF_DIRS=(
  "agendia-template-mf"
  "agendia-mf-shell"
  "agendia-mf-auth"
  "agendia-mf-agenda"
  "agendia-mf-sales"
  "agendia-mf-clients"
  "agendia-mf-dashboard"
  "agendia-mf-organization"
  "agendia-mf-platform"
  "agendia-mf-landing"
  "agendia-mf-public-booking"
)

INSTALLED=0
SKIPPED=0
FAILED=0

for dir in "${MF_DIRS[@]}"; do
  dirPath="$ROOT_DIR/$dir"
  if [ -d "$dirPath" ] && [ -f "$dirPath/package.json" ]; then
    echo ""
    echo "📦 Instalando dependencias en $dir..."
    cd "$dirPath" || continue
    
    if npm install; then
      echo "✅ $dir instalado correctamente"
      ((INSTALLED++))
    else
      echo "❌ Error instalando $dir"
      ((FAILED++))
    fi
    
    cd "$ROOT_DIR" || continue
  else
    echo "⏭️  Saltando $dir (no existe o no tiene package.json)"
    ((SKIPPED++))
  fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Resumen:"
echo "   ✅ Instalados: $INSTALLED"
echo "   ⏭️  Saltados: $SKIPPED"
echo "   ❌ Fallidos: $FAILED"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $FAILED -eq 0 ]; then
  echo "🎉 ¡Todas las instalaciones completadas exitosamente!"
  exit 0
else
  echo "⚠️  Algunas instalaciones fallaron. Revisa los errores arriba."
  exit 1
fi

