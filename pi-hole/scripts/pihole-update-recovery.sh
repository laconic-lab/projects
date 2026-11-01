#!/usr/bin/env bash
#
# Pi-hole recovery after a SteamOS update
# Target: Steam Deck / SteamOS / rootless Podman
#
# Repairs/checks:
#   1. Host sysctl needed for rootless Podman/pasta to bind DNS port 53.
#   2. Persistent firewalld rules allowing DNS from the home IPv4 LAN only.
#   3. Existing Pi-hole systemd service and existing container state.
#
# Safety:
# - Run as the normal "deck" user, NOT with sudo before the script.
# - Does not recreate/remove containers.
# - Does not modify Pi-hole configuration, DNS upstreams, or data.
# - Does not change directory ownership or update Gravity.
# - Firewall access is restricted to 192.168.1.0/24, TCP+UDP port 53.
#
# If the firewall setup differs after a future update, this script stops
# rather than guessing which firewall backend or zone should be changed.

set -u

SYSCTL_FILE="/etc/sysctl.d/99-pihole.conf"
SYSCTL_KEY="net.ipv4.ip_unprivileged_port_start"
EXPECTED_VALUE="53"

SERVICE="pihole.service"
CONTAINER="pihole"

FIREWALL_ZONE="public"
LAN_CIDR="192.168.1.0/24"
DNS_UDP_RULE="rule family=\"ipv4\" source address=\"${LAN_CIDR}\" port port=\"53\" protocol=\"udp\" accept"
DNS_TCP_RULE="rule family=\"ipv4\" source address=\"${LAN_CIDR}\" port port=\"53\" protocol=\"tcp\" accept"

echo "========================================"
echo " Pi-hole SteamOS recovery"
echo "========================================"

# 1. Confirm the existing container is present.
if ! podman container exists "$CONTAINER"; then
    echo "ERROR: Existing container '$CONTAINER' was not found."
    echo "No container changes made."
    exit 1
fi

# 2. Restore/check the persistent sysctl configuration.
if ! sudo test -f "$SYSCTL_FILE" ||
   ! sudo grep -Eq \
   '^[[:space:]]*net\.ipv4\.ip_unprivileged_port_start[[:space:]]*=[[:space:]]*53([[:space:]]*(#.*)?)?$' \
   "$SYSCTL_FILE"; then
    echo "Creating/restoring $SYSCTL_FILE"
    if ! printf '%s\n' \
        'net.ipv4.ip_unprivileged_port_start=53' |
        sudo tee "$SYSCTL_FILE" >/dev/null; then
        echo "ERROR: Could not write the sysctl configuration."
        exit 1
    fi
else
    echo "Persistent sysctl configuration is already correct."
fi

# 3. Apply and verify only the required active sysctl setting.
CURRENT_VALUE="$(sysctl -n "$SYSCTL_KEY" 2>/dev/null || true)"
if [[ "$CURRENT_VALUE" != "$EXPECTED_VALUE" ]]; then
    echo "Current sysctl value: ${CURRENT_VALUE:-unknown}"
    echo "Applying $SYSCTL_KEY=$EXPECTED_VALUE"
    if ! sudo sysctl -w "$SYSCTL_KEY=$EXPECTED_VALUE"; then
        echo "ERROR: Could not apply the sysctl setting."
        exit 1
    fi
else
    echo "Active sysctl value is already correct: $CURRENT_VALUE"
fi

CURRENT_VALUE="$(sysctl -n "$SYSCTL_KEY" 2>/dev/null || true)"
if [[ "$CURRENT_VALUE" != "$EXPECTED_VALUE" ]]; then
    echo "ERROR: Sysctl verification failed; expected value 53."
    exit 1
fi
echo "Verified: $SYSCTL_KEY = $EXPECTED_VALUE"

# 4. Ensure the expected firewalld setup exists before changing firewall rules.
if ! command -v firewall-cmd >/dev/null 2>&1; then
    echo "ERROR: firewall-cmd is not installed."
    echo "No firewall rules were changed; investigate the active firewall first."
    exit 1
fi

if ! firewall-cmd --state >/dev/null 2>&1; then
    echo "ERROR: firewalld is not running."
    echo "No firewall rules were changed; investigate the active firewall first."
    exit 1
fi

if ! firewall-cmd --get-active-zones |
     grep -Eq "^${FIREWALL_ZONE}([[:space:]]|$)"; then
    echo "ERROR: Zone '$FIREWALL_ZONE' is not active."
    echo "No firewall rules were changed; inspect firewalld zones first."
    exit 1
fi

echo "Checking persistent LAN-only DNS firewall rules..."


if sudo firewall-cmd --permanent --zone="$FIREWALL_ZONE" \
     --query-rich-rule="$DNS_UDP_RULE" >/dev/null 2>&1; then
    echo "Persistent UDP/53 LAN rule already exists."
else
    echo "Adding persistent UDP/53 rule for $LAN_CIDR..."
    if ! sudo firewall-cmd --permanent --zone="$FIREWALL_ZONE" \
         --add-rich-rule="$DNS_UDP_RULE"; then
        echo "ERROR: Could not add the persistent UDP/53 firewall rule."
        exit 1
    fi
fi

if sudo firewall-cmd --permanent --zone="$FIREWALL_ZONE" \
     --query-rich-rule="$DNS_TCP_RULE" >/dev/null 2>&1; then
    echo "Persistent TCP/53 LAN rule already exists."
else
    echo "Adding persistent TCP/53 rule for $LAN_CIDR..."
    if ! sudo firewall-cmd --permanent --zone="$FIREWALL_ZONE" \
         --add-rich-rule="$DNS_TCP_RULE"; then
        echo "ERROR: Could not add the persistent TCP/53 firewall rule."
        exit 1
    fi
fi

# Reload once so permanent rules are reflected in the active runtime rules.
# Reload is safe here: it applies firewalld's saved configuration; it does not
# disable the firewall or open DNS to arbitrary source addresses.
echo "Reloading firewalld to apply the persistent configuration..."
if ! sudo firewall-cmd --reload; then
    echo "ERROR: firewalld reload failed."
    exit 1
fi

# 5. Verify both rules in the active runtime configuration.
if ! sudo firewall-cmd --zone="$FIREWALL_ZONE" \
     --query-rich-rule="$DNS_UDP_RULE" >/dev/null 2>&1; then
    echo "ERROR: UDP/53 rule is not active after reload."
    exit 1
fi

if ! sudo firewall-cmd --zone="$FIREWALL_ZONE" \
     --query-rich-rule="$DNS_TCP_RULE" >/dev/null 2>&1; then
    echo "ERROR: TCP/53 rule is not active after reload."
    exit 1
fi

echo "Verified: LAN-only UDP and TCP DNS rules are active."
sudo firewall-cmd --zone="$FIREWALL_ZONE" --list-rich-rules

# 6. Check service autostart; report, do not silently enable it.
if systemctl --user is-enabled --quiet "$SERVICE"; then
    echo "$SERVICE is enabled."
else
    echo "WARNING: $SERVICE is not enabled."
    echo "Automatic startup may need separate investigation."
fi

# 7. Start the existing container only if it is stopped.
if [[ "$(podman inspect --format '{{.State.Running}}' \
    "$CONTAINER" 2>/dev/null || true)" == "true" ]]; then
    echo "Pi-hole container is already running; no restart needed."
elif systemctl --user is-active --quiet "$SERVICE"; then
    # With Type=oneshot and RemainAfterExit=yes, the unit can remain active
    # while the container is stopped. Start the existing container directly.
    echo "Service reports active, but container is stopped."
    echo "Starting the existing container..."
    if ! podman start "$CONTAINER"; then
        echo "ERROR: Container start failed."
        echo "Inspect the service and container logs."
        exit 1
    fi
else
    echo "Starting the existing Pi-hole service..."
    if ! systemctl --user start "$SERVICE"; then
        echo "ERROR: Service start failed."
        echo "Check: systemctl --user status $SERVICE --no-pager"
        exit 1
    fi
fi

# 8. Verify the container reaches the running state.
RUNNING="false"
for attempt in {1..15}; do
    RUNNING="$(podman inspect --format '{{.State.Running}}' \
        "$CONTAINER" 2>/dev/null || true)"
    [[ "$RUNNING" == "true" ]] && break
    sleep 1
done

if [[ "$RUNNING" != "true" ]]; then
    echo "ERROR: Pi-hole did not reach the running state."
    echo
    systemctl --user status "$SERVICE" --no-pager || true
    podman ps -a --filter "name=^${CONTAINER}$"
    exit 1
fi

echo
echo "SUCCESS: Existing Pi-hole container is running."
podman ps --filter "name=^${CONTAINER}$"
echo
echo "Check the admin page and Query Log:"
echo "http://192.168.1.161:8080/admin"
echo
echo "From a Windows client, test DNS with:"
echo "nslookup doubleclick.net 192.168.1.161"
echo
echo "Recovery checks completed."
