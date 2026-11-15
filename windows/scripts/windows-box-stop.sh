#!/usr/bin/env bash
set -euo pipefail

NAME="windows-box"

if podman container exists "$NAME"; then
    podman stop --time 120 "$NAME"
else
    echo "windows-box does not exist."
fi
