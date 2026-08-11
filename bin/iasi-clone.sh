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

Lists the repositories that would be cloned from $IASI_ORG.
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

if ! repositories="$(iasi_repositories)"; then
  error "No se pudo obtener la lista de repositorios de $IASI_ORG."
  exit 1
fi

while IFS='|' read -r name url default_branch; do
  [ -n "$name" ] || continue

  target="$WORKSPACE_DIR/$name"

  if [ -d "$target/.git" ]; then
    success "$name ya existe."
    detail "$target"
  elif [ -e "$target" ]; then
    warning "$name no se clonaría: el destino ya existe."
    detail "$target"
  else
    info "Clonaría $name."
    detail "$url"
    detail "$target"
  fi
done <<< "$repositories"
