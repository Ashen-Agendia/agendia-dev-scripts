#!/bin/bash

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

