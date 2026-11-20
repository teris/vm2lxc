#!/usr/bin/env bash
# Non-destructive mock checks of selectors and guest interface matching.
set -Eeuo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
source "$ROOT/lib/tui.sh"
qm() {
 case "$1 $2" in
  'config 105') cat <<'CFG'
name: test
ostype: l26
memory: 2048
net0: virtio=02:00:00:11:22:33,bridge=vmbr0
net1: virtio=BC:24:11:AA:BB:CC,bridge=manage
scsi0: store02:105/vm-105-disk-0.qcow2,size=80G
CFG
 ;;
  *) return 1;;
 esac
}
pvesh() { echo 122; }
pct() { return 1; }
pvesm() {
 if [[ ${1:-} == status && ${2:-} == --content && ${3:-} == rootdir ]]; then
  printf '%s\n' 'Name Type Status Total(KiB) Used(KiB) Available(KiB) %' \
    'store02 dir active 104857600 10485760 94371840 10%' \
    'oldpool dir inactive 104857600 10485760 94371840 10%'
 elif [[ ${1:-} == status ]]; then
  printf '%s\n' 'Name Type Status Total(KiB) Used(KiB) Available(KiB) %' \
    'store02 dir active 104857600 10485760 94371840 10%' \
    'backup dir active 104857600 10485760 94371840 10%'
 else return 1; fi
}
[[ $(ui_next_ctid) == 122 ]]
ui_storage_options
[[ ${UI_STORAGE_OPTIONS[0]} == store02 && ${#UI_STORAGE_OPTIONS[@]} == 2 ]]
UI_QGA_JSON='[{"name":"ens18","hardware-address":"02:00:00:11:22:33","ip-addresses":[{"ip-address-type":"ipv4","ip-address":"10.20.30.40","prefix":24}]},{"name":"ens19","hardware-address":"bc:24:11:aa:bb:cc","ip-addresses":[{"ip-address-type":"ipv4","ip-address":"10.78.0.105","prefix":24}]}]'
[[ $(ui_guest_net_by_mac 02:00:00:11:22:33 ipv4) == '10.20.30.40/24' ]]
[[ $(ui_guest_net_by_mac BC:24:11:AA:BB:CC ipv4) == '10.78.0.105/24' ]]
[[ $(ui_guest_netname_by_mac BC:24:11:AA:BB:CC) == ens19 ]]
[[ -z $(ui_guest_net_by_mac aa:aa:aa:aa:aa:aa ipv4 || :) ]]
echo 'MOCK CHECKS PASS'
