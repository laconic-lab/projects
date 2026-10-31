#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="/home/deck/OdysseusProject"
TOOLS_DIR="$PROJECT_DIR/decktools"
RUNTIME_DIR="$TOOLS_DIR/runtime"
PID_FILE="$RUNTIME_DIR/odysseus.pid"
CHROMA_MARKER="$RUNTIME_DIR/chromadb.started-by-odysseus"

CHROMA_NAME="odysseus-chromadb"

cd "$PROJECT_DIR"

host_podman() {
    distrobox-host-exec podman "$@"
}

# Verify that a PID is the expected, non-zombie Odysseus process.
is_odysseus_pid() {
    local pid="$1"
    local stat_line
    local state
    local cmdline

    [[ "$pid" =~ ^[0-9]+$ ]] || return 1
    [[ -r "/proc/$pid/stat" && -r "/proc/$pid/cmdline" ]] || return 1

    stat_line="$(<"/proc/$pid/stat")" || return 1
    state="${stat_line##*) }"
    state="${state%% *}"
    [[ "$state" != "Z" && "$state" != "X" ]] || return 1

    cmdline="$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null)" || return 1

    [[ "$cmdline" == *"$PROJECT_DIR/.venv/bin/python -m uvicorn app:app"* ]]
}

echo "===== ODYSSEUS STOP ====="

# Stop only the process recorded by the START script.
if [[ -f "$PID_FILE" ]]; then
    APP_PID="$(cat "$PID_FILE")"

    if is_odysseus_pid "$APP_PID"; then
        echo "Requesting graceful shutdown of Odysseus (PID $APP_PID)..."

        kill -TERM "$APP_PID"

        STOPPED=false

        for _ in $(seq 1 20); do
            if ! is_odysseus_pid "$APP_PID"; then
                STOPPED=true
                break
            fi
            sleep 1
        done

        if [[ "$STOPPED" != "true" ]]; then
            echo "ERROR: Odysseus is still running after 20 seconds."
            echo "No ChromaDB shutdown will be attempted."
            echo "PID file retained: $PID_FILE"
            exit 1
        fi

        echo "Odysseus stopped gracefully."

        if [[ -f "$PID_FILE" ]] &&
           [[ "$(cat "$PID_FILE")" == "$APP_PID" ]]; then
            rm -f "$PID_FILE"
        fi
    else
        echo "ERROR: PID file exists, but process identity cannot be verified."
        echo "No process signal sent and no ChromaDB shutdown attempted."
        echo "Inspect PID file: $PID_FILE"
        exit 1
    fi
else
    echo "No Odysseus PID file found."
    echo "No application process will be signalled."
fi

# Never stop ChromaDB while any Odysseus instance is still running.
for PROC_DIR in /proc/[0-9]*; do
    [[ -r "$PROC_DIR/cmdline" ]] || continue
    PROC_PID="${PROC_DIR##*/}"

    if is_odysseus_pid "$PROC_PID"; then
        echo "ERROR: Odysseus is still running (PID $PROC_PID)."
        echo "ChromaDB will be left untouched."
        exit 1
    fi
done

# ChromaDB is stopped only when the START script recorded ownership.
if [[ -e "$CHROMA_MARKER" ]]; then
    echo "ChromaDB ownership marker found."

    if ! host_podman container exists "$CHROMA_NAME"; then
        echo "ERROR: Owned ChromaDB container was not found."
        echo "Ownership marker retained for inspection."
        exit 1
    fi

    CHROMA_RUNNING="$(host_podman inspect "$CHROMA_NAME" \
        --format '{{.State.Running}}')"

    if [[ "$CHROMA_RUNNING" == "true" ]]; then
        echo "Stopping ChromaDB started by Odysseus..."
        host_podman stop --time 20 "$CHROMA_NAME" >/dev/null
    else
        echo "ChromaDB is already stopped."
    fi

    CHROMA_RUNNING="$(host_podman inspect "$CHROMA_NAME" \
        --format '{{.State.Running}}')"

    if [[ "$CHROMA_RUNNING" == "true" ]]; then
        echo "ERROR: ChromaDB remains running."
        echo "Ownership marker retained for inspection."
        exit 1
    fi

    rm -f "$CHROMA_MARKER"
    echo "ChromaDB stopped; ownership marker removed."
else
    echo "No ChromaDB ownership marker."
    echo "ChromaDB will be left untouched."
fi

echo
echo "===== STOP COMPLETE ====="
