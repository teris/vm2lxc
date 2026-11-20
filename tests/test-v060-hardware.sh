#!/usr/bin/env bash
set -Eeuo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
source "$root/lib/hardware.sh"
source "$root/lib/engine.sh"
# jq inventory and defaults
config=$'cores: 3\nsockets: 2\nmemory: 6144\nballoon: 2048\ncpulimit: 3\ncpuunits: 200\nusb0: host=1-2\nhostpci0: 0000:01:00'
hw_source_resources "$config"
[[ $HW_SOURCE_CORES == 6 && $HW_SOURCE_MEMORY == 6144 && $HW_SOURCE_BALLOON == 2048 ]]
[[ $HW_SOURCE_PASSTHROUGH == *usb0* && $HW_SOURCE_PASSTHROUGH == *hostpci0* ]]
output=$(hw_inventory_json "$config")
jq -e '.source.cores == 6 and .source.memory_mib == 6144 and (.passthrough_devices|length)==2' <<< "$output" >/dev/null
# Source defaults and overrides, without invoking Proxmox or touching guests.
qm(){ if [[ $1 == config ]]; then printf '%s\n' "$config"; else return 2; fi; }
VMID=102; HW_CORES=4; HW_MEMORY=4096; HW_SWAP=512; HW_CPULIMIT=''; HW_CPUUNITS=''
# Inspect fail-safe passthrough refusal in a subshell; engine_die exits.
if (engine_hardware >/dev/null 2>&1); then echo 'ERROR: passthrough silently accepted' >&2; exit 1; fi
config=$'cores: 3\nsockets: 2\nmemory: 6144\ncpulimit: 3\ncpuunits: 200'
engine_hardware >/dev/null
[[ $HW_CORES == 4 && $HW_MEMORY == 4096 && $HW_SWAP == 512 ]]
[[ $HW_CPULIMIT == 3 && $HW_CPUUNITS == 200 ]]
# Create a profile with inventory, test old profiles compatibility via existing suite.
source "$root/lib/profiles.sh"
ROOT_DIR=$(mktemp -d)
trap 'rm -rf "$ROOT_DIR"' EXIT
PVE_VM2LXC_HW_JSON=$(hw_inventory_json "$config")
file=$(profile_save 102 117 store02 80 /tmp plan false --cores 4 --memory 4096 --swap 512)
jq -e '.hardware_inventory.source.cores==6 and .engine_options[0]=="--cores"' "$file" >/dev/null
unset PVE_VM2LXC_HW_JSON
file2=$(profile_save 102 118 store02 80 /tmp plan false --cores 6)
jq -e '.hardware_inventory=={}' "$file2" >/dev/null
printf 'PASS hardware inventory, overrides, passthrough rejection, profile persistence\n'
