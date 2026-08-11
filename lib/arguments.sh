#!/usr/bin/env bash

# -----------------------------------------------------------------------------
# IASI Tools - Common arguments
# -----------------------------------------------------------------------------

IASI_HELP=0
IASI_ARGUMENT_ERROR=""

iasi_parse_arguments() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -h|--help)
        IASI_HELP=1
        ;;
      -v)
        IASI_VERBOSITY=2
        ;;
      -s)
        IASI_VERBOSITY=0
        ;;
      *)
        IASI_ARGUMENT_ERROR="$1"
        return 2
        ;;
    esac

    shift
  done
}
