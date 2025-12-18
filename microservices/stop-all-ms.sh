#!/bin/bash

echo "🛑 Deteniendo todos los microservicios..."

echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_ROOT="$(dirname "$SCRIPT_DIR")"
PIDS_FILE="$SCRIPTS_ROOT/.ms-pids"

STOPPED=0
NOT_FOUND=0

if [ ! -f "$PIDS_FILE" ]; then
  echo "⚠️  No se encontró archivo de PIDs (.ms-pids)"
  echo "   No hay microservicios registrados por start-all-ms.sh para detener."
  exit 0
fi

echo "📋 Leyendo PIDs desde $PIDS_FILE..."
echo ""

while IFS=':' read -r PID DIR; do
  if [ -z "$PID" ] || [ -z "$DIR" ]; then
    continue
  fi

  if kill -0 "$PID" 2>/dev/null; then
    echo "   🛑 Deteniendo $DIR (PID: $PID)..."
    kill "$PID" 2>/dev/null
    if [ $? -eq 0 ]; then
      echo "      ✅ $DIR detenido"
      ((STOPPED++))
    else
      echo "      ❌ Error deteniendo $DIR"
    fi
  else
    echo "   ⚠️  $DIR (PID: $PID) ya no está corriendo"
    ((NOT_FOUND++))
  fi

done < "$PIDS_FILE"

rm "$PIDS_FILE"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Resumen:"
echo "   🛑 Detenidos: $STOPPED"
if [ $NOT_FOUND -gt 0 ]; then
  echo "   ⚠️  No encontrados: $NOT_FOUND"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $STOPPED -gt 0 ]; then
  echo "✅ Todos los microservicios han sido detenidos (según .ms-pids)"
else
  echo "ℹ️  No se encontraron procesos para detener"
fi
