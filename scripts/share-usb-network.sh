#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# Give a Coralboard SL internet access through this Linux host's USB link.
#
# The board's USB-C exposes an NCM network interface. On the board it is
# `usb0`; on the host it shows up as `enx<mac>`, and NetworkManager leaves it
# stuck at "connecting (getting IP configuration)" because nothing on that link
# serves DHCP. This script:
#
#   1. Host:  activates an in-memory NetworkManager profile in "shared" mode
#             (host becomes 10.42.0.1, runs DHCP + NAT). The profile is never
#             written to disk, does not autoconnect, and is gone after a reboot.
#             Re-run this script after replugging the board.
#   2. Board: over ADB, requests a lease on usb0 and restarts time sync. The
#             board has no RTC and boots with a stale clock, which breaks
#             HTTPS (`certificate is not yet valid`) until NTP runs.
#
# Usage:  scripts/share-usb-network.sh [host-interface]
#
# Requires: nmcli (NetworkManager), adb, sudo. Only nmcli runs through sudo, so
# adb keeps using your user's authorized keys.

set -euo pipefail

die() { echo "error: $*" >&2; exit 1; }

command -v nmcli >/dev/null || die "nmcli not found (this script needs NetworkManager)"
command -v adb   >/dev/null || die "adb not found; install it with: sudo apt install adb"

# --- Find the board's interface on the host ---------------------------------
iface="${1:-}"
if [[ -z "$iface" ]]; then
    candidates=()
    for dev in /sys/class/net/*; do
        drv="$(basename "$(readlink -f "$dev/device/driver" 2>/dev/null)" 2>/dev/null || true)"
        [[ "$drv" == "cdc_ncm" ]] && candidates+=("$(basename "$dev")")
    done
    case "${#candidates[@]}" in
        0) die "no USB NCM interface found. Is the board booted (red heartbeat LED) and on a data cable?" ;;
        1) iface="${candidates[0]}" ;;
        *) die "several USB NCM interfaces found (${candidates[*]}); pass the right one as an argument" ;;
    esac
fi
[[ -e "/sys/class/net/$iface" ]] || die "interface '$iface' does not exist"

echo "==> Host: sharing network on $iface"
# `nmcli device modify` only works on an active connection, and this device
# spends most of its time disconnected between failed DHCP attempts, so bring
# up a dedicated profile instead.
profile="coral-usb-share"
nm() { if (( EUID == 0 )); then nmcli "$@"; else sudo nmcli "$@"; fi; }

if nm -g NAME connection show | grep -Fxq "$profile"; then
    nm connection delete "$profile" >/dev/null
fi
nm connection add save no type ethernet ifname "$iface" con-name "$profile" \
    autoconnect no ipv4.method shared ipv6.method ignore >/dev/null
nm connection up "$profile" >/dev/null

for _ in $(seq 1 10); do
    ip -4 addr show "$iface" | grep -q 'inet ' && break
    sleep 1
done
ip -4 addr show "$iface" | grep -q 'inet ' || die "$iface did not get an address in shared mode"
ip -4 -o addr show "$iface" | awk '{print "    host address: " $4}'

# --- Board side ---------------------------------------------------------------
echo "==> Board: waiting for ADB"
adb wait-for-device

echo "==> Board: requesting a DHCP lease on usb0"
host_ip="$(ip -4 -o addr show "$iface" | awk '{split($4, a, "/"); print a[1]; exit}')"
if ! lease_output="$(adb shell 'udhcpc -i usb0 -n -q' 2>&1)"; then
    echo "$lease_output" | sed 's/^/    /' >&2
    die "board got no DHCP lease from $host_ip. Check the host firewall: sudo ufw status verbose"
fi
echo "$lease_output" | tr -d '\r' | grep -E 'lease|fail' | sed 's/^/    /' || true
adb shell ip route | tr -d '\r' | grep -q "^default via $host_ip " \
    || die "board has no default route via $host_ip after DHCP"

echo "==> Board: syncing the clock"
adb shell 'systemctl restart systemd-timesyncd'
max_drift=60
synced=false
for _ in $(seq 1 30); do
    board_epoch="$(adb shell date +%s | tr -d '\r')"
    drift=$(( $(date +%s) - ${board_epoch:-0} ))
    if (( drift < max_drift && drift > -max_drift )); then
        synced=true
        break
    fi
    sleep 1
done
echo "    board time: $(adb shell date | tr -d '\r')"
$synced || die "board clock is still ${drift}s off the host. NTP may be blocked (sudo iptables -S FORWARD)"

echo "==> Board: checking internet"
if adb shell 'ping -c1 -W3 github.com >/dev/null 2>&1'; then
    echo "    online"
else
    die "board cannot reach github.com"
fi
