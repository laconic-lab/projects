#!/usr/bin/env bash
set -euo pipefail

NAME="windows-box"

if podman container exists "$NAME"; then
    podman ps -a --filter "name=^${NAME}$"
    echo
    podman inspect "$NAME" \
        --format 'State={{.State.Status}} ExitCode={{.State.ExitCode}}'
else
    echo "windows-box has not been created."
fi
