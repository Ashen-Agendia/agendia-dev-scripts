#!/bin/bash

echo "Actualizando todos los repositorios..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_ROOT="$(dirname "$SCRIPT_DIR")"
ROOT_DIR="$(dirname "$SCRIPTS_ROOT")"

echo "📁 Buscando repositorios en: $ROOT_DIR"
echo ""

cd "$ROOT_DIR" || exit 1

for dir in */; do
    if [ -d "$dir/.git" ]; then
        echo "Actualizando $dir..."
        cd "$dir"
        git pull
        cd "$ROOT_DIR" || continue
    fi
done

echo "¡Listo! Todos los repositorios han sido actualizados."

