#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

IASI_QUARTO_OPERATION=build exec "$SCRIPT_DIR/publish.sh" "$@"
