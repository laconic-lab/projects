#!/usr/bin/env bash
# READ-ONLY NVIDIA diagnostic. Writes a report only; does not change system state.
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
REPORT_DIR="$PROJECT_DIR/reports"
mkdir -p "$REPORT_DIR"
STAMP="$(date +%Y%m%d-%H%M%S)"
REPORT="$REPORT_DIR/nvidia-diagnostic-$STAMP.txt"
run() { printf '\n$'; printf ' %q' "$@"; printf '\n'; "$@" 2>&1 || echo "[exit: $?]"; }
{
echo "NVIDIA DIAGNOSTIC — READ ONLY"
date --iso-8601=seconds 2>/dev/null || date
echo "Host: $(hostname)"
echo "User: $(id -un)"
echo
echo "=== OS ==="; cat /etc/os-release 2>/dev/null || true
echo; echo "=== KERNEL ==="; run uname -a
echo "=== PCI / GPU ==="; if command -v lspci >/dev/null; then lspci -nnk | grep -A4 -i -E 'VGA|3D|Display|NVIDIA'; else echo "lspci unavailable"; fi
echo; echo "=== ACTIVE NVIDIA MODULE ==="
cat /proc/driver/nvidia/version 2>&1 || true
command -v modinfo >/dev/null && { run modinfo -F version nvidia; run modinfo -n nvidia; }
command -v nvidia-smi >/dev/null && run nvidia-smi || true
echo; echo "=== DKMS ==="; command -v dkms >/dev/null && run dkms status || true
echo; echo "=== NVIDIA APT PACKAGES ==="
dpkg-query -W -f='${db:Status-Abbrev} ${binary:Package} ${Version}\n' 2>/dev/null | grep -Ei 'nvidia|libnvidia' || true
echo; echo "=== APT HOLDS ==="; apt-mark showhold 2>&1 || true
echo; echo "=== KERNEL COMMAND LINE ==="; cat /proc/cmdline 2>/dev/null || true
echo; echo "=== INSTALLER / SOURCE PATHS ==="
for p in /var/lib/nvidia /usr/src/nvidia-470.256.02 /usr/bin/nvidia-uninstall; do
  if [ -e "$p" ] || [ -L "$p" ]; then ls -ld "$p"; else echo "Missing: $p"; fi
done
if [ -r /var/lib/nvidia/log ]; then sed -n '1,3p' /var/lib/nvidia/log
elif command -v sudo >/dev/null; then echo "Root-only installer DB; requesting read-only header:"; sudo sed -n '1,3p' /var/lib/nvidia/log 2>&1 || true; fi
echo; echo "=== NVIDIA LIBRARY LINKS ==="
D=/usr/lib/x86_64-linux-gnu
for f in libcuda.so libcuda.so.1 libcudadebugger.so.1 libnvidia-ml.so libnvidia-ml.so.1 libnvidia-nvvm.so libnvidia-nvvm.so.4 libnvidia-nvvm70.so.4 libnvidia-opencl.so.1 libnvidia-ptxjitcompiler.so libnvidia-ptxjitcompiler.so.1; do
 p="$D/$f"; echo "--- $p"
 if [ -L "$p" ]; then echo "Link: $(readlink "$p")"; echo "Resolved: $(readlink -e "$p" || echo DANGLING)"
 elif [ -e "$p" ]; then ls -l "$p"; else echo Missing; fi
 dpkg-query -S "$p" 2>&1 || true
done
echo; echo "=== NVIDIA CONFIG PATHS ==="
for p in /etc/modprobe.d /etc/X11/xorg.conf /etc/default/grub; do [ -e "$p" ] && ls -ld "$p" || echo "Missing: $p"; done
find /etc/modprobe.d -maxdepth 1 -type f -iname '*nvidia*' -print 2>/dev/null || true
echo; echo "=== NVIDIA SUSPEND/RESUME SERVICE STATUS ==="
if command -v systemctl >/dev/null; then
 for s in nvidia-suspend.service nvidia-resume.service nvidia-hibernate.service; do
  echo "--- $s"; systemctl is-enabled "$s" 2>&1 || true; systemctl is-active "$s" 2>&1 || true
 done
fi
echo; echo "=== END — NO SYSTEM MODIFICATIONS PERFORMED ==="
} 2>&1 | tee "$REPORT"
chmod 600 "$REPORT"
echo "Report saved: $REPORT"
