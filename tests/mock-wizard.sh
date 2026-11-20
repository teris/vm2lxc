#!/usr/bin/env bash
# Integration-style TUI test with mocked Proxmox responses. No VM touched.
set -Eeuo pipefail
source "$(cd "$(dirname "$0")/.." && pwd)/lib/tui.sh"
qm() {
 case "${1:-} ${2:-}" in
  'list ') printf 'VMID NAME STATUS MEM(MB) BOOTDISK(GB) PID\n105 TestServer stopped 2048 80 0\n';;
  'config 105') cat <<'CFG'
name: TestServer
ostype: l26
memory: 2048
onboot: 0
net0: virtio=02:00:00:11:22:33,bridge=vmbr0
net1: virtio=BC:24:11:AA:BB:CC,bridge=manage
scsi0: store02:105/vm-105-disk-0.qcow2,size=80G
CFG
  ;;
  *) return 1;;
 esac
}
pct() { return 1; }
pvesh() { echo 122; }
pvesm() {
 case "${1:-} ${2:-} ${3:-}" in
  'status --content rootdir') printf '%s\n' 'Name Type Status Total(KiB) Used(KiB) Available(KiB) %' 'store02 dir active 104857600 10485760 94371840 10%' ;;
  'status  ') printf '%s\n' 'Name Type Status Total(KiB) Used(KiB) Available(KiB) %' 'store02 dir active 104857600 10485760 94371840 10%' 'backup dir active 104857600 10485760 94371840 10%' ;;
  *) return 1;;
 esac
}
ui_guest_network_qga() {
 UI_QGA_JSON='[{"name":"ens18","hardware-address":"02:00:00:11:22:33","ip-addresses":[{"ip-address-type":"ipv4","ip-address":"10.20.30.40","prefix":24}]},{"name":"ens19","hardware-address":"bc:24:11:aa:bb:cc","ip-addresses":[{"ip-address-type":"ipv4","ip-address":"10.78.0.105","prefix":24}]}]'
}
ui_guest_route_qga() { return 1; }
engine_main() { printf '[MOCK_ENGINE] %q ' "$@"; printf '\n'; }
tui_main
