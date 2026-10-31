#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="/home/deck/OdysseusProject"
TOOLS_DIR="$PROJECT_DIR/decktools"
RUNTIME_DIR="$TOOLS_DIR/runtime"
PID_FILE="$RUNTIME_DIR/odysseus.pid"
CHROMA_MARKER="$RUNTIME_DIR/chromadb.started-by-odysseus"
LOG_FILE="$PROJECT_DIR/data/logs/uvicorn-console.log"

CHROMA_NAME="odysseus-chromadb"
CHROMA_HEALTH_URL="http://127.0.0.1:8100/api/v2/heartbeat"
APP_HEALTH_URL="http://127.0.0.1:7011/"

cd "$PROJECT_DIR"

mkdir -p "$RUNTIME_DIR" "$PROJECT_DIR/data/logs"

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

echo "===== ODYSSEUS START ====="

# Check the recorded PID first.
if [[ -f "$PID_FILE" ]]; then
    OLD_PID="$(cat "$PID_FILE")"

    if is_odysseus_pid "$OLD_PID"; then
        echo "Odysseus is already running (PID $OLD_PID)."
        exit 0
    fi

    echo "Removing stale or invalid PID file."
    rm -f "$PID_FILE"
fi

# Detect an existing instance even if it has no PID file.
for PROC_DIR in /proc/[0-9]*; do
    [[ -r "$PROC_DIR/cmdline" ]] || continue
    PROC_PID="${PROC_DIR##*/}"

    if is_odysseus_pid "$PROC_PID"; then
        echo "Existing Odysseus process detected (PID $PROC_PID)."
        echo "Refusing to start a duplicate."
        exit 1
    fi
done

# Check the dedicated ChromaDB container.
if ! host_podman container exists "$CHROMA_NAME"; then
    echo "ERROR: Dedicated ChromaDB container was not found."
    exit 1
fi

CHROMA_RUNNING="$(host_podman inspect "$CHROMA_NAME" \
    --format '{{.State.Running}}')"

if [[ "$CHROMA_RUNNING" != "true" ]]; then
    echo "Starting existing ChromaDB container..."
    host_podman start "$CHROMA_NAME" >/dev/null
    touch "$CHROMA_MARKER"
else
    echo "ChromaDB is already running; ownership remains unchanged."
fi

# Wait up to 30 seconds for ChromaDB.
echo "Waiting for ChromaDB health..."
CHROMA_READY=false

for _ in $(seq 1 30); do
    if curl -fsS --max-time 2 "$CHROMA_HEALTH_URL" >/dev/null; then
        CHROMA_READY=true
        break
    fi
    sleep 1
done

if [[ "$CHROMA_READY" != "true" ]]; then
    echo "ERROR: ChromaDB did not become healthy."
    echo "If this script started it, the ownership marker is retained."
    exit 1
fi

echo "ChromaDB is healthy."

# Launch Odysseus detached from the terminal.
echo "Starting Odysseus in the background..."

nohup "$PROJECT_DIR/.venv/bin/python" -m uvicorn app:app \
    --host 0.0.0.0 --port 7011 \
    >> "$LOG_FILE" 2>&1 </dev/null &

APP_PID=$!
echo "$APP_PID" > "$PID_FILE"

# Gracefully clean up only the process launched by this script.
cleanup_failed_start() {
    echo "Attempting graceful cleanup of failed startup..."

    if is_odysseus_pid "$APP_PID"; then
        kill -TERM "$APP_PID" 2>/dev/null || true

        for _ in $(seq 1 10); do
            if ! is_odysseus_pid "$APP_PID"; then
                break
            fi
            sleep 1
        done

        if is_odysseus_pid "$APP_PID"; then
            echo "WARNING: Process remains active after 10 seconds."
            echo "PID file retained for manual inspection: $PID_FILE"
            return 1
        fi
    else
        echo "Process identity no longer matches; no signal sent."
    fi

    if [[ -f "$PID_FILE" ]] &&
       [[ "$(cat "$PID_FILE")" == "$APP_PID" ]]; then
        rm -f "$PID_FILE"
    fi

    echo "Failed-start cleanup completed."
}

# Wait up to 30 seconds for the application.
echo "Waiting for Odysseus HTTP response..."

for _ in $(seq 1 30); do
    if ! is_odysseus_pid "$APP_PID"; then
        echo "ERROR: Odysseus process exited or failed identity verification."

        if [[ -f "$PID_FILE" ]] &&
           [[ "$(cat "$PID_FILE")" == "$APP_PID" ]]; then
            rm -f "$PID_FILE"
        fi

        exit 1
    fi

    HTTP_CODE="$(curl -sS -o /dev/null -w '%{http_code}' \
        --max-time 2 "$APP_HEALTH_URL" 2>/dev/null || true)"

    if [[ "$HTTP_CODE" =~ ^[23][0-9][0-9]$ ]]; then
        if ! is_odysseus_pid "$APP_PID"; then
            echo "ERROR: HTTP responded, but PID verification failed."
            cleanup_failed_start || true
            exit 1
        fi

        echo "Odysseus is responding (HTTP $HTTP_CODE)."
        echo "Verified PID: $APP_PID"
        echo "Console log: $LOG_FILE"
        exit 0
    fi

    sleep 1
done

echo "ERROR: Odysseus did not respond within 30 seconds."
echo "Inspect: $LOG_FILE"
cleanup_failed_start || true
exit 1
