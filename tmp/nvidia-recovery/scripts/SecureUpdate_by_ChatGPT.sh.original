
#!/bin/bash

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

    # Check the currently loaded NVIDIA driver
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

    # Find the newest installed kernel
    latest_kernel=$(find /lib/modules -mindepth 1 -maxdepth 1 \
        -type d -printf '%f\n' | sort -V | tail -n1)

    if [[ -z "$latest_kernel" ]]; then
        red "No installed kernel module directories found."
        return 1
    fi

    echo "Newest installed kernel: $latest_kernel"

    if [[ "$latest_kernel" != "$running_kernel" ]]; then
        yellow "Newest kernel differs from the running kernel."
        yellow "A reboot may be needed after verifying the new kernel."
    fi

    # Check NVIDIA module available for the newest installed kernel
    module_version=$(modinfo -k "$latest_kernel" \
        -F version nvidia 2>/dev/null)

    if [[ "$module_version" != "470.256.02" ]]; then
        red "NVIDIA module for $latest_kernel is ${module_version:-NOT FOUND}."
        red "Expected 470.256.02. STOP MAINTENANCE."
        return 1
    fi

    green "NVIDIA 470.256.02 module verified for $latest_kernel"

    # Verify DKMS registration for that specific kernel
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

# ---------- SYSTEM MAINTENANCE ----------
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

