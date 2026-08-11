#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_DIR="$(cd -- "$SCRIPT_DIR/../.." && pwd)"

source "$TOOLS_DIR/lib/core/messages.sh"

usage() {
  cat <<'EOF'
Usage: iasi commit "message" [repository]

Stages all changes, creates a commit, and pushes it to the configured remote.
Without a repository, all Git repositories directly below the current directory
are processed. With a repository directory, only that repository is processed.

Arguments:
  message      Required commit message
  repository   Optional repository directory or path

Options:
  -h, --help   Show this help
EOF
}

if [ "$#" -eq 1 ] && { [ "$1" = "-h" ] || [ "$1" = "--help" ]; }; then
  usage
  exit 0
fi

if [ "$#" -lt 1 ]; then
  error "El mensaje del commit es obligatorio."
  usage >&2
  exit 2
fi

if [ "$#" -gt 2 ]; then
  error "Solo se puede indicar un mensaje y un directorio de repositorio."
  usage >&2
  exit 2
fi

commit_message="$1"
repository_argument="${2:-}"

if [ -z "$commit_message" ]; then
  error "El mensaje del commit no puede estar vacío."
  exit 2
fi

repositories=()

if [ -n "$repository_argument" ]; then
  if [ ! -d "$repository_argument" ]; then
    error "No existe el directorio de repositorio: $repository_argument"
    exit 2
  fi

  repository_path="$(cd -- "$repository_argument" && pwd)"

  if [ ! -d "$repository_path/.git" ]; then
    error "El directorio no es un repositorio Git: $repository_argument"
    exit 2
  fi

  repositories+=("$repository_path")
else
  workspace_dir="$PWD"

  for candidate in "$workspace_dir"/*; do
    [ -d "$candidate/.git" ] || continue
    repositories+=("$candidate")
  done

  if [ "${#repositories[@]}" -eq 0 ]; then
    error "No se encontraron repositorios Git en $workspace_dir."
    exit 1
  fi
fi

committed=0
unchanged=0

for repository in "${repositories[@]}"; do
  name="$(basename -- "$repository")"
  info "Procesando $name."

  if ! git -C "$repository" add -A .; then
    error "No se pudieron preparar los cambios de $name."
    exit 1
  fi

  if git -C "$repository" diff --cached --quiet; then
    detail "$name no tiene cambios; se omite."
    unchanged=$((unchanged + 1))
    continue
  fi

  if ! git -C "$repository" commit -m "$commit_message"; then
    error "No se pudo crear el commit de $name."
    exit 1
  fi

  if ! git -C "$repository" push; then
    error "No se pudo publicar el commit de $name."
    exit 1
  fi

  success_detail "$name publicado."
  committed=$((committed + 1))
done

success "$committed repositorio(s) confirmado(s) y publicado(s); $unchanged sin cambios."
