#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# WINDOWS VM START TEMPLATE
#
# Copy this file into a VM project's config/ directory and adapt the values in
# the CONFIGURATION section. Keep one independently configured copy per VM.
#
# This script starts an existing container without changing its configuration,
# or creates a new container using the settings below.
#
# IMPORTANT:
#   - A normal runtime container intentionally omits /custom.iso.
#   - For installation only, add a temporary --volume mapping for
#     /custom.iso:ro to the podman run command. After installation, recreate
#     the container without that mapping.
#   - Starting an existing container does NOT remove or change any mounts.
#   - This script does not start automatically at host boot.
# =============================================================================

# ----- CONFIGURATION: customize these values for each VM ---------------------

# Absolute path to this VM's project directory.
PROJECT="/home/deck/WindowsVM"

# Podman container name. Must be unique among containers on this host.
NAME="windows-box"

# Environment file for this VM. Do not commit it: it may contain secrets.
ENV_FILE="$PROJECT/config/${NAME}.env"

# Pin the exact image version/digest used by this VM.
IMAGE="docker.io/dockurr/windows@sha256:59f8bed19cfd49cf1701debe34f9df6311e61a4e2ae68aa9f41206e2184e31cc"

# Host address and TCP port for the Dockur web console.
# Use a distinct host port if multiple VMs must run simultaneously.
HOST_IP="192.168.1.161"
HOST_PORT="8006"

# Graceful shutdown timeout, in seconds.
STOP_TIMEOUT="120"

# ----- PREFLIGHT --------------------------------------------------------------

if [[ ! -r "$ENV_FILE" ]]; then
    echo "ERROR: Environment configuration is missing or unreadable: $ENV_FILE"
    exit 1
fi

if [[ ! -d "$PROJECT/storage" || ! -d "$PROJECT/shared" ]]; then
    echo "ERROR: Expected storage/ and shared/ directories are missing."
    echo "Project: $PROJECT"
    exit 1
fi

if [[ ! -e /dev/kvm ]]; then
    echo "ERROR: /dev/kvm is not available; this configuration expects KVM."
    exit 1
fi

if ! podman image exists "$IMAGE"; then
    echo "ERROR: Pinned image digest is not available locally."
    exit 1
fi

# ----- START OR CREATE --------------------------------------------------------

if podman container exists "$NAME"; then
    STATE="$(podman inspect --format '{{.State.Status}}' "$NAME")"

    if [[ "$STATE" == "running" ]]; then
        echo "$NAME is already running."
        exit 0
    fi

    # Existing container settings (including mounts and published ports) remain
    # unchanged. Editing this script does not modify an existing container.
    ISO_MOUNT="$(podman inspect "$NAME" --format '{{range .Mounts}}{{if eq .Destination "/custom.iso"}}{{println .Source}}{{end}}{{end}}')"
    if [[ -n "$ISO_MOUNT" ]]; then
        echo "WARNING: Existing container still has installation media mounted:"
        echo "  $ISO_MOUNT -> /custom.iso"
        echo "That mount will remain when this container starts."
    fi

    echo "Starting existing $NAME container..."
    podman start "$NAME"
else
    echo "Creating $NAME with persistent storage..."

    # Normal runtime container: no installation ISO is mounted here.
    # For the temporary installation phase only, add a line such as:
    #   --volume "/absolute/path/to/windows.iso:/custom.iso:ro" \

    podman run --detach \
        --name "$NAME" \
        --pull=never \
        --restart=no \
        --stop-timeout "$STOP_TIMEOUT" \
        --device=/dev/kvm \
        --publish "$HOST_IP:$HOST_PORT:8006" \
        --volume "$PROJECT/storage:/storage:rw" \
        --volume "$PROJECT/shared:/shared:rw" \
        --env-file "$ENV_FILE" \
        "$IMAGE"
fi

echo
echo "$NAME started."
echo "Web console: http://$HOST_IP:$HOST_PORT"
