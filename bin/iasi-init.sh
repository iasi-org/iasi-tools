#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"

source "$TOOLS_DIR/lib/messages.sh"
source "$TOOLS_DIR/lib/arguments.sh"

usage() {
  cat <<EOF
Usage: $(basename "$0") [options] [workspace]

Runs all IASI initialization steps in order.

Steps:
  1. Recreate the repositories
  2. Install iasi.quarto
  3. Configure iasi-lua in every Quarto project

Options:
  -h, --help   Show this help
  -v           Detailed information
  -s           Silent mode
  -y, --yes    Do not ask for confirmation
EOF
}

options=()

for argument in "$@"; do
  case "$argument" in
    -h|--help)
      usage
      exit 0
      ;;
    -y|--yes)
      ;;
    -*)
      options+=("$argument")
      ;;
  esac
done

if ! iasi_parse_arguments "${options[@]}"; then
  error "Opción no válida: $IASI_ARGUMENT_ERROR"
  usage >&2
  exit 2
fi

steps=(
  "$TOOLS_DIR/bin/iasi-clone.sh"
  "$TOOLS_DIR/lib/iasi-install-iasi-quarto.sh"
  "$TOOLS_DIR/lib/iasi-install-lua.sh"
)

for step in "${steps[@]}"; do
  if "$step" "$@"; then
    continue
  else
    step_status=$?
    error "La inicialización se ha detenido en $(basename "$step")."
    exit "$step_status"
  fi
done

success "Inicialización completada correctamente."
