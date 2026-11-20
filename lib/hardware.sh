#!/usr/bin/env bash
# Source VM hardware inventory for TUI and JSON profiles. Read-only.
# SPDX-License-Identifier: MIT
hw_get_field() { sed -n "s/^$2: //p" <<< "$1" | head -1; }
hw_source_resources() {
 local cfg=$1 cores sockets memory
 cores=$(hw_get_field "$cfg" cores); sockets=$(hw_get_field "$cfg" sockets)
 memory=$(hw_get_field "$cfg" memory)
 HW_SOURCE_CORES=$(( ${cores:-1} * ${sockets:-1} ))
 HW_SOURCE_MEMORY=${memory:-512}
 HW_SOURCE_CPULIMIT=$(hw_get_field "$cfg" cpulimit)
 HW_SOURCE_CPUUNITS=$(hw_get_field "$cfg" cpuunits)
 HW_SOURCE_BALLOON=$(hw_get_field "$cfg" balloon)
 HW_SOURCE_PASSTHROUGH=$(grep -E '^(usb[0-9]+|hostpci[0-9]+|serial[0-9]+|parallel[0-9]+|args):' <<< "$cfg" || :)
}
hw_inventory_json() {
 local cfg=$1
 hw_source_resources "$cfg"
 jq -n --argjson cores "$HW_SOURCE_CORES" --argjson memory_mib "$HW_SOURCE_MEMORY" \
  --arg balloon_mib "$HW_SOURCE_BALLOON" --arg cpulimit "$HW_SOURCE_CPULIMIT" \
  --arg cpuunits "$HW_SOURCE_CPUUNITS" --arg devices "$HW_SOURCE_PASSTHROUGH" \
  '{source:{cores:$cores,memory_mib:$memory_mib,balloon_mib:$balloon_mib,cpulimit:$cpulimit,cpuunits:$cpuunits}, passthrough_devices:($devices | split("\n") | map(select(length>0))), note:"USB, PCI and serial VM devices are inventoried but cannot be transparently migrated to LXC."}'
}

# Classify QEMU-only console endpoints separately from real host devices.
hw_device_lines() { grep -E '^(usb[0-9]+|hostpci[0-9]+|serial[0-9]+|parallel[0-9]+|args):' <<< "$1" || :; }
hw_device_key() { printf '%s' "${1%%:*}"; }
hw_device_class() {
 local key=${1%%:*} value=${1#*: }; value=${value%%,*}
 case "$key" in
  serial*|parallel*)
   case "$value" in socket|none) printf 'virtual-console';; /dev/*) printf 'host-device';; *) printf 'unsupported';; esac ;;
  usb*|hostpci*) printf 'host-device';;
  args) printf 'custom-qemu';;
  *) printf 'unsupported';;
 esac
}
# Only explicit physical device nodes may be exposed via Proxmox devN.
hw_valid_node() {
 [[ $1 == /dev/* && $1 != *'..'* && ! $1 =~ [[:space:]] ]] && [[ -c $1 || -b $1 ]]
}
# An explicit per-source decision is required for every non-console QEMU device.
hw_validate_decisions() {
 local cfg=$1; shift
 local -n _skip=$1 _map=$2
 local line key class path
 while IFS= read -r line; do
  [[ -n $line ]] || continue
  key=$(hw_device_key "$line"); class=$(hw_device_class "$line")
  [[ $class == virtual-console ]] && continue
  if [[ -v _skip[$key] ]]; then continue; fi
  if [[ -v _map[$key] ]]; then
   path=${_map[$key]}
   hw_valid_node "$path" || { printf 'Device %s: invalid/unavailable host node: %s\n' "$key" "$path" >&2; return 1; }
   continue
  fi
  printf 'Device %s (%s): no explicit skip or mapping decision\n' "$key" "$class" >&2
  return 1
 done < <(hw_device_lines "$cfg")
}
