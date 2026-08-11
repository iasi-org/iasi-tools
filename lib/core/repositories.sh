#!/usr/bin/env bash

# -----------------------------------------------------------------------------
# IASI Tools - Core repository list
# -----------------------------------------------------------------------------

IASI_ORG="${IASI_ORG:-iasi-org}"

iasi_repositories() {
  gh repo list "$IASI_ORG" \
    --limit 100 \
    --no-archived \
    --json name,sshUrl,defaultBranchRef \
    --jq '.[] | "\(.name)|\(.sshUrl)|\(.defaultBranchRef.name)"'
}
