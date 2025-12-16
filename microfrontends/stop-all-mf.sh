#!/bin/bash

echo "🛑 Deteniendo todos los microfrontends..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_ROOT="$(dirname "$SCRIPT_DIR")"
PIDS_FILE="$SCRIPTS_ROOT/.mf-pids"
STOPPED=0
NOT_FOUND=0

if [ ! -f "$PIDS_FILE" ]; then
  echo "⚠️  No se encontró archivo de PIDs (.mf-pids)"
  echo "   Intentando detener procesos de Vite/Node manualmente..."
  
  # Intentar detener procesos de Vite en los puertos comunes
  PORTS=(3000 3001 3002 3003 3004 3005 3006 3007 3008 3009 3010)
  
  for port in "${PORTS[@]}"; do
    PID=$(lsof -ti:$port 2>/dev/null || fuser $port/tcp 2>/dev/null | awk '{print $1}')
    if [ ! -z "$PID" ]; then
      echo "   Deteniendo proceso en puerto $port (PID: $PID)..."
      kill $PID 2>/dev/null && ((STOPPED++)) || echo "   ⚠️  No se pudo detener proceso en puerto $port"
    fi
  done
  
  if [ $STOPPED -eq 0 ]; then
    echo "   ℹ️  No se encontraron procesos corriendo en los puertos comunes"
  fi
else
  echo "📋 Leyendo PIDs desde $PIDS_FILE..."
  
  while IFS=':' read -r PID DIR; do
    if [ -z "$PID" ] || [ -z "$DIR" ]; then
      continue
    fi
    
    if kill -0 $PID 2>/dev/null; then
      echo "   🛑 Deteniendo $DIR (PID: $PID)..."
      kill $PID 2>/dev/null
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
  
  # Limpiar archivo de PIDs
  rm "$PIDS_FILE"
fi

# Intentar detener cualquier proceso de Node/Vite restante relacionado con MFs
echo ""
echo "🔍 Buscando procesos restantes de Node/Vite..."

# En Linux/Mac
if command -v pkill >/dev/null 2>&1; then
  PIDS=$(pgrep -f "vite.*--port" 2>/dev/null || pgrep -f "npm.*dev" 2>/dev/null)
  if [ ! -z "$PIDS" ]; then
    echo "   Encontrados procesos adicionales, deteniendo..."
    pkill -f "vite.*--port" 2>/dev/null
    pkill -f "npm.*dev" 2>/dev/null
    ((STOPPED++))
  fi
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Resumen:"
echo "   🛑 Detenidos: $STOPPED"
if [ $NOT_FOUND -gt 0 ]; then
  echo "   ⚠️  No encontrados: $NOT_FOUND"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $STOPPED -gt 0 ]; then
  echo "✅ Todos los microfrontends han sido detenidos"
else
  echo "ℹ️  No se encontraron procesos para detener"
fi

