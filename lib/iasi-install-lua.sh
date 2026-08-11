#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"

source "$TOOLS_DIR/lib/messages.sh"
source "$TOOLS_DIR/lib/arguments.sh"

usage() {
  cat <<EOF
Usage: $(basename "$0") [options] [workspace]

Adds iasi-lua to every Quarto project under the workspace.

Options:
  -h, --help   Show this help
  -v           Detailed information
  -s           Silent mode
EOF
}

workspace_argument=""
options=()

for argument in "$@"; do
  case "$argument" in
    -y|--yes)
      ;;
    -*)
      options+=("$argument")
      ;;
    *)
      if [ -n "$workspace_argument" ]; then
        error "Solo se puede indicar un directorio de trabajo."
        exit 2
      fi
      workspace_argument="$argument"
      ;;
  esac
done

if ! iasi_parse_arguments "${options[@]}"; then
  error "Opción no válida: $IASI_ARGUMENT_ERROR"
  usage >&2
  exit 2
fi

if [ "$IASI_HELP" -eq 1 ]; then
  usage
  exit 0
fi

if [ -z "$workspace_argument" ]; then
  workspace_argument="$PWD"
fi

if [ ! -d "$workspace_argument" ]; then
  error "No existe el directorio de trabajo: $workspace_argument"
  exit 1
fi

export IASI_ROOT="$(cd -- "$workspace_argument" && pwd)"
LUA_DIR="$IASI_ROOT/iasi-lua"
LOG_DIR="$IASI_ROOT/logs"
LOG_FILE="$LOG_DIR/$(basename "$0" .sh)-$(date +%Y%m%d%H%M%S).log"

if [ ! -d "$LUA_DIR" ]; then
  error "No se encontró el repositorio: $LUA_DIR"
  exit 1
fi

if ! mkdir -p -- "$LOG_DIR"; then
  error "No se pudo crear el directorio de logs: $LOG_DIR"
  exit 1
fi

{
  printf "IASI init step 3 started at %s\n" "$(date --iso-8601=seconds)"
  printf "Workspace: %s\n\n" "$IASI_ROOT"
} > "$LOG_FILE"

quarto_projects=()

mapfile -d '' -t quarto_projects < <(
  find "$IASI_ROOT" \
    -type d -name 'tests' -prune -o \
    -type f -name '_quarto.yml' -print0 \
    2>> "$LOG_FILE"
)

if [ "${#quarto_projects[@]}" -gt 0 ]; then
  info "Configurando proyectos Quarto"
fi

for quarto_config in "${quarto_projects[@]}"; do
  quarto_directory="$(dirname -- "$quarto_config")"
  detail "$quarto_directory"
  printf "Quarto directory: %s\n" "$quarto_directory" >> "$LOG_FILE"

  if ! (
    cd -- "$quarto_directory"
    quarto add "$IASI_ROOT/iasi-lua" --no-prompt
  ) >> "$LOG_FILE" 2>&1; then
    error "No se pudo configurar el proyecto Quarto: $quarto_directory"
    detail "Consulta el log: $LOG_FILE"
    exit 1
  fi

  success_detail "Proyecto Quarto configurado: $quarto_directory"
done

detail "Log: $LOG_FILE"
