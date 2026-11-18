#!/bin/bash

# ---------- REPORT INITIALIZATION ----------
umask 077
REPORT_DIR="$HOME/Desktop"
if ! mkdir -p -- "$REPORT_DIR"; then
    printf 'ERROR: Cannot create report directory: %s\n' "$REPORT_DIR" >&2
    exit 2
fi
STAMP="$(date +%Y%m%d_%H%M%S)"
REPORT="$REPORT_DIR/${STAMP}_results_for_secureupdate.txt"
if ! ( set -o noclobber; : > "$REPORT" ) 2>/dev/null; then
    printf 'ERROR: Cannot create report file: %s\n' "$REPORT" >&2
    exit 2
fi
chmod 600 "$REPORT" || exit 2
exec > >(tee -a "$REPORT") 2>&1

# ---------- TERMINAL COLORS ----------
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
RESET='\033[0m'

green()  { printf "${GREEN}✔ %s${RESET}\n" "$*"; }
red()    { printf "${RED}✘ %s${RESET}\n" "$*"; }
yellow() { printf "${YELLOW}⚠ %s${RESET}\n" "$*"; }

# ---------- NVIDIA / KERNEL CHECK ----------
nvidia_check() {
    local stage="$1"
    local running_kernel latest_kernel
    local loaded_version module_version dkms_status

    running_kernel=$(uname -r)

    echo
    echo "========== NVIDIA / KERNEL CHECK: $stage =========="
    echo "Running kernel: $running_kernel"

    if [[ ! -r /proc/driver/nvidia/version ]]; then
        red "NVIDIA driver is not currently loaded."
        return 1
    fi

    loaded_version=$(grep -m1 'NVIDIA UNIX' \
        /proc/driver/nvidia/version |
        grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)

    if [[ "$loaded_version" != "470.256.02" ]]; then
        red "Loaded NVIDIA version is ${loaded_version:-UNKNOWN}, not 470.256.02."
        red "STOP: Review the NVIDIA driver state."
        return 1
    fi
    green "Loaded NVIDIA driver 470.256.02 verified"

    latest_kernel=$(find /lib/modules -mindepth 1 -maxdepth 1 \
        -type d -printf '%f\n' | sort -V | tail -n1)
    if [[ -z "$latest_kernel" ]]; then
        red "No installed kernel module directories found."
        return 1
    fi

    echo "Newest installed kernel: $latest_kernel"
    if [[ "$latest_kernel" != "$running_kernel" ]]; then
        yellow "Newest kernel differs from the running kernel. A reboot may be needed."
    fi

    module_version=$(modinfo -k "$latest_kernel" -F version nvidia 2>/dev/null)
    if [[ "$module_version" != "470.256.02" ]]; then
        red "NVIDIA module for $latest_kernel is ${module_version:-NOT FOUND}."
        red "Expected 470.256.02. STOP MAINTENANCE."
        return 1
    fi
    green "NVIDIA 470.256.02 module verified for $latest_kernel"

    dkms_status=$(dkms status 2>&1)
    echo
    echo "DKMS status:"
    printf '%s\n' "$dkms_status"

    if ! grep -F "nvidia/470.256.02, $latest_kernel," \
        <<< "$dkms_status" | grep -q 'installed'; then
        red "DKMS does not confirm NVIDIA 470.256.02 installed for $latest_kernel."
        red "STOP MAINTENANCE and review DKMS."
        return 1
    fi
    green "DKMS registration verified for $latest_kernel"
}

# ---------- FINAL PENDING-UPDATE REPORT ----------
secureupdate_final_report() {
    local original_status="$1"
    local apt_list holds normal_sim full_sim full_inst flatpak_updates line flatpak_rc
    local phased_names kept_names pkg arch candidate installed reason key

    echo
    red "========== UPDATES NOT INSTALLED — REVIEW REQUIRED =========="
    echo "This section lists pending updates; pending does not automatically mean unsafe."

    apt_list=$(apt list --upgradable 2>&1)
    local apt_list_rc=$?
    echo
    echo "--- APT PACKAGE CANDIDATES (installed version -> candidate version) ---"
    if (( apt_list_rc != 0 )); then
        yellow "Could not retrieve the APT candidate list:"
        printf '%s\n' "$apt_list"
    elif grep -q '/' <<< "$apt_list"; then
        while IFS= read -r line; do
            [[ "$line" == Listing* || -z "$line" ]] && continue
            red "$line"
        done <<< "$apt_list"
    else
        green "No APT package candidates reported by apt list --upgradable."
    fi

    holds=$(apt-mark showhold 2>&1 || true)
    echo
    echo "--- APT PACKAGE HOLDS ---"
    if [[ -n "${holds//[[:space:]]/}" ]]; then
        while IFS= read -r line; do
            [[ -n "$line" ]] && red "HELD: $line"
        done <<< "$holds"
    else
        green "No APT package holds reported."
    fi

    normal_sim=$(sudo apt-get -s upgrade 2>&1 || true)
    phased_names=$(awk '
        index($0, "The following upgrades have been deferred due to phasing:") { active=1; next }
        active && (/^The following / || /^[[:space:]]*$/) { exit }
        active { for (i=1; i<=NF; i++) print $i }
    ' <<< "$normal_sim")
    kept_names=$(awk '
        index($0, "The following packages have been kept back:") { active=1; next }
        active && (/^The following / || /^[[:space:]]*$/) { exit }
        active { for (i=1; i<=NF; i++) print $i }
    ' <<< "$normal_sim")

    echo
    echo "--- CLASSIFIED APT CANDIDATES ---"
    if (( apt_list_rc == 0 )); then
        while IFS=$'\t' read -r pkg arch candidate installed; do
            [[ -z "$pkg" ]] && continue
            key="${pkg%%:*}"
            reason=""
            if grep -Fxq "$pkg" <<< "$holds" || grep -Fxq "$key" <<< "$holds"; then
                reason+="HELD by apt-mark; "
            fi
            if grep -Fxq "$pkg" <<< "$phased_names" || grep -Fxq "$key" <<< "$phased_names"; then
                reason+="DEFERRED due to APT phasing; "
            fi
            if grep -Fxq "$pkg" <<< "$kept_names" || grep -Fxq "$key" <<< "$kept_names"; then
                reason+="KEPT BACK by normal apt-get upgrade; "
            fi
            if grep -Eq "^Inst ${pkg}([[:space:]]|$)" <<< "$normal_sim"; then
                reason+="included in normal-upgrade simulation; verify actual transaction; "
            fi
            [[ -n "$reason" ]] || reason="Reason undetermined from available APT output."
            printf '%s  %s (installed: %s; candidate: %s) — %s%s\n' "$RED" "$pkg" "${installed:-unknown}" "${candidate:-unknown}" "$reason" "$RESET"
        done < <(awk '
            NR == 1 { next }
            $1 ~ /\// {
                pkg=$1; sub(/\/.*/, "", pkg)
                candidate=$2; arch=$3; installed=""
                if (match($0, /\[upgradable from: [^]]+\]/)) {
                    installed=substr($0, RSTART, RLENGTH)
                    sub(/^\[upgradable from: /, "", installed)
                    sub(/\]$/, "", installed)
                }
                printf "%s\t%s\t%s\t%s\n", pkg, arch, candidate, installed
            }
        ' <<< "$apt_list")
    fi

    echo
    echo "--- NORMAL apt-get upgrade SIMULATION / REASONS ---"
    printf '%s\n' "$normal_sim"

    full_sim=$(sudo apt-get -s full-upgrade 2>&1 || true)
    echo
    echo "--- full-upgrade SIMULATION ONLY — NOT EXECUTED ---"
    full_inst=$(awk '/^Inst / { print }' <<< "$full_sim")
    if [[ -n "$full_inst" ]]; then
        while IFS= read -r line; do
            red "$line"
        done <<< "$full_inst"
    else
        printf '%s\n' "$full_sim"
    fi

    echo
    echo "--- FLATPAK UPDATES STILL PENDING ---"
    if command -v flatpak >/dev/null 2>&1; then
        flatpak_updates=$(flatpak remote-ls --updates 2>&1)
        flatpak_rc=$?
        if (( flatpak_rc != 0 )); then
            yellow "Could not determine pending Flatpak updates (exit $flatpak_rc):"
            printf '%s\\n' "$flatpak_updates"
        elif [[ -n "${flatpak_updates//[[:space:]]/}" ]]; then
            while IFS= read -r line; do
                [[ -n "$line" ]] && red "$line"
            done <<< "$flatpak_updates"
        else
            green "No Flatpak updates reported."
        fi
    else
        yellow "Flatpak command unavailable; pending Flatpak updates were not checked."
    fi

    echo
    echo "APT normal-upgrade output distinguishes phased updates and packages kept back."
    echo "APT holds are listed separately. The full-upgrade simulation is diagnostic only."
    echo "No full-upgrade transaction or pending kernel installation is performed by this report."
    echo "SecureUpdate exit status before final reporting: $original_status"
    echo "Report file: $REPORT"
}

trap 'secureupdate_final_report "$?"' EXIT

# ---------- SYSTEM MAINTENANCE ----------
if [[ $# -gt 0 && "${1:-}" != "--report-only" ]]; then
    echo "Usage: $0 [--report-only]"
    exit 2
fi

if [[ "${1:-}" == "--report-only" ]]; then
    echo "SECUREUPDATE REPORT-ONLY MODE — no package or driver changes will be made."
    echo "APT metadata is not refreshed; current cached package lists are used."
    nvidia_check "REPORT ONLY" || exit 1
    exit 0
fi

nvidia_check "BEFORE UPDATE" &&
sudo apt-get update &&
sudo apt-get upgrade &&
nvidia_check "AFTER APT UPGRADE" &&
flatpak update &&
{
    echo
    echo "========== APT AUTOREMOVE PREVIEW =========="

    preview=$(sudo apt-get autoremove --dry-run 2>&1) || {
        echo "$preview"
        exit 1
    }

    echo "$preview"

    if grep -qE '^[0-9]+ upgraded, [0-9]+ newly installed, [1-9][0-9]* to remove' <<< "$preview"; then
        echo
        read -r -p "Review the list above. Proceed with autoremove? [y/N] " answer

        if [[ "$answer" =~ ^[Yy]$ ]]; then
            sudo apt-get autoremove && sudo apt-get autoclean
        else
            echo "Removal skipped; autoclean skipped."
        fi
    else
        echo "No packages proposed for removal. Skipping confirmation."
        sudo apt-get autoclean
    fi
}
