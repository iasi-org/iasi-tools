#!/usr/bin/env bash

# -----------------------------------------------------------------------------
# IASI Tools - Common repository list
# -----------------------------------------------------------------------------

IASI_ORG="${IASI_ORG:-iasi-org}"

iasi_repositories() {
  gh repo list "$IASI_ORG" \
    --limit 100 \
    --no-archived \
    --json name,sshUrl \
    --jq '.[] | "\(.name)|\(.sshUrl)"'
}
