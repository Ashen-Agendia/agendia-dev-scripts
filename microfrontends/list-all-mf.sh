#!/bin/bash

echo "📋 Listando microfrontends corriendo..."
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_ROOT="$(dirname "$SCRIPT_DIR")"
PIDS_FILE="$SCRIPTS_ROOT/.mf-pids"

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

RUNNING=0
STOPPED=0
NOT_STARTED=0

declare -A runningMfs

if [ -f "$PIDS_FILE" ]; then
  echo "📂 Leyendo PIDs desde archivo..."
  echo ""
  
  while IFS=':' read -r pid dirName; do
    if [ -z "$pid" ] || [ -z "$dirName" ]; then
      continue
    fi
    
    if kill -0 "$pid" 2>/dev/null; then
      port=""
      if command -v lsof >/dev/null 2>&1; then
        port=$(lsof -Pan -p "$pid" -iTCP 2>/dev/null | grep LISTEN | head -1 | awk '{print $9}' | cut -d: -f2)
      elif command -v netstat >/dev/null 2>&1; then
        port=$(netstat -tuln 2>/dev/null | grep "$pid" | head -1 | awk '{print $4}' | cut -d: -f2)
      fi
      
      portInfo=""
      if [ -n "$port" ] && [ "$port" != "" ]; then
        portInfo=" (Puerto: $port)"
      fi
      
      echo "   ✅ $dirName - PID: $pid$portInfo"
      runningMfs["$dirName"]=1
      ((RUNNING++))
    else
      echo "   ⚠️  $dirName - PID: $pid (proceso detenido)"
      ((STOPPED++))
    fi
  done < "$PIDS_FILE"
else
  echo "⚠️  No se encontró archivo de PIDs (.mf-pids)"
  echo "   Buscando procesos de Node/Vite manualmente..."
  echo ""
  
  nodeProcesses=$(ps aux | grep -E "node.*vite|node.*npm.*dev|npm.*run.*dev" | grep -v grep)
  
  if [ -n "$nodeProcesses" ]; then
    echo "$nodeProcesses" | while read -r line; do
      pid=$(echo "$line" | awk '{print $2}')
      port=""
      if command -v lsof >/dev/null 2>&1; then
        port=$(lsof -Pan -p "$pid" -iTCP 2>/dev/null | grep LISTEN | head -1 | awk '{print $9}' | cut -d: -f2)
      elif command -v netstat >/dev/null 2>&1; then
        port=$(netstat -tuln 2>/dev/null | grep "$pid" | head -1 | awk '{print $4}' | cut -d: -f2)
      fi
      
      portInfo=""
      if [ -n "$port" ] && [ "$port" != "" ]; then
        portInfo=" (Puerto: $port)"
      fi
      
      echo "   ✅ Proceso Node - PID: $pid$portInfo"
    done
    RUNNING=$(echo "$nodeProcesses" | wc -l | tr -d ' ')
  else
    echo "   ℹ️  No se encontraron procesos de Node/Vite corriendo"
  fi
fi

echo ""

for dirName in "${MF_DIRS[@]}"; do
  if [ -z "${runningMfs[$dirName]}" ]; then
    ((NOT_STARTED++))
  fi
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Resumen:"
echo "   ✅ Corriendo: $RUNNING"
if [ $STOPPED -gt 0 ]; then
  echo "   ⚠️  Detenidos: $STOPPED"
fi
echo "   ⏭️  No iniciados: $NOT_STARTED"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $RUNNING -eq 0 ]; then
  echo ""
  echo "ℹ️  No hay microfrontends corriendo actualmente"
  echo "   Para iniciarlos: ./start-all-mf.sh"
fi

