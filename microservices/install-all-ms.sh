#!/bin/bash

echo "📦 Instalando dependencias de todos los microservicios..."
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_ROOT="$(dirname "$SCRIPT_DIR")"
ROOT_DIR="$(dirname "$SCRIPTS_ROOT")"

MS_DIRS=(
  "agendia-template-ms"
  "agendia-ms-agenda"
  "agendia-ms-clients"
  "agendia-ms-notifications"
  "agendia-ms-organization"
  "agendia-ms-platform"
  "agendia-ms-sales"
)

INSTALLED=0
SKIPPED=0
FAILED=0

for dirName in "${MS_DIRS[@]}"; do
  dirPath="$ROOT_DIR/$dirName"
  buildFile="$dirPath/build.sbt"

  if [ -d "$dirPath" ] && [ -f "$buildFile" ]; then
    echo ""
    echo "📦 Ejecutando 'sbt compile' en $dirName..."
    cd "$dirPath" || continue

    if sbt compile; then
      echo "✅ $dirName compilado / dependencias descargadas correctamente"
      ((INSTALLED++))
    else
      echo "❌ Error ejecutando 'sbt compile' en $dirName"
      ((FAILED++))
    fi

    cd "$ROOT_DIR" || continue
  else
    echo "⏭️  Saltando $dirName (no existe o no tiene build.sbt)"
    ((SKIPPED++))
  fi

done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Resumen:"
echo "   ✅ Procesados (compile OK): $INSTALLED"
echo "   ⏭️  Saltados: $SKIPPED"
echo "   ❌ Fallidos: $FAILED"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $FAILED -eq 0 ]; then
  echo "🎉 ¡Instalación/compilación completada sin errores!"
  exit 0
else
  echo "⚠️  Algunas compilaciones fallaron. Revisa la salida anterior."
  exit 1
fi
