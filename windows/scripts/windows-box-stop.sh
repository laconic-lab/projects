#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# WINDOWS VM STOP TEMPLATE
#
# Copy this file into a VM project's config/ directory and set NAME to that
# project's container name. Requests a graceful stop through Podman.
# It does not remove the container or delete persistent VM storage.
# =============================================================================

# ----- CONFIGURATION: customize for each VM ----------------------------------

NAME="windows-box"

# Allow this many seconds for the guest to shut down before Podman escalates.
STOP_TIMEOUT="120"

# ----- STOP -------------------------------------------------------------------

if ! podman container exists "$NAME"; then
    echo "$NAME does not exist."
    exit 0
fi

STATE="$(podman inspect --format '{{.State.Status}}' "$NAME")"

case "$STATE" in
    running)
        echo "Requesting graceful shutdown of $NAME (timeout: ${STOP_TIMEOUT}s)..."
        podman stop --time "$STOP_TIMEOUT" "$NAME"
        ;;
    exited|created|configured)
        echo "$NAME is already stopped (state: $STATE)."
        ;;
    *)
        echo "No stop action taken. $NAME is in state: $STATE"
        ;;
esac
