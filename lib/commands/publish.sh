#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_DIR="$(cd -- "$SCRIPT_DIR/../.." && pwd)"

source "$TOOLS_DIR/lib/core/messages.sh"

operation="${IASI_QUARTO_OPERATION:-publish}"

if [ "$operation" != "build" ] && [ "$operation" != "publish" ]; then
  error "Operación Quarto interna desconocida: $operation"
  exit 2
fi

usage() {
  if [ "$operation" = "build" ]; then
    cat <<'EOF'
Usage: iasi-dev build [repository]

Recursively finds repositories containing IASI Quarto projects, then runs
iasi.quarto::build() once at each repository root. Directories named tests are
excluded from discovery.

Arguments:
  repository  Repository or directory to search; current directory by default

Options:
  -v           Show detailed information, including success messages
  -h, --help  Show this help
EOF
  else
    cat <<'EOF'
Usage: iasi-dev publish [repository]

Recursively finds repositories containing IASI Quarto projects, then runs
iasi.quarto::publish() once at each repository root.
Multiproject repositories are assembled into a single root publish/ directory.
Directories named tests are excluded from discovery.

Arguments:
  repository  Repository or directory to search; current directory by default

Options:
  -v           Show detailed information, including success messages
  -h, --help  Show this help
EOF
  fi
}

search_argument=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    -v)
      IASI_VERBOSITY=2
      shift
      ;;
    -*)
      error "Opción desconocida: $1"
      usage >&2
      exit 2
      ;;
    *)
      if [ -n "$search_argument" ]; then
        error "Solo se puede indicar un repositorio o directorio."
        usage >&2
        exit 2
      fi
      search_argument="$1"
      shift
      ;;
  esac
done

search_argument="${search_argument:-$PWD}"

if [ ! -d "$search_argument" ]; then
  error "No existe el directorio: $search_argument"
  exit 2
fi

SEARCH_DIR="$(cd -- "$search_argument" && pwd)"
if search_repository="$(git -C "$SEARCH_DIR" rev-parse --show-toplevel 2>/dev/null)"; then
  LOG_DIR="$(dirname -- "$search_repository")/logs"
else
  LOG_DIR="$SEARCH_DIR/logs"
fi
LOG_FILE="$LOG_DIR/iasi-$operation-$(date +%Y%m%d%H%M%S).log"

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
  printf "IASI %s started at %s\n" "$operation" "$(date --iso-8601=seconds)"
  printf "Directory: %s\n" "$SEARCH_DIR"
  printf "Operation: %s\n\n" "$operation"
} > "$LOG_FILE"

repositories=()

if [ -f "$SEARCH_DIR/_quarto.yml" ] && [ -f "$SEARCH_DIR/_iasi.yml" ]; then
  repositories+=("$SEARCH_DIR")
else
  while IFS= read -r -d '' quarto_file; do
    project_dir="$(dirname -- "$quarto_file")"

    repository_dir="$project_dir"
    ancestor="$project_dir"

    while [ "$ancestor" != "/" ] && [ "$ancestor" != "." ]; do
      if [ -e "$ancestor/.git" ]; then
        repository_dir="$ancestor"
        break
      fi

      parent="$(dirname -- "$ancestor")"
      [ "$parent" != "$ancestor" ] || break
      ancestor="$parent"
    done

    already_added=0
    for existing in "${repositories[@]}"; do
      if [ "$existing" = "$repository_dir" ]; then
        already_added=1
        break
      fi
    done

    if [ "$already_added" -eq 0 ]; then
      repositories+=("$repository_dir")
    fi
  done < <(
    find "$SEARCH_DIR" \
      -path '*/.git' -prune -o \
      -path '*/.quarto' -prune -o \
      -path '*/.codex*' -prune -o \
      -path '*/tests' -prune -o \
      -path '*/node_modules' -prune -o \
      -path '*/renv' -prune -o \
      -type f -name '_quarto.yml' -print0
  )
fi

if [ "${#repositories[@]}" -eq 0 ]; then
  error "No se encontraron proyectos con _quarto.yml en $SEARCH_DIR."
  exit 1
fi

for repository_dir in "${repositories[@]}"; do
  repository_name="$(basename -- "$repository_dir")"

  if [ "$operation" = "build" ]; then
    info "Construyendo $repository_name."
    r_expression='iasi.quarto::build()'
  else
    info "Publicando $repository_name."
    r_expression='iasi.quarto::publish()'
  fi
  printf "[%s]\n" "$repository_dir" >> "$LOG_FILE"

  subprojects=()
  while IFS= read -r -d '' quarto_file; do
    project_dir="$(dirname -- "$quarto_file")"

    if [ "$project_dir" != "$repository_dir" ]; then
      subprojects+=("${project_dir#"$repository_dir"/}")
    fi
  done < <(
    find "$repository_dir" \
      -path '*/.git' -prune -o \
      -path '*/.quarto' -prune -o \
      -path '*/.codex*' -prune -o \
      -path '*/tests' -prune -o \
      -path '*/node_modules' -prune -o \
      -path '*/renv' -prune -o \
      -type f -name '_quarto.yml' -print0
  )

  if [ "${#subprojects[@]}" -gt 0 ]; then
    info "Subproyectos Quarto:"
    printf "Subprojects:\n" >> "$LOG_FILE"

    for subproject in "${subprojects[@]}"; do
      info "- $subproject"
      printf -- "- %s\n" "$subproject" >> "$LOG_FILE"
    done
  fi

  if ! (
    cd -- "$repository_dir"
    PATH="$QUARTO_BIN_DIR:$PATH" \
      "$RSCRIPT_BIN" -e "$r_expression"
  ) >> "$LOG_FILE" 2>&1; then
    error "No se pudo ejecutar $operation: $repository_dir"
    warning "Consulta el log: $LOG_FILE"
    exit 1
  fi

  printf "\n" >> "$LOG_FILE"
  success_detail "$repository_name: $operation completado."
done

success "${#repositories[@]} repositorio(s) Quarto: $operation completado."
