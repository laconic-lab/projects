#!/usr/bin/env bash
set -uo pipefail

# Steam Deck host dashboard.
# SSH, the pihole container, and the pihole-box Distrobox are protected.

GREEN=$'\033[32m'
YELLOW=$'\033[33m'
RED=$'\033[31m'
CYAN=$'\033[36m'
RESET=$'\033[0m'
BOLD=$'\033[1m'

LOCALAI_BOX="localai-box"
STABLE_BOX="Stable-box"
ODYSSEUS_BOX="odysseus-box"
PIHOLE_BOX="pihole-box"
PIHOLE_CONTAINER="pihole"

PROJECT="/home/deck/LocalAIProject"
LOCALAI_STOP="$PROJECT/scripts/localai-stop.sh"
SHYRKA_STOP="/home/deck/LocalAIProject/AIAgent/dashboard/webui-stop.sh"
STABLE_STOP="/home/deck/StableDiffusionProject/sd-stop.sh"
ODYSSEUS_STOP="/home/deck/OdysseusProject/decktools/odysseus_stop.sh"
ODYSSEUS_PID_FILE="/home/deck/OdysseusProject/decktools/runtime/odysseus.pid"
ODYSSEUS_CHROMA_MARKER="/home/deck/OdysseusProject/decktools/runtime/chromadb.started-by-odysseus"

say()   { printf '%s\n' "$*"; }
good()  { printf '%s[OK]%s %s\n' "$GREEN" "$RESET" "$*"; }
warn()  { printf '%s[!]%s %s\n' "$YELLOW" "$RESET" "$*"; }
bad()   { printf '%s[ERROR]%s %s\n' "$RED" "$RESET" "$*"; }
line()  { printf '%s\n' "------------------------------------------------------------"; }

ask_yes() {
    local answer
    printf '%s [y/N] ' "$1"
    IFS= read -r answer || answer=""
    [[ "$answer" == "y" || "$answer" == "Y" ]]
}

box_state() {
    local state
    state="$(podman inspect --format '{{.State.Status}}' "$1" 2>/dev/null)" || {
        printf 'unknown'
        return
    }
    printf '%s' "$state"
}

box_running() {
    [[ "$(box_state "$1")" == "running" ]]
}

# Return codes: 0 = exact process found, 1 = confirmed absent, 2 = unknown.
# Match complete NUL-separated command lines; never use pgrep -f here.
process_state() {
    local box="$1"
    local expected="$2"
    local output rc

    box_running "$box" || {
        local state
        state="$(box_state "$box")"
        [[ "$state" == "exited" || "$state" == "stopped" ]] && return 1
        return 2
    }

    output="$(podman exec "$box" python3 -c '
import glob, sys
expected = sys.argv[1]
found = False
try:
    paths = glob.glob("/proc/[0-9]*/cmdline")
    for path in paths:
        try:
            raw = open(path, "rb").read()
        except (OSError, PermissionError):
            continue
        if not raw:
            continue
        actual = raw.replace(b"\0", b" ").decode("utf-8", "replace").rstrip()
        if actual == expected:
            found = True
            break
    print("RUNNING" if found else "ABSENT")
except Exception:
    print("UNKNOWN")
    sys.exit(2)
' "$expected" 2>/dev/null)" || return 2

    case "$output" in
        RUNNING) return 0 ;;
        ABSENT)  return 1 ;;
        *)       return 2 ;;
    esac
}

process_running() {
    process_state "$1" "$2"
}

# Odysseus requires exact argv + PID-file identity before it can be stopped.
# Return codes: 0 = one exact process matches its PID file,
# 1 = process and PID file both absent, 2 = mismatch/multiple/unknown.
odysseus_process_state() {
    local state output

    state="$(box_state "$ODYSSEUS_BOX")"
    if [[ "$state" == "exited" || "$state" == "stopped" ]]; then
        return 1
    fi
    [[ "$state" == "running" ]] || return 2

    output="$(podman exec "$ODYSSEUS_BOX" /usr/bin/python3 -c '
import glob, os, sys
expected = [
    b"/home/deck/OdysseusProject/.venv/bin/python",
    b"-m", b"uvicorn", b"app:app",
    b"--host", b"0.0.0.0", b"--port", b"7011",
]
pid_file = sys.argv[1]
try:
    found = []
    for path in glob.glob("/proc/[0-9]*/cmdline"):
        try:
            with open(path, "rb") as stream:
                raw = stream.read()
        except OSError:
            continue
        argv = [part for part in raw.split(b"\0") if part]
        if argv == expected:
            found.append(path.split("/")[2])
    exists = os.path.exists(pid_file)
    if len(found) == 0 and not exists:
        print("ABSENT")
    elif len(found) == 1 and exists:
        with open(pid_file, "r", encoding="ascii") as stream:
            recorded = stream.read().strip()
        print("RUNNING" if recorded.isdigit() and recorded == found[0] else "UNKNOWN")
    else:
        print("UNKNOWN")
except Exception:
    print("UNKNOWN")
    sys.exit(2)
' "$ODYSSEUS_PID_FILE" 2>/dev/null)" || return 2

    case "$output" in
        RUNNING) return 0 ;;
        ABSENT)  return 1 ;;
        *)       return 2 ;;
    esac
}

# Return codes: 0 = Stable server found, 1 = confirmed absent, 2 = unknown.
stable_process_state() {
    local output

    box_running "$STABLE_BOX" || {
        local state
        state="$(box_state "$STABLE_BOX")"
        [[ "$state" == "exited" || "$state" == "stopped" ]] && return 1
        return 2
    }

    output="$(podman exec "$STABLE_BOX" python3 -c '
import glob, os, sys

try:
    for path in glob.glob("/proc/[0-9]*/cmdline"):
        try:
            raw = open(path, "rb").read()
        except OSError:
            continue
        if not raw:
            continue
        argv = [x.decode("utf-8", "replace") for x in raw.split(b"\0") if x]
        if not argv:
            continue
        if os.path.basename(argv[0]) != "sd-server":
            continue
        args = argv[1:]
        if ("--listen-ip" in args and
            args[args.index("--listen-ip") + 1:args.index("--listen-ip") + 2] == ["127.0.0.1"] and
            "--listen-port" in args and
            args[args.index("--listen-port") + 1:args.index("--listen-port") + 2] == ["1234"]):
            print("RUNNING")
            sys.exit(0)
    print("ABSENT")
except Exception:
    print("UNKNOWN")
    sys.exit(2)
' 2>/dev/null)" || return 2

    case "$output" in
        RUNNING) return 0 ;;
        ABSENT)  return 1 ;;
        *)       return 2 ;;
    esac
}

stop_box() {
    local box="$1"

    case "$box" in
        "$PIHOLE_BOX"|"$PIHOLE_CONTAINER")
            bad "Refusing to stop protected Pi-hole component: $box"
            return 1
            ;;
    esac

    if ! box_running "$box"; then
        good "$box is already stopped or not running."
        return 0
    fi

    say "Stopping Distrobox gracefully: $box"
    if distrobox stop --yes "$box"; then
        if ! box_running "$box"; then
            good "$box stopped."
            return 0
        fi
    fi

    bad "$box did not confirm a stopped state."
    return 1
}

run_in_box() {
    local box="$1"
    local command="$2"

    if ! box_running "$box"; then
        warn "$box is not running; refusing to enter it for a stop operation."
        return 1
    fi

    podman exec "$box" bash -lc "$command"
}

show_status() {
    local state name status odysseus_status_rc
    local ollama_pattern='/usr/local/bin/ollama serve'
    local webui_pattern='/home/deck/LocalAIProject/open-webui-venv/bin/python /home/deck/LocalAIProject/open-webui-venv/bin/open-webui serve --host 192.168.1.161 --port 3000'
    local shyrka_pattern='/home/deck/LocalAIProject/AIAgent/.venv/bin/python /home/deck/LocalAIProject/AIAgent/dashboard/server.py'

    printf '\n%b%sSTEAM DECK — CHECKBOX STATUS%s\n' "$BOLD" "$CYAN" "$RESET"
    line

    printf '%bPROTECTED COMPONENTS%b\n' "$BOLD" "$RESET"
    printf 'SSH service: '
    if systemctl is-active --quiet sshd; then
        good "active"
    else
        bad "not active — dashboard will not attempt to change SSH"
    fi

    printf 'SSH port 22 listener: '
    if ss -ltn 2>/dev/null | awk '$4 ~ /:22$/ {found=1} END {exit !found}'; then
        good "listening"
    else
        warn "not detected"
    fi

    printf 'Pi-hole Podman container (%s): ' "$PIHOLE_CONTAINER"
    state="$(box_state "$PIHOLE_CONTAINER")"
    if [[ "$state" == "running" ]]; then
        good "running — protected"
    else
        bad "$state — protected; no automatic action"
    fi

    printf 'Pi-hole Distrobox (%s): ' "$PIHOLE_BOX"
    state="$(box_state "$PIHOLE_BOX")"
    if [[ "$state" == "running" ]]; then
        good "running — protected"
    else
        printf '%s%s%s\n' "$YELLOW" "$state — protected" "$RESET"
    fi

    line
    printf '%bKNOWN PROJECT SERVICES%b\n' "$BOLD" "$RESET"

    if box_running "$LOCALAI_BOX"; then
        printf 'Ollama: '
        if process_running "$LOCALAI_BOX" "$ollama_pattern"; then
            good "running"
        else
            warn "not detected"
        fi

        printf 'Open WebUI: '
        if process_running "$LOCALAI_BOX" "$webui_pattern"; then
            good "running"
        else
            warn "not detected"
        fi

        printf 'Shyrka Command Center: '
        if process_running "$LOCALAI_BOX" "$shyrka_pattern"; then
            good "running"
        else
            warn "not detected"
        fi
    else
        printf 'LocalAI / Shyrka services: %scontainer is %s%s\n' \
            "$YELLOW" "$(box_state "$LOCALAI_BOX")" "$RESET"
    fi

    printf 'LocalAI WebUI:  http://192.168.1.161:3000/\n'
    printf 'Shyrka Center:  http://192.168.1.161:8765/\n'

    printf 'Stable-box: '
    state="$(box_state "$STABLE_BOX")"
    if [[ "$state" == "running" ]]; then
        good "running"
    else
        printf '%s%s%s\n' "$YELLOW" "$state" "$RESET"
    fi

    printf 'Odysseus: '
    state="$(box_state "$ODYSSEUS_BOX")"
    if [[ "$state" == "running" ]]; then
        if odysseus_process_state; then
            good "Uvicorn running — PID file matches"
        else
            odysseus_status_rc=$?
            if [[ "$odysseus_status_rc" -eq 1 ]]; then
                warn "application stopped"
            else
                bad "process/PID state unknown or mismatched"
            fi
        fi
    else
        printf '%s%s%s\n' "$YELLOW" "$state" "$RESET"
    fi
    printf 'Odysseus UI:   http://192.168.1.161:7011/\n'

    line
    printf '%bDISTROBOX INVENTORY%b\n' "$BOLD" "$RESET"
    distrobox list --no-color 2>&1 || warn "Could not read Distrobox inventory."

    line
    printf '%bPODMAN CONTAINER INVENTORY%b\n' "$BOLD" "$RESET"
    podman ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' 2>&1 ||
        warn "Could not read Podman inventory."

    line
    say "Unknown boxes are displayed for visibility but are never auto-stopped."
    say "SSH and both Pi-hole components are excluded from shutdown actions."
}

stop_localai_service() {
    say "Running LocalAI's own graceful stop script..."
    run_in_box "$LOCALAI_BOX" "'$LOCALAI_STOP'"
}

stop_shyrka_service() {
    say "Running Shyrka's own stop script..."
    run_in_box "$LOCALAI_BOX" "'$SHYRKA_STOP'"
}

stop_stable_service() {
    say "Running Stable Diffusion's own stop script..."
    run_in_box "$STABLE_BOX" "'$STABLE_STOP'"
}

stop_odysseus_service() {
    say "Running Odysseus's own stop script..."
    run_in_box "$ODYSSEUS_BOX" "'$ODYSSEUS_STOP'"
}

shutdown_menu() {
    local all=0
    local localai_ok=2
    local shyrka_ok=2
    local stable_ok=2
    local odysseus_ok=2
    local odysseus_rc=2
    local chroma_marker_state=2
    local marker_rc chroma_state
    local answer
    local ollama_rc webui_rc shyrka_rc stable_rc
    local unknown

    local ollama_cmd='/usr/local/bin/ollama serve'
    local webui_cmd='/home/deck/LocalAIProject/open-webui-venv/bin/python /home/deck/LocalAIProject/open-webui-venv/bin/open-webui serve --host 192.168.1.161 --port 3000'
    local shyrka_cmd='/home/deck/LocalAIProject/AIAgent/.venv/bin/python /home/deck/LocalAIProject/AIAgent/dashboard/server.py'

    printf '\n%bSHUTDOWN OPTIONS%b\n' "$BOLD" "$RESET"
    say "y = ask about eligible services and boxes one by one"
    say "a = stop supported services, then eligible boxes"
    say "Enter = exit without changes"
    printf 'Choose [y/a/Enter]: '
    IFS= read -r answer || answer=""

    case "$answer" in
        a|A) all=1 ;;
        y|Y) all=0 ;;
        *) say "No changes requested."; return 0 ;;
    esac

    # Establish Odysseus state using exact argv + matching PID-file identity.
    if odysseus_process_state; then
        odysseus_ok=0
    else
        odysseus_rc=$?
        [[ "$odysseus_rc" -eq 1 ]] && odysseus_ok=1 || odysseus_ok=2
    fi

    # Read ChromaDB ownership without changing it.
    if box_running "$ODYSSEUS_BOX"; then
        if podman exec "$ODYSSEUS_BOX" test -e "$ODYSSEUS_CHROMA_MARKER" 2>/dev/null; then
            chroma_marker_state=1
        else
            marker_rc=$?
            [[ "$marker_rc" -eq 1 ]] && chroma_marker_state=0 || chroma_marker_state=2
        fi
    elif [[ "$(box_state "$ODYSSEUS_BOX")" == "exited" || "$(box_state "$ODYSSEUS_BOX")" == "stopped" ]]; then
        chroma_marker_state=0
    else
        chroma_marker_state=2
    fi

    # If Odysseus is absent but still owns ChromaDB, run its STOP script
    # for ownership cleanup before considering the Distrobox shutdown.
    if [[ "$chroma_marker_state" -eq 2 ]]; then
        odysseus_ok=2
    elif [[ "$odysseus_ok" -eq 1 && "$chroma_marker_state" -eq 1 ]]; then
        odysseus_ok=0
    fi

    # Establish LocalAI and Shyrka states independently.
    if ! box_running "$LOCALAI_BOX"; then
        case "$(box_state "$LOCALAI_BOX")" in
            exited|stopped) localai_ok=1; shyrka_ok=1 ;;
            *)              localai_ok=2; shyrka_ok=2 ;;
        esac
    else
        if process_state "$LOCALAI_BOX" "$ollama_cmd"; then
            ollama_rc=0
        else
            ollama_rc=$?
        fi

        if process_state "$LOCALAI_BOX" "$webui_cmd"; then
            webui_rc=0
        else
            webui_rc=$?
        fi

        if [[ "$ollama_rc" -eq 2 || "$webui_rc" -eq 2 ]]; then
            localai_ok=2
        elif [[ "$ollama_rc" -eq 0 || "$webui_rc" -eq 0 ]]; then
            localai_ok=0
        else
            localai_ok=1
        fi

        if process_state "$LOCALAI_BOX" "$shyrka_cmd"; then
            shyrka_ok=0
        else
            shyrka_rc=$?
            if [[ "$shyrka_rc" -eq 1 ]]; then
                shyrka_ok=1
            else
                shyrka_ok=2
            fi
        fi
    fi

    # LocalAI stop + independent post-stop verification.
    case "$localai_ok" in
        0)
            if [[ "$all" -eq 1 ]] || ask_yes "Stop LocalAI (Ollama + Open WebUI)?"; then
                if stop_localai_service; then
                    if process_state "$LOCALAI_BOX" "$ollama_cmd"; then
                        ollama_rc=0
                    else
                        ollama_rc=$?
                    fi
                    if process_state "$LOCALAI_BOX" "$webui_cmd"; then
                        webui_rc=0
                    else
                        webui_rc=$?
                    fi

                    if [[ "$ollama_rc" -eq 1 && "$webui_rc" -eq 1 ]]; then
                        localai_ok=1
                        good "LocalAI processes verified stopped."
                    elif [[ "$ollama_rc" -eq 2 || "$webui_rc" -eq 2 ]]; then
                        localai_ok=2
                        bad "LocalAI state is unknown after the stop script; its box will be kept running."
                    else
                        localai_ok=0
                        bad "A LocalAI process is still running; its box will be kept running."
                    fi
                else
                    localai_ok=0
                    bad "LocalAI stop script failed; its box will be kept running."
                fi
            fi
            ;;
        1) good "LocalAI processes verified absent." ;;
        *) warn "LocalAI process state is unknown; refusing its stop operation and box shutdown." ;;
    esac

    # Shyrka stop + independent post-stop verification.
    case "$shyrka_ok" in
        0)
            if [[ "$all" -eq 1 ]] || ask_yes "Stop Shyrka Command Center?"; then
                if stop_shyrka_service; then
                    if process_state "$LOCALAI_BOX" "$shyrka_cmd"; then
                        shyrka_ok=0
                    else
                        shyrka_rc=$?
                        if [[ "$shyrka_rc" -eq 1 ]]; then
                            shyrka_ok=1
                            good "Shyrka process verified stopped."
                        else
                            shyrka_ok=2
                            bad "Shyrka state is unknown after the stop script."
                        fi
                    fi
                else
                    shyrka_ok=0
                    bad "Shyrka stop script failed; its box will be kept running."
                fi
            fi
            ;;
        1) good "Shyrka process verified absent." ;;
        *) warn "Shyrka process state is unknown; refusing its stop operation and box shutdown." ;;
    esac

    # Odysseus stop + independent process/PID/ownership verification.
    case "$odysseus_ok" in
        0)
            if [[ "$all" -eq 1 ]] || ask_yes "Stop Odysseus gracefully?"; then
                if [[ "$chroma_marker_state" -eq 2 ]]; then
                    odysseus_ok=2
                    bad "ChromaDB ownership state is unknown; refusing Odysseus stop."
                elif stop_odysseus_service; then
                    if odysseus_process_state; then
                        odysseus_ok=0
                        bad "Odysseus is still running; odysseus-box will be kept running."
                    else
                        odysseus_rc=$?
                        if [[ "$odysseus_rc" -eq 1 ]] &&
                           podman exec "$ODYSSEUS_BOX" test ! -e "$ODYSSEUS_CHROMA_MARKER" 2>/dev/null; then
                            if [[ "$chroma_marker_state" -eq 1 ]]; then
                                chroma_state="$(podman inspect --format '{{.State.Status}}' odysseus-chromadb 2>/dev/null)" || chroma_state="unknown"
                                if [[ "$chroma_state" == "exited" || "$chroma_state" == "stopped" ]]; then
                                    odysseus_ok=1
                                    good "Odysseus and owned ChromaDB shutdown verified."
                                else
                                    odysseus_ok=2
                                    bad "Owned ChromaDB is not confirmed stopped; keeping odysseus-box."
                                fi
                            else
                                odysseus_ok=1
                                good "Odysseus process and PID file verified absent; unowned ChromaDB left untouched."
                            fi
                        else
                            odysseus_ok=2
                            bad "Odysseus process/PID or ownership state is unknown after stop."
                        fi
                    fi
                else
                    odysseus_ok=0
                    bad "Odysseus stop script failed; odysseus-box will be kept running."
                fi
            fi
            ;;
        1) good "Odysseus process and PID file verified absent." ;;
        *) warn "Odysseus process/PID state is unknown or mismatched; refusing stop and box shutdown." ;;
    esac

    # Stable Diffusion stop + independent post-stop verification.
    if ! box_running "$STABLE_BOX"; then
        case "$(box_state "$STABLE_BOX")" in
            exited|stopped) stable_ok=1 ;;
            *)              stable_ok=2 ;;
        esac
    else
        if stable_process_state; then
            stable_ok=0
        else
            stable_rc=$?
            if [[ "$stable_rc" -eq 1 ]]; then
                stable_ok=1
            else
                stable_ok=2
            fi
        fi
    fi

    case "$stable_ok" in
        0)
            if [[ "$all" -eq 1 ]] || ask_yes "Stop Stable Diffusion gracefully?"; then
                if stop_stable_service; then
                    if stable_process_state; then
                        stable_ok=0
                        bad "Stable server is still running; Stable-box will be kept running."
                    else
                        stable_rc=$?
                        if [[ "$stable_rc" -eq 1 ]]; then
                            stable_ok=1
                            good "Stable Diffusion process verified stopped."
                        else
                            stable_ok=2
                            bad "Stable process state is unknown; Stable-box will be kept running."
                        fi
                    fi
                else
                    stable_ok=0
                    bad "Stable stop script failed; Stable-box will be kept running."
                fi
            fi
            ;;
        1) good "Stable Diffusion process verified absent." ;;
        *) warn "Stable process state is unknown; refusing its stop operation and box shutdown." ;;
    esac

    line
    printf '%bBOX SHUTDOWN%b\n' "$BOLD" "$RESET"

    if box_running "$LOCALAI_BOX"; then
        if [[ "$localai_ok" -eq 1 && "$shyrka_ok" -eq 1 ]]; then
            if [[ "$all" -eq 1 ]] || ask_yes "Stop localai-box now?"; then
                stop_box "$LOCALAI_BOX" || true
            fi
        else
            warn "Keeping localai-box running: LocalAI and Shyrka must both be verified stopped."
        fi
    fi

    if box_running "$STABLE_BOX"; then
        if [[ "$stable_ok" -eq 1 ]]; then
            if [[ "$all" -eq 1 ]] || ask_yes "Stop Stable-box now?"; then
                stop_box "$STABLE_BOX" || true
            fi
        else
            warn "Keeping Stable-box running because Stable Diffusion was not confirmed stopped."
        fi
    fi

    if box_running "$ODYSSEUS_BOX"; then
        if [[ "$odysseus_ok" -eq 1 ]]; then
            if [[ "$all" -eq 1 ]] || ask_yes "Stop odysseus-box now?"; then
                stop_box "$ODYSSEUS_BOX" || true
            fi
        else
            warn "Keeping odysseus-box running because Odysseus shutdown was not fully verified."
        fi
    fi

    say "Shutdown sequence finished. Review any warnings above."
}

case "${1:-}" in
    --status-only)
        show_status
        exit 0
        ;;
    --help|-h)
        say "Usage: checkbox [--status-only|--help]"
        say "Default mode displays status and offers guarded shutdown options."
        exit 0
        ;;
    "")
        ;;
    *)
        bad "Unknown option: $1"
        say "Use --help for usage."
        exit 2
        ;;
esac

show_status
shutdown_menu
