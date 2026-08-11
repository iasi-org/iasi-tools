#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_DIR="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
COMPOSE_DIR="$TOOLS_DIR/docker"
COMPOSE_FILE="$COMPOSE_DIR/iasi-compose.yml"

source "$TOOLS_DIR/lib/core/messages.sh"

usage() {
  cat <<EOF
Usage: iasi docker [start|stop|status]

Manages the containers defined in docker/iasi-compose.yml.
Without a command, start is used.

Commands:
  start    Create and start the containers
  stop     Stop and remove the containers
  status   Show the container status
EOF
}

if [ "$#" -gt 1 ]; then
  error "Solo se puede indicar un comando."
  usage >&2
  exit 2
fi

command="${1:-start}"

case "$command" in
  start)
    info "Iniciando contenedores Docker."

    if ! docker compose \
      --project-directory "$COMPOSE_DIR" \
      -f "$COMPOSE_FILE" \
      up -d; then
      error "No se pudieron iniciar los contenedores Docker."
      exit 1
    fi

    success "Contenedores Docker iniciados."
    ;;
  stop)
    info "Deteniendo contenedores Docker."

    if ! docker compose \
      --project-directory "$COMPOSE_DIR" \
      -f "$COMPOSE_FILE" \
      down; then
      error "No se pudieron detener los contenedores Docker."
      exit 1
    fi

    success "Contenedores Docker detenidos."
    ;;
  status)
    docker compose \
      --project-directory "$COMPOSE_DIR" \
      -f "$COMPOSE_FILE" \
      ps
    ;;
  -h|--help)
    usage
    ;;
  *)
    error "Comando no válido: $command"
    usage >&2
    exit 2
    ;;
esac
