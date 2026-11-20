#!/usr/bin/env bash
set -Eeuo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
source "$root/lib/hardware.sh"
cfg=$'serial0: socket\nusb0: host=1-2\nhostpci0: 0000:01:00'
[[ $(hw_device_class 'serial0: socket') == virtual-console ]]
[[ $(hw_device_class 'serial0: /dev/ttyS0') == host-device ]]
declare -A sk=() mp=()
if hw_validate_decisions "$cfg" sk mp 2>/dev/null; then echo 'Missing explicit decisions accepted' >&2; exit 1; fi
sk[usb0]=1
if hw_validate_decisions "$cfg" sk mp 2>/dev/null; then echo 'Incomplete decisions accepted' >&2; exit 1; fi
sk[hostpci0]=1
hw_validate_decisions "$cfg" sk mp
cfg=$'serial0: socket\nserial1: socket'
hw_validate_decisions "$cfg" sk mp
cfg=$'usb0: host=1-2'
mp[usb0]=/dev/null
unset 'sk[usb0]'
hw_validate_decisions "$cfg" sk mp
mp[usb0]='/dev/does-not-exist'
if hw_validate_decisions "$cfg" sk mp 2>/dev/null; then echo 'Missing host node accepted' >&2; exit 1; fi
printf 'PASS: console ignored; other devices require explicit decisions; host node checked\n'
