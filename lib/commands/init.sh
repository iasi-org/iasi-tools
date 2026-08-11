#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_DIR="$(cd -- "$SCRIPT_DIR/../.." && pwd)"

source "$TOOLS_DIR/lib/core/messages.sh"
source "$TOOLS_DIR/lib/core/arguments.sh"

usage() {
  cat <<EOF
Usage: iasi init [options] [workspace]

Runs all IASI initialization steps in order.

Steps:
  1. Recreate the repositories
  2. Install iasi.quarto
  3. Configure iasi-lua in every Quarto project
  4. Start the Docker containers

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
  "$TOOLS_DIR/lib/commands/clone.sh"
  "$TOOLS_DIR/lib/install/quarto.sh"
  "$TOOLS_DIR/lib/install/lua.sh"
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

docker_step="$TOOLS_DIR/lib/commands/docker.sh"

if IASI_VERBOSITY="$IASI_VERBOSITY" "$docker_step" start; then
  :
else
  step_status=$?
  error "La inicialización se ha detenido en $(basename "$docker_step")."
  exit "$step_status"
fi

success "Inicialización completada correctamente."
