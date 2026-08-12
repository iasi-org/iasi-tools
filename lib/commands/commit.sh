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
  workspace_dir="$(dirname -- "$repository_path")"
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

log_dir="$workspace_dir/logs"
log_file="$log_dir/iasi-commit-$(date +%Y%m%d%H%M%S).log"

if ! mkdir -p -- "$log_dir"; then
  error "No se pudo crear el directorio de logs: $log_dir"
  exit 1
fi

{
  printf "IASI commit started at %s\n" "$(date --iso-8601=seconds)"
  printf "Workspace: %s\n" "$workspace_dir"
  printf "Repository: %s\n" "${repository_argument:-all}"
  printf "Message: %s\n\n" "$commit_message"
} > "$log_file"

committed=0
unchanged=0

for repository in "${repositories[@]}"; do
  name="$(basename -- "$repository")"
  info "Procesando $name."

  printf "[%s]\n" "$name" >> "$log_file"

  if ! git -C "$repository" add -A . >> "$log_file" 2>&1; then
    error "No se pudieron preparar los cambios de $name."
    detail "Consulta el log: $log_file"
    exit 1
  fi

  if git -C "$repository" diff --cached --quiet >> "$log_file" 2>&1; then
    detail "$name no tiene cambios; se comprueban commits pendientes."
    printf "No changes.\n\n" >> "$log_file"
    unchanged=$((unchanged + 1))
  else
    if ! git -C "$repository" commit -m "$commit_message" >> "$log_file" 2>&1; then
      error "No se pudo crear el commit de $name."
      detail "Consulta el log: $log_file"
      exit 1
    fi

    committed=$((committed + 1))
  fi

  if ! git -C "$repository" push >> "$log_file" 2>&1; then
    error "No se pudo publicar el commit de $name."
    detail "Consulta el log: $log_file"
    exit 1
  fi

  printf "\n" >> "$log_file"
  success_detail "$name publicado."
done

success "$committed repositorio(s) confirmado(s) y publicado(s); $unchanged sin cambios."
detail "Log: $log_file"
