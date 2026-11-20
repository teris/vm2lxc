#!/usr/bin/env bash
set -Eeuo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
source "$root/lib/tui.sh"
source "$root/lib/profiles.sh"
source "$root/lib/hardware.sh"
tmp=$(mktemp -d); trap 'rm -rf -- "$tmp"' EXIT
export PVE_VM2LXC_PROFILES="$tmp/profiles"
ROOT_DIR="$root" UI_VM=117 UI_LANG=de UI_TARGET_CTID=118
# Execute the actual final step of the wizard in isolation with no Proxmox calls.
fn=$(sed -n '/^ local profile_path=\x27\x27 delete_intent=false hardware_json=/,/^ return 0$/p' "$root/lib/tui.sh")
[[ $fn == *'ui_engine_monitor'* ]] || exit 51
eval "wizard_tail() { local profile_path='' delete_intent=false hardware_json='' save_error=''; ${fn#*$'\n'}; }"
ui_wizard_checkpoint() { :; }
ui_wizard_frame() { :; }
ui_put() { :; }
ui_wizard_choice() { case "$1" in *'Quell-VM'*) UI_PICK=keep;; *) UI_PICK=go;; esac; return 0; }
ui_engine_monitor() { printf '%s\n' "$@" > "$tmp/engine-args"; }
ui_wizard_notice() { echo "Unexpected wizard notice: $*" >&2; exit 23; }
ui_t() { printf '%s' "$1"; }
# No network/routing snapshot is allowed after source-retention selection.
ui_routing_snapshot() { echo 'Unexpected guest query' >&2; exit 24; }
ctid=118 storage=store02 size=10 archive=/mnt/pve/store02 mode=convert cfg='cores: 2
memory: 2048' params=(--shutdown --ip-net0 192.0.2.3/24) nets=('net0')
wizard_tail
[[ -s $tmp/engine-args ]] || exit 25
grep -qx 'convert' "$tmp/engine-args"
grep -qx -- '--ip-net0' "$tmp/engine-args"
# A failed profile save must not prevent explicit direct execution.
profile_save() { return 1; }
: > "$tmp/engine-args"
wizard_tail
[[ -s $tmp/engine-args ]] || exit 26
echo 'PASS: source retention -> summary -> execute; failed profile save cannot abort; no QGA snapshot'
