#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
set -Eeuo pipefail
[[ ${EUID:-$(id -u)} -eq 0 ]] || { echo 'Als root ausführen.' >&2; exit 1; }
command -v qm >/dev/null && command -v pct >/dev/null && command -v pvesm >/dev/null || { echo 'Nur auf Proxmox VE installieren.' >&2; exit 1; }
base=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
for dep in bash stty tput awk sed grep; do command -v "$dep" >/dev/null || { echo "Fehlende Abhängigkeit: $dep" >&2; exit 1; }; done
bash -n "$base/bin/pve-vm2lxc" "$base/lib/tui.sh" "$base/lib/legacy-planner.sh" "$base/lib/engine.sh" "$base/lib/guest-ipv4-method.sh" "$base/lib/profiles.sh" "$base/lib/hardware.sh" "$base/lib/task-monitor.sh" "$base/lib/guest-config.sh"
install -d -m 0755 /opt/pve-vm2lxc/bin /opt/pve-vm2lxc/lib /usr/local/bin
install -m 0644 "$base/VERSION" /opt/pve-vm2lxc/VERSION
install -m 0644 "$base/lib/profiles.sh" /opt/pve-vm2lxc/lib/profiles.sh
install -m 0644 "$base/lib/hardware.sh" /opt/pve-vm2lxc/lib/hardware.sh
install -m 0644 "$base/lib/task-monitor.sh" /opt/pve-vm2lxc/lib/task-monitor.sh
install -m 0644 "$base/lib/guest-config.sh" /opt/pve-vm2lxc/lib/guest-config.sh
install -d -m 0700 /opt/pve-vm2lxc/profiles /opt/pve-vm2lxc/logs
install -m 0644 "$base/lib/engine.sh" /opt/pve-vm2lxc/lib/engine.sh
install -m 0644 "$base/lib/owner-restore.sh" /opt/pve-vm2lxc/lib/owner-restore.sh
# Remove only our obsolete Python helper from earlier releases.
rm -f /opt/pve-vm2lxc/lib/owner-restore.py
install -m 0644 "$base/lib/guest-ipv4-method.sh" /opt/pve-vm2lxc/lib/guest-ipv4-method.sh
install -m 0644 "$base/lib/tui.sh" /opt/pve-vm2lxc/lib/tui.sh
install -m 0644 "$base/lib/legacy-planner.sh" /opt/pve-vm2lxc/lib/legacy-planner.sh
# Keep the bin/ and lib/ layout together under /opt/pve-vm2lxc.
install -m 0755 "$base/bin/pve-vm2lxc" /opt/pve-vm2lxc/bin/pve-vm2lxc
cat > /usr/local/bin/pve-vm2lxc <<'LAUNCHER'
#!/usr/bin/env bash
exec /opt/pve-vm2lxc/bin/pve-vm2lxc "$@"
LAUNCHER
chmod 755 /usr/local/bin/pve-vm2lxc
printf 'Installiert: pve-vm2lxc v1.0.0 (TUI + Offline-Migrationsmotor)\n'
