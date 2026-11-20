#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."
export ROOT_DIR=$PWD PVE_VM2LXC_PROFILES
PVE_VM2LXC_PROFILES=$(mktemp -d)
trap 'rm -rf "$PVE_VM2LXC_PROFILES"' EXIT
source lib/profiles.sh
saved=$(profile_save 102 117 store02 150 /mnt/pve/store02 plan false --ip-net0 192.0.2.5/24 --ip6-net0 2001:db8::5/64)
[[ -f $saved ]]
profile_load "${saved##*/}"
[[ $(jq -r '.engine_options[3]' "$saved") == '2001:db8::5/64' ]]
[[ $(stat -c %a "$saved") == 600 ]]
[[ $(profile_list | wc -l) == 1 ]]
! profile_load '../../etc/passwd'
echo 'PASS saved profiles'
