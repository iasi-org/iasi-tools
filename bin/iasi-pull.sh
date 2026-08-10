#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
WORKSPACE_DIR="$(cd -- "$TOOLS_DIR/.." && pwd)"

source "$TOOLS_DIR/lib/messages.sh"
source "$TOOLS_DIR/lib/arguments.sh"
source "$TOOLS_DIR/lib/repositories.sh"

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Lists the repositories in $IASI_ORG that would be updated with git pull.
This version does not modify anything.

Options:
  -h, --help   Show this help
  -v           Minimal information (default)
  -V           Detailed information
  -s           Silent mode
EOF
}

if ! iasi_parse_arguments "$@"; then
  error "Opción no válida: $IASI_ARGUMENT_ERROR"
  usage >&2
  exit 2
fi

if [ "$IASI_HELP" -eq 1 ]; then
  usage
  exit 0
fi

command -v git >/dev/null 2>&1 || {
  error "Git no está instalado o no está disponible en PATH."
  exit 1
}

command -v gh >/dev/null 2>&1 || {
  error "GitHub CLI no está instalado o no está disponible en PATH."
  exit 1
}

gh auth status >/dev/null 2>&1 || {
  error "GitHub CLI no está autenticado. Ejecuta: gh auth login"
  exit 1
}

if ! repositories="$(iasi_repositories)"; then
  error "No se pudo obtener la lista de repositorios de $IASI_ORG."
  exit 1
fi

while IFS='|' read -r name url; do
  [ -n "$name" ] || continue

  target="$WORKSPACE_DIR/$name"

  if [ -d "$target/.git" ]; then
    info "Actualizaría $name."
    detail "$target"
  elif [ -e "$target" ]; then
    warning "$name no se actualizaría: el destino existe pero no es un repositorio Git."
    detail "$target"
  else
    warning "$name no se actualizaría: no está clonado."
    detail "$url"
  fi
done <<< "$repositories"
