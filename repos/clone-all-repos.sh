#!/bin/bash

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

echo "¡Listo! Todos los repositorios han sido clonados."

