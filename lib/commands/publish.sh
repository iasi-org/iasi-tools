#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_DIR="$(cd -- "$SCRIPT_DIR/../.." && pwd)"

source "$TOOLS_DIR/lib/core/messages.sh"

usage() {
  cat <<'EOF'
Usage: iasi publish "message" [directory]

Recursively finds directories containing _quarto.yml, then runs
iasi.quarto::build() and iasi.quarto::publish() in each one. If every project
succeeds, all affected repositories are committed and pushed with iasi commit.
Directories named tests are excluded from discovery.

Arguments:
  message     Required commit message
  directory   Directory to search; current directory by default

Options:
  -h, --help  Show this help
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
  error "Solo se puede indicar un mensaje y un directorio."
  usage >&2
  exit 2
fi

commit_message="$1"
search_argument="${2:-$PWD}"

if [ -z "$commit_message" ]; then
  error "El mensaje del commit no puede estar vacío."
  exit 2
fi

if [ ! -d "$search_argument" ]; then
  error "No existe el directorio: $search_argument"
  exit 2
fi

SEARCH_DIR="$(cd -- "$search_argument" && pwd)"
LOG_DIR="$SEARCH_DIR/logs"
LOG_FILE="$LOG_DIR/iasi-publish-$(date +%Y%m%d%H%M%S).log"

RSCRIPT_BIN="${IASI_RSCRIPT:-}"

if [ -z "$RSCRIPT_BIN" ] && command -v Rscript >/dev/null 2>&1; then
  RSCRIPT_BIN="$(command -v Rscript)"
fi

if [ -z "$RSCRIPT_BIN" ] && [ -n "${R_HOME:-}" ]; then
  for candidate in "$R_HOME/bin/Rscript" "$R_HOME/bin/Rscript.exe"; do
    if [ -x "$candidate" ]; then
      RSCRIPT_BIN="$candidate"
      break
    fi
  done
fi

if [ -z "$RSCRIPT_BIN" ] && [ -d /c/SDK/R ]; then
  while IFS= read -r candidate; do
    RSCRIPT_BIN="$candidate"
  done < <(find /c/SDK/R -maxdepth 3 -type f -iname 'Rscript.exe' | sort -V)
fi

if [ -z "$RSCRIPT_BIN" ] || [ ! -x "$RSCRIPT_BIN" ]; then
  error "No se encontró Rscript. Añádelo a PATH o define IASI_RSCRIPT."
  exit 1
fi

QUARTO_BIN="${IASI_QUARTO:-}"

if [ -z "$QUARTO_BIN" ] && command -v quarto >/dev/null 2>&1; then
  QUARTO_BIN="$(command -v quarto)"
fi

if [ -z "$QUARTO_BIN" ] && [ -d /c/SDK/RStudio ]; then
  while IFS= read -r candidate; do
    QUARTO_BIN="$candidate"
  done < <(find /c/SDK/RStudio -maxdepth 8 -type f -iname 'quarto.exe' | sort -V)
fi

if [ -z "$QUARTO_BIN" ] || [ ! -x "$QUARTO_BIN" ]; then
  error "No se encontró Quarto. Añádelo a PATH o define IASI_QUARTO."
  exit 1
fi

QUARTO_BIN_DIR="$(dirname -- "$QUARTO_BIN")"

if ! mkdir -p -- "$LOG_DIR"; then
  error "No se pudo crear el directorio de logs: $LOG_DIR"
  exit 1
fi

{
  printf "IASI publish started at %s\n" "$(date --iso-8601=seconds)"
  printf "Directory: %s\n" "$SEARCH_DIR"
  printf "Message: %s\n\n" "$commit_message"
} > "$LOG_FILE"

projects=()

while IFS= read -r -d '' quarto_file; do
  projects+=("$(dirname -- "$quarto_file")")
done < <(
  find "$SEARCH_DIR" \
    -path '*/.git' -prune -o \
    -path '*/.quarto' -prune -o \
    -path '*/tests' -prune -o \
    -path '*/node_modules' -prune -o \
    -path '*/renv' -prune -o \
    -type f -name '_quarto.yml' -print0
)

if [ "${#projects[@]}" -eq 0 ]; then
  error "No se encontraron proyectos con _quarto.yml en $SEARCH_DIR."
  exit 1
fi

for project in "${projects[@]}"; do
  info "Construyendo y publicando $project."
  printf "[%s]\n" "$project" >> "$LOG_FILE"

  if ! (
    cd -- "$project"
    PATH="$QUARTO_BIN_DIR:$PATH" \
      "$RSCRIPT_BIN" -e 'iasi.quarto::build(); iasi.quarto::publish()'
  ) >> "$LOG_FILE" 2>&1; then
    error "No se pudo construir o publicar: $project"
    detail "Consulta el log: $LOG_FILE"
    exit 1
  fi

  printf "\n" >> "$LOG_FILE"
  success_detail "$project publicado."
done

repository=""
if repository_candidate="$(git -C "$SEARCH_DIR" rev-parse --show-toplevel 2>/dev/null)"; then
  repository="$repository_candidate"
fi

info "Confirmando y publicando los cambios en Git."

if [ -n "$repository" ]; then
  "$TOOLS_DIR/lib/commands/commit.sh" "$commit_message" "$repository"
else
  (
    cd -- "$SEARCH_DIR"
    "$TOOLS_DIR/lib/commands/commit.sh" "$commit_message"
  )
fi

success "${#projects[@]} proyecto(s) Quarto construido(s) y publicado(s)."
detail "Log: $LOG_FILE"
