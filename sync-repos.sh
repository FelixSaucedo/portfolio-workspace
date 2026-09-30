#!/usr/bin/env bash
set -e

MSG="${1:-chore: sync repository updates}"
ROOT_DIR="$(pwd)"

sync_repo() {
  local dir="$1"
  local name="$2"
  echo "----------------------------------------"
  echo "==> Verificando [$name]..."
  if [ -d "$dir/.git" ]; then
    cd "$dir"
    if [ -n "$(git status --porcelain)" ]; then
      echo "    Subiendo cambios en $name..."
      git add -A
      git commit -m "$MSG"
      git push origin HEAD
    else
      echo "    Sin cambios pendientes."
    fi
    cd "$ROOT_DIR"
  else
    echo "    Aviso: No es un repositorio Git válido."
  fi
}

sync_repo "$ROOT_DIR" "portfolio-workspace"
sync_repo "$ROOT_DIR/felixsaucedo-api" "felixsaucedo-api"
sync_repo "$ROOT_DIR/felixsaucedo-ui" "felixsaucedo-ui"

echo "----------------------------------------"
echo "=== Todos los repositorios sincronizados exitosamente ==="
