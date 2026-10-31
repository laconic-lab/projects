#!/usr/bin/env bash
set -Eeuo pipefail

LOG_DIR="/home/deck/OdysseusProject/data/logs"
LINES="${1:-100}"

if [[ "$#" -gt 1 || ! "$LINES" =~ ^[1-9][0-9]{0,3}$ ]] || (( LINES > 5000 )); then
    printf 'Usage: %s [lines: 1-5000]\n' "$0" >&2
    exit 2
fi

show_log() {
    local name="$1"
    local path="$LOG_DIR/$name"

    printf '\n===== %s — last %s lines =====\n' "$name" "$LINES"

    if [[ ! -f "$path" ]]; then
        printf '[NOT FOUND] %s\n' "$path"
        return 0
    fi

    if [[ ! -r "$path" ]]; then
        printf '[NOT READABLE] %s\n' "$path"
        return 0
    fi

    tail -n "$LINES" -- "$path"
}

printf 'ODYSSEUS — READ-ONLY LOG VIEWER\n'
printf 'Log directory: %s\n' "$LOG_DIR"

show_log "app.log"
show_log "uvicorn-console.log"

printf '\n===== END OF LOGS =====\n'
