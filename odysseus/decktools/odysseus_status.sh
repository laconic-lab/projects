#!/usr/bin/env bash
set -u

PROJECT_DIR="/home/deck/OdysseusProject"
RUNTIME_DIR="$PROJECT_DIR/decktools/runtime"
PID_FILE="$RUNTIME_DIR/odysseus.pid"
CHROMA_MARKER="$RUNTIME_DIR/chromadb.started-by-odysseus"

APP_HEALTH_URL="http://127.0.0.1:7011/"
CHROMA_HEALTH_URL="http://127.0.0.1:8100/api/v2/heartbeat"
CHROMA_NAME="odysseus-chromadb"

cd "$PROJECT_DIR" || exit 1

host_podman() {
    distrobox-host-exec podman "$@"
}

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

echo "===== ODYSSEUS STATUS ====="

echo
echo "----- ODYSSEUS PROCESS -----"

FOUND_APP=false
FOUND_PID=""
FOUND_COUNT=0

for PROC_DIR in /proc/[0-9]*; do
    [[ -r "$PROC_DIR/cmdline" ]] || continue
    PROC_PID="${PROC_DIR##*/}"

    if is_odysseus_pid "$PROC_PID"; then
        FOUND_APP=true
        FOUND_COUNT=$((FOUND_COUNT + 1))
        FOUND_PID="$PROC_PID"
        echo "RUNNING: Odysseus process detected (PID $PROC_PID)."
    fi
done

if (( FOUND_COUNT > 1 )); then
    echo "WARNING: Multiple Odysseus processes detected ($FOUND_COUNT)."
fi

if [[ "$FOUND_APP" != "true" ]]; then
    echo "STOPPED: No Odysseus process detected."
fi

echo
echo "----- PID FILE -----"

if [[ -f "$PID_FILE" ]]; then
    RECORDED_PID="$(cat "$PID_FILE")"
    echo "Present: $PID_FILE"
    echo "Recorded PID: $RECORDED_PID"

    if is_odysseus_pid "$RECORDED_PID"; then
        echo "MATCH: PID file identifies a running Odysseus process."
    else
        echo "WARNING: PID file does not identify a running Odysseus process."
    fi

    if [[ "$FOUND_APP" == "true" && "$RECORDED_PID" != "$FOUND_PID" ]]; then
        echo "WARNING: Detected process PID differs from the PID file."
    fi
else
    echo "Absent: No Odysseus PID file."
    if [[ "$FOUND_APP" == "true" ]]; then
        echo "WARNING: Odysseus is running without its PID file."
    fi
fi

echo
echo "----- APPLICATION HTTP -----"

APP_HTTP_CODE="$(curl -sS -o /dev/null -w '%{http_code}' \
    --max-time 3 "$APP_HEALTH_URL" 2>/dev/null || true)"

if [[ "$APP_HTTP_CODE" =~ ^[23][0-9][0-9]$ ]]; then
    echo "RESPONDING: HTTP $APP_HTTP_CODE"
else
    echo "NOT RESPONDING: HTTP ${APP_HTTP_CODE:-no response}"
fi

echo
echo "----- LISTENING PORTS -----"

if command -v ss >/dev/null 2>&1; then
    if ! ss -ltnp | grep -E ':(7011|8100)\b'; then
        echo "No listeners detected on ports 7011 or 8100."
    fi
else
    echo "WARNING: ss command is unavailable."
fi

echo
echo "----- CHROMADB CONTAINER -----"

if host_podman container exists "$CHROMA_NAME" 2>/dev/null; then
    CHROMA_RUNNING="$(host_podman inspect "$CHROMA_NAME" \
        --format '{{.State.Running}}' 2>/dev/null || true)"

    if [[ "$CHROMA_RUNNING" == "true" ]]; then
        echo "RUNNING: $CHROMA_NAME"
    elif [[ "$CHROMA_RUNNING" == "false" ]]; then
        echo "STOPPED: $CHROMA_NAME"
    else
        echo "WARNING: Could not determine container state."
    fi
else
    echo "MISSING: $CHROMA_NAME"
fi

echo
echo "----- CHROMADB HEARTBEAT -----"

if CHROMA_RESPONSE="$(curl -fsS --max-time 3 \
    "$CHROMA_HEALTH_URL" 2>/dev/null)"; then
    echo "RESPONDING: $CHROMA_RESPONSE"
else
    echo "NOT RESPONDING: No successful heartbeat."
fi

echo
echo "----- CHROMADB OWNERSHIP -----"

if [[ -e "$CHROMA_MARKER" ]]; then
    echo "Present: Odysseus START recorded that it started ChromaDB."
else
    echo "Absent: Odysseus does not currently claim ChromaDB ownership."
fi

echo
echo "----- LOG FILES -----"

for LOG_FILE in \
    "$PROJECT_DIR/data/logs/app.log" \
    "$PROJECT_DIR/data/logs/uvicorn-console.log"; do

    if [[ -f "$LOG_FILE" ]]; then
        LOG_SIZE="$(stat -c '%s bytes' "$LOG_FILE" 2>/dev/null || echo "size unavailable")"
        echo "Present: $LOG_FILE ($LOG_SIZE)"
    else
        echo "Absent: $LOG_FILE"
    fi
done

echo
echo "===== STATUS REPORT COMPLETE ====="
