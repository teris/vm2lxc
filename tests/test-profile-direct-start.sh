#!/usr/bin/env bash
# Regression: direct wizard and saved-profile menu must share exactly one runner.
set -Eeuo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
source "$root/lib/tui.sh"
source "$root/lib/profiles.sh"
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
export PVE_VM2LXC_PROFILES="$tmp"
ROOT_DIR="$root"
profile_save 102 117 store02 80 /mnt/pve/store01 convert true --ip-net0 10.0.0.2/24 --shutdown >/dev/null
file=$(find "$tmp" -maxdepth 1 -name '*.json' -printf '%f\n' | head -1)
[[ -n $file ]]
called="$tmp/called"
ui_engine_monitor() { printf '%s\n' "$@" > "$called"; }
ui_start_saved_profile "$file"
mapfile -t args < "$called"
[[ ${args[0]} == convert && ${args[1]} == 117 && ${args[2]} == store02 && ${args[3]} == 80 ]]
[[ ${args[4]} == /mnt/pve/store01 ]]
count=0
for a in "${args[@]}"; do [[ $a == --shutdown ]] && ((count+=1)) || :; done
[[ $count -eq 1 ]] || { echo "Duplicate/missing shutdown: $count" >&2; exit 1; }
# A broken start must not exit bash, must leave profile available.
ui_engine_monitor() { return 1; }
ui_wizard_notice() { :; }
if ui_start_saved_profile "$file"; then echo 'Expected failure' >&2; exit 1; fi
[[ -f "$tmp/$file" ]]
# Direct wizard execution runs the monitor immediately; profile menu uses same monitor.
grep -Fq 'ui_engine_monitor "$mode" "$ctid" "$storage" "$size" "$archive" "${params[@]}"' "$root/lib/tui.sh"
echo 'PASS: saved profile and direct wizard share migration runner'
