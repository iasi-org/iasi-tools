#!/usr/bin/env bash

set -euo pipefail

ORG="iasi-org"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
WORKSPACE_DIR="$(cd -- "$TOOLS_DIR/.." && pwd)"

source "$TOOLS_DIR/lib/messages.sh"
source "$TOOLS_DIR/lib/arguments.sh"

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Lists the actions required to prepare the repositories of $ORG.
This version does not clone or modify anything.

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

info "Consultando repositorios de $ORG..."

if ! repositories="$(
  gh repo list "$ORG" \
    --limit 100 \
    --no-archived \
    --json name,sshUrl \
    --jq '.[] | "\(.name)|\(.sshUrl)"'
)"; then
  error "No se pudo obtener la lista de repositorios de $ORG."
  exit 1
fi

if [ -z "$repositories" ]; then
  warning "No se encontraron repositorios."
  exit 0
fi

info "Acciones previstas:"

while IFS='|' read -r name url; do
  target="$WORKSPACE_DIR/$name"

  if [ -d "$target/.git" ]; then
    success "$name ya existe."
    detail "  $target"
  elif [ -e "$target" ]; then
    warning "$name no se clonaría: el destino ya existe y no es un repositorio Git."
    detail "  $target"
  else
    info "Clonaría $name."
    detail "  $url"
    detail "  -> $target"
  fi
done <<< "$repositories"

info "Modo simulación: no se ha modificado nada."
