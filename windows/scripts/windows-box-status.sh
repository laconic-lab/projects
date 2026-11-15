#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# WINDOWS VM STATUS TEMPLATE
#
# Copy this file into a VM project's config/ directory and set NAME to that
# project's container name. Reports container state and important mount/port
# details without displaying environment-file contents.
# =============================================================================

# ----- CONFIGURATION: customize for each VM ----------------------------------

NAME="windows-box"

# ----- STATUS -----------------------------------------------------------------

if ! podman container exists "$NAME"; then
    echo "$NAME has not been created."
    exit 0
fi

echo "===== CONTAINER ====="
podman ps -a --filter "name=^$NAME$"

echo
echo "===== STATE ====="
podman inspect "$NAME" \
    --format 'Name={{.Name}} State={{.State.Status}} ExitCode={{.State.ExitCode}} Image={{.ImageName}} Restart={{.HostConfig.RestartPolicy.Name}}'

echo
echo "===== MOUNTS ====="
podman inspect "$NAME" \
    --format '{{range .Mounts}}{{println .Source "->" .Destination "RW=" .RW}}{{end}}'

echo
echo "===== PUBLISHED PORTS ====="
podman port "$NAME" || true

echo
echo "NOTE: If /custom.iso appears above, the container still has installation media"
echo "mounted. This script reports that state; it does not change the container."
