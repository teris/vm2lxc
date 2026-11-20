#!/usr/bin/env bash
set -euo pipefail
engine=$(cd -- "$(dirname -- "$0")/.." && pwd)/lib/engine.sh
bash -n "$engine"
restore_line=$(grep -n 'engine_staging_restore "\$rootfs"' "$engine" | tail -1 | cut -d: -f1)
unmount_line=$(grep -n 'engine_release_guest_mount || engine_die' "$engine" | tail -1 | cut -d: -f1)
network_line=$(grep -n 'engine_pve_worker pct set "\$CTID" "\${NET_ARGS\[i\]}"' "$engine" | tail -1 | cut -d: -f1)
((restore_line < unmount_line && unmount_line < network_line))
# The cleanup function must use mount-table checks and not delete CT resources.
grep -q 'guestunmount --retry=2' "$engine"
grep -q 'findmnt -rn --mountpoint' "$engine"
! sed -n '/^engine_temp_cleanup()/,/^# Build a tiny/p' "$engine" | grep -Eq 'pct destroy|qm stop|rm -rf.*guest-'
echo 'PASS restore order and run-owned cleanup lifecycle'
