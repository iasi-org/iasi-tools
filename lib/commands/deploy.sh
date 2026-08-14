#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_DIR="$(cd -- "$SCRIPT_DIR/../.." && pwd)"

source "$TOOLS_DIR/lib/core/messages.sh"

usage() {
  cat <<'EOF'
Usage: iasi-dev deploy [-f|--full] [-m|--message "message"] [repository...]

Commits regular repository changes and, when present, publish/ artifacts
separately, then pushes the resulting commits. With --full, build and publish
are run successfully before the normal deploy flow starts.

Arguments:
  repository   Optional repository or workspace directory; current directory
               by default

Options:
  -f, --full   Run build and publish before committing and pushing
  -m, --message MESSAGE
               Base commit message; "deploy" by default
  -v           Show detailed information, including success messages
  -h, --help   Show this help
EOF
}

full=0
commit_message="deploy"
target_arguments=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    -f|--full)
      full=1
      shift
      ;;
    -m|--message)
      if [ "$#" -lt 2 ] || [ -z "$2" ]; then
        error "La opción $1 requiere un mensaje."
        exit 2
      fi
      commit_message="$2"
      shift 2
      ;;
    -v)
      IASI_VERBOSITY=2
      shift
      ;;
    --message=*)
      commit_message="${1#*=}"
      if [ -z "$commit_message" ]; then
        error "La opción --message requiere un mensaje."
        exit 2
      fi
      shift
      ;;
    -*)
      error "Opción desconocida: $1"
      usage >&2
      exit 2
      ;;
    *)
      target_arguments+=("$1")
      shift
      ;;
  esac
done

if [ "${#target_arguments[@]}" -gt 1 ]; then
  for selected_target in "${target_arguments[@]}"; do
    deploy_options=(-m "$commit_message")
    [ "$full" -eq 1 ] && deploy_options=(-f "${deploy_options[@]}")
    "$0" "${deploy_options[@]}" "$selected_target"
  done
  exit 0
fi

target_argument="${target_arguments[0]:-}"
target="${target_argument:-$PWD}"

if [ ! -d "$target" ]; then
  error "No existe el directorio: $target"
  exit 2
fi

TARGET_DIR="$(cd -- "$target" && pwd)"

if [ -n "$target_argument" ]; then
  info "Desplegando $(basename -- "$TARGET_DIR")."
else
  info "Desplegando todos los repositorios."
fi

if [ "$full" -eq 1 ]; then
  "$TOOLS_DIR/lib/commands/build.sh" "$TARGET_DIR"
  "$TOOLS_DIR/lib/commands/publish.sh" "$TARGET_DIR"
fi

repositories=()

if repository_root="$(git -C "$TARGET_DIR" rev-parse --show-toplevel 2>/dev/null)"; then
  repositories+=("$repository_root")
else
  for candidate in "$TARGET_DIR"/*; do
    [ -d "$candidate/.git" ] || continue
    repositories+=("$candidate")
  done
fi

if [ "${#repositories[@]}" -eq 0 ]; then
  error "No se encontraron repositorios Git en $TARGET_DIR."
  exit 1
fi

if target_repository="$(git -C "$TARGET_DIR" rev-parse --show-toplevel 2>/dev/null)"; then
  LOG_DIR="$(dirname -- "$target_repository")/logs"
else
  LOG_DIR="$TARGET_DIR/logs"
fi
LOG_FILE="$LOG_DIR/iasi-deploy-$(date +%Y%m%d%H%M%S).log"
mkdir -p -- "$LOG_DIR"

{
  printf "IASI deploy started at %s\n" "$(date --iso-8601=seconds)"
  printf "Directory: %s\n" "$TARGET_DIR"
  printf "Full: %s\n" "$full"
  printf "Message: %s\n\n" "$commit_message"
} > "$LOG_FILE"

regular_commits=0
publish_commits=0

for repository in "${repositories[@]}"; do
  name="$(basename -- "$repository")"
  printf "[%s]\n" "$name" >> "$LOG_FILE"

  # Partition any previously staged publish changes before staging regular work.
  git -C "$repository" reset --quiet -- publish >> "$LOG_FILE" 2>&1 || true

  if ! git -C "$repository" add -A -- . ':(exclude)publish' >> "$LOG_FILE" 2>&1; then
    error "No se pudieron preparar los cambios normales de $name."
    warning "Consulta el log: $LOG_FILE"
    exit 1
  fi

  if git -C "$repository" diff --cached --quiet >> "$LOG_FILE" 2>&1; then
    detail "$name no tiene cambios normales."
  else
    if ! git -C "$repository" commit -m "$commit_message" >> "$LOG_FILE" 2>&1; then
      error "No se pudo crear el commit de $name."
      warning "Consulta el log: $LOG_FILE"
      exit 1
    fi
    regular_commits=$((regular_commits + 1))
  fi

  if [ -d "$repository/publish" ] ||
     [ -n "$(git -C "$repository" ls-files -- publish)" ]; then
    if ! git -C "$repository" add -A -- publish >> "$LOG_FILE" 2>&1; then
      error "No se pudieron preparar los artefactos publish/ de $name."
      warning "Consulta el log: $LOG_FILE"
      exit 1
    fi

    if git -C "$repository" diff --cached --quiet >> "$LOG_FILE" 2>&1; then
      detail "$name no tiene cambios en publish/."
    else
      if ! git -C "$repository" commit -m "$commit_message publish" >> "$LOG_FILE" 2>&1; then
        error "No se pudo crear el commit publish de $name."
        warning "Consulta el log: $LOG_FILE"
        exit 1
      fi
      publish_commits=$((publish_commits + 1))
    fi
  else
    detail "$name no tiene carpeta publish/."
  fi

  if ! git -C "$repository" push >> "$LOG_FILE" 2>&1; then
    error "No se pudieron subir los commits de $name."
    warning "Consulta el log: $LOG_FILE"
    exit 1
  fi

  printf "\n" >> "$LOG_FILE"
  success_detail "$name desplegado."
done

success "$regular_commits commit(s) normales y $publish_commits commit(s) publish creados."
