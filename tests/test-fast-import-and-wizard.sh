#!/usr/bin/env bash
set -Eeuo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
engine="$root/lib/engine.sh"
tui="$root/lib/tui.sh"
# The costly original scanning, per-file restoration and verification must not
# execute in the default conversion path.
body=$(sed -n '/^engine_staging_restore() {/,/^# Run Proxmox worker/p' "$engine")
! grep -Eq 'owner_restore (scan|apply|verify)' <<< "$body"
grep -Fq 'phase=extract' <<< "$body"
grep -Fq 'phase=owner_baseline' <<< "$body"
grep -Fq 'chown -R -h --' <<< "$body"
grep -Fq '[[ -z $OWNER_MAP_FILE ]] || engine_die' <<< "$body"
# The complete archive must be preserved; network is configured only after restore.
python_check=0
restore_line=$(grep -n 'engine_staging_restore "$rootfs"' "$engine" | head -1 | cut -d: -f1)
net_line=$(grep -n 'engine_pve_worker pct set "$CTID" "${NET_ARGS\[i\]}"' "$engine" | head -1 | cut -d: -f1)
[[ "$restore_line" -lt "$net_line" ]]
grep -Fq 'ui_engine_monitor "$mode" "$ctid" "$storage" "$size" "$archive" "${params[@]}"' "$tui"
! grep -Fq 'ui_start_saved_profile "$(basename -- "$profile_path")"' "$tui"
! grep -Fq 'ui_wizard_choice "$(ui_t '''Dateieigentümer''' ' "$tui"
echo 'PASS: fast staging import, mapped baseline, network ordering and direct wizard start'
