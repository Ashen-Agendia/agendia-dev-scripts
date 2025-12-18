#!/bin/bash

echo "📋 Listando microservicios corriendo..."
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_ROOT="$(dirname "$SCRIPT_DIR")"
PIDS_FILE="$SCRIPTS_ROOT/.ms-pids"

MS_DIRS=(
  "agendia-template-ms"
  "agendia-ms-agenda"
  "agendia-ms-clients"
  "agendia-ms-notifications"
  "agendia-ms-organization"
  "agendia-ms-platform"
  "agendia-ms-sales"
)

RUNNING=0
STOPPED=0
NOT_STARTED=0

declare -A runningMs

if [ -f "$PIDS_FILE" ]; then
  echo "📂 Leyendo PIDs desde archivo..."
  echo ""

  while IFS=':' read -r PID DIR; do
    if [ -z "$PID" ] || [ -z "$DIR" ]; then
      continue
    fi

    if kill -0 "$PID" 2>/dev/null; then
      echo "   ✅ $DIR - PID: $PID"
      runningMs["$DIR"]=1
      ((RUNNING++))
    else
      echo "   ⚠️  $DIR - PID: $PID (proceso detenido)"
      ((STOPPED++))
    fi
  done < "$PIDS_FILE"
else
  echo "⚠️  No se encontró archivo de PIDs (.ms-pids)"
  echo "   Usa ./start-all-ms.sh para iniciar microservicios."
fi

echo ""

for DIR in "${MS_DIRS[@]}"; do
  if [ -z "${runningMs[$DIR]}" ]; then
    ((NOT_STARTED++))
  fi
Done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Resumen:"
echo "   ✅ Corriendo: $RUNNING"
if [ $STOPPED -gt 0 ]; then
  echo "   ⚠️  Detenidos: $STOPPED"
fi
echo "   ⏭️  No iniciados (según lista fija): $NOT_STARTED"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $RUNNING -eq 0 ]; then
  echo ""
  echo "ℹ️  No hay microservicios corriendo actualmente"
  echo "   Para iniciarlos: ./start-all-ms.sh"
fi
