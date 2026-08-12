#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_DIR="$(cd -- "$SCRIPT_DIR/../.." && pwd)"

source "$TOOLS_DIR/lib/core/messages.sh"

usage() {
  cat <<'EOF'
Usage: iasi sync file [file...]

Propagates files from iasi-common to every existing copy in the IASI
workspace. Files are matched by name. iasi-common and Git metadata are
excluded from the search, and missing copies are not created.

Options:
  -h, --help   Show this help
EOF
}

if [ "$#" -eq 0 ]; then
  error "Debes indicar al menos un archivo."
  usage >&2
  exit 2
fi

if [ "$#" -eq 1 ] && { [ "$1" = "-h" ] || [ "$1" = "--help" ]; }; then
  usage
  exit 0
fi

for argument in "$@"; do
  if [[ "$argument" == -* ]]; then
    error "Opción no válida: $argument"
    usage >&2
    exit 2
  fi
done

WORKSPACE_DIR="$(cd -- "$TOOLS_DIR/.." && pwd)"
COMMON_DIR="${IASI_COMMON_DIR:-$WORKSPACE_DIR/iasi-common}"

if [ ! -d "$COMMON_DIR" ]; then
  error "No se encontró iasi-common: $COMMON_DIR"
  exit 1
fi

synced=0

for argument in "$@"; do
  filename="$(basename -- "$argument")"
  source_file=""

  while IFS= read -r -d '' candidate; do
    source_file="$candidate"
    break
  done < <(find "$COMMON_DIR" -type f -name "$filename" -print0)

  if [ -z "$source_file" ]; then
    error "No se encontró $filename en iasi-common."
    exit 1
  fi

  found=0

  while IFS= read -r -d '' target; do
    if ! cp -- "$source_file" "$target"; then
      error "No se pudo actualizar: $target"
      exit 1
    fi

    success_detail "$target"
    found=$((found + 1))
    synced=$((synced + 1))
  done < <(
    find "$WORKSPACE_DIR" \
      -path "$COMMON_DIR" -prune -o \
      -path '*/.git' -prune -o \
      -type f -name "$filename" -print0
  )

  if [ "$found" -eq 0 ]; then
    warning "No existen copias de $filename fuera de iasi-common."
  else
    info "$filename: $found copia(s) actualizada(s)."
  fi
done

success "$synced copia(s) sincronizada(s) desde iasi-common."
