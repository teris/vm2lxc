#!/usr/bin/env bash
set -Eeuo pipefail
source "$(cd "$(dirname "$0")/.." && pwd)/lib/tui.sh"
raw='net1: virtio=BC:24:11:44:FA:E5,bridge=manage,tag=77,mtu=1400'
for language in de en; do
  UI_LANG=$language
  detail=$(ui_network_detail 1 "$raw" 'BC:24:11:44:FA:E5' '10.77.0.112/24' '')
  [[ $(printf '%s\n' "$detail" | wc -l) -eq 7 ]]
  grep -q 'MAC: BC:24:11:44:FA:E5' <<< "$detail"
  grep -q 'Bridge: manage' <<< "$detail"
  grep -q 'IP/CIDR: 10.77.0.112/24' <<< "$detail"
  grep -q 'VLAN: 77' <<< "$detail"
  grep -q 'MTU: 1400' <<< "$detail"
  [[ $(ui_wizard_detail_lines "$detail") -eq 7 ]]
done
printf 'network layout: OK\n'
