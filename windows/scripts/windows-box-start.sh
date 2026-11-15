#!/usr/bin/env bash
set -euo pipefail

PROJECT="/home/deck/WindowsVM"
CONFIG="$PROJECT/config"
NAME="windows-box"
IMAGE="docker.io/dockurr/windows@sha256:59f8bed19cfd49cf1701debe34f9df6311e61a4e2ae68aa9f41206e2184e31cc"
if [[ ! -r "$CONFIG/windows-box.env" ]]; then
    echo "ERROR: Environment configuration is missing."
    exit 1
fi

if ! podman image exists "$IMAGE"; then
    echo "ERROR: Pinned image digest is not available locally."
    exit 1
fi

if podman container exists "$NAME"; then
    STATE="$(podman inspect --format '{{.State.Status}}' "$NAME")"
    if [[ "$STATE" == "running" ]]; then
        echo "windows-box is already running."
        exit 0
    fi

    echo "Starting existing windows-box container..."
    podman start "$NAME"
else
    echo "Creating windows-box with persistent storage..."

    podman run --detach \
        --name "$NAME" \
        --pull=never \
        --restart=no \
        --stop-timeout 120 \
        --device=/dev/kvm \
        --publish 192.168.1.161:8006:8006 \
        --volume "$PROJECT/storage:/storage:rw" \
        --volume "$PROJECT/shared:/shared:rw" \
        --env-file "$CONFIG/windows-box.env" \
        "$IMAGE"
fi

echo
echo "Windows VM container started."
echo "Web console: http://192.168.1.161:8006"
