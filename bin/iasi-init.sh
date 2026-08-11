#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"

source "$TOOLS_DIR/lib/messages.sh"
source "$TOOLS_DIR/lib/arguments.sh"
source "$TOOLS_DIR/lib/repositories.sh"

usage() {
  cat <<EOF
Usage: $(basename "$0") [options] [workspace]

Recreates from scratch all repositories from $IASI_ORG.
Existing repository destinations are removed before cloning.
Command output is written to logs/iasi-init-YYYYMMDDhhmmss.log in the workspace.

If workspace is omitted, the current directory is used.

Options:
  -h, --help   Show this help
  -v           Detailed information
  -s           Silent mode
  -y, --yes    Do not ask for confirmation
EOF
}

workspace_argument=""
options=()
assume_yes=0

for argument in "$@"; do
  case "$argument" in
    -y|--yes)
      assume_yes=1
      ;;
    -*)
      options+=("$argument")
      ;;
    *)
      if [ -n "$workspace_argument" ]; then
        error "Solo se puede indicar un directorio de trabajo."
        usage >&2
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

if [ "$assume_yes" -eq 0 ]; then
  if ! confirm "Los repositorios existentes en $workspace_argument se eliminarán y se clonarán de nuevo."; then
    info "Operación cancelada."
    exit 0
  fi
fi

if [ ! -d "$workspace_argument" ]; then
  if ! mkdir -p -- "$workspace_argument"; then
    error "No se pudo crear el directorio de trabajo: $workspace_argument"
    exit 1
  fi

  info "Directorio de trabajo creado: $workspace_argument"
fi

WORKSPACE_DIR="$(cd -- "$workspace_argument" && pwd)"
LOG_DIR="$WORKSPACE_DIR/logs"
SCRIPT_NAME="$(basename "$0" .sh)"
LOG_FILE="$LOG_DIR/$SCRIPT_NAME-$(date +%Y%m%d%H%M%S).log"

if ! mkdir -p -- "$LOG_DIR"; then
  error "No se pudo crear el directorio de logs: $LOG_DIR"
  exit 1
fi

cd -- "$WORKSPACE_DIR"

{
  printf "IASI init started at %s\n" "$(date --iso-8601=seconds)"
  printf "Organization: %s\n" "$IASI_ORG"
  printf "Workspace: %s\n\n" "$WORKSPACE_DIR"
} > "$LOG_FILE"

if ! repositories="$(iasi_repositories 2>> "$LOG_FILE")"; then
  error "No se pudo obtener la lista de repositorios de $IASI_ORG."
  detail "Consulta el log: $LOG_FILE"
  exit 1
fi

while IFS='|' read -r name url default_branch; do
  [ -n "$name" ] || continue

  if [[ ! "$name" =~ ^[a-zA-Z0-9._-]+$ ]] || [ "$name" = "." ] || [ "$name" = ".." ]; then
    error "Nombre de repositorio no válido: $name"
    detail "Consulta el log: $LOG_FILE"
    exit 1
  fi

  target="$WORKSPACE_DIR/$name"

  if [ -e "$target" ] || [ -L "$target" ]; then
    info "Eliminando $name."
    detail "$target"

    if ! rm -rf -- "$target" >> "$LOG_FILE" 2>&1; then
      error "No se pudo eliminar $name."
      detail "Consulta el log: $LOG_FILE"
      exit 1
    fi
  fi

  info "Clonando $name."
  detail "$url"
  detail "$target"

  if ! git clone "$url" "$target" >> "$LOG_FILE" 2>&1; then
    error "No se pudo clonar $name."
    detail "Consulta el log: $LOG_FILE"
    exit 1
  fi

  success_detail "$name clonado."
done <<< "$repositories"

success "Repositorios recreados correctamente."
detail "Log: $LOG_FILE"
