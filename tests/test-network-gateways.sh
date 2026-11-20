#!/usr/bin/env bash
set -Eeuo pipefail
base=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source "$base/lib/engine.sh"
qm() {
  case "$1" in
    config) cat <<'CONFIG'
net0: virtio=02:00:00:12:94:46,bridge=vmbr0
net1: virtio=BC:24:11:5B:55:31,bridge=manage
CONFIG
      ;;
  esac
}
VMID=102
IP_OVERRIDES=([0]='192.0.2.10/24' [1]='10.78.0.102/24')
GW_OVERRIDES=([0]='192.0.2.1')
engine_net
[[ ${#NET_DESCS[@]} -eq 2 ]]
[[ ${NET_DESCS[0]} == *'gw=192.0.2.1'* ]]
[[ ${NET_DESCS[1]} != *'gw='* ]]
# Must refuse an accidental second default gateway.
GW_OVERRIDES[1]='10.78.0.1'
if (engine_net) >/dev/null 2>&1; then
 echo 'ERROR: accepted two default gateways' >&2; exit 1
fi
printf '%s\n' 'PASS: optional secondary gateway + duplicate gateway guard'
