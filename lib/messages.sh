#!/usr/bin/env bash

# -----------------------------------------------------------------------------
# IASI Tools - Common messages
# -----------------------------------------------------------------------------

IASI_VERBOSITY="${IASI_VERBOSITY:-1}"

# Colors
_IASI_BLUE="\033[0;34m"
_IASI_GREEN="\033[0;32m"
_IASI_YELLOW="\033[0;33m"
_IASI_RED="\033[0;31m"
_IASI_RESET="\033[0m"

_message() {
  local color="$1"
  local text="$2"

  printf "%b%s - %s%b\n", "$color", "$(date +%T)", "$text", "$_IASI_RESET"
}

info() {
  [ "$IASI_VERBOSITY" -ge 1 ] || return 0
  _message "$_IASI_BLUE" "$1"
}

detail() {
  [ "$IASI_VERBOSITY" -ge 2 ] || return 0
  _message "$_IASI_BLUE" "$1"
}

success() {
  [ "$IASI_VERBOSITY" -ge 1 ] || return 0
  _message "$_IASI_GREEN" "$1"
}

warning() {
  [ "$IASI_VERBOSITY" -ge 1 ] || return 0
  _message "$_IASI_YELLOW" "$1"
}

error() {
  _message "$_IASI_RED" "$1" >&2
}
