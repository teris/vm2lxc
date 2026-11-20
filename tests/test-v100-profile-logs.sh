#!/usr/bin/env bash
set -Eeuo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
source "$root/lib/profiles.sh"
rootdir=$(mktemp -d)
trap 'rm -rf "$rootdir"' EXIT
export PVE_VM2LXC_PROFILES="$rootdir/profiles"
mkdir -p "$PVE_VM2LXC_PROFILES"
file=vm-117-ct-118-20261120T153202Z.json
printf '{}' > "$PVE_VM2LXC_PROFILES/$file"
profile_delete "$file"
[[ ! -e $PVE_VM2LXC_PROFILES/$file ]]
printf '{}' > "$PVE_VM2LXC_PROFILES/$file"
if profile_delete '../VERSION'; then exit 1; fi
[[ -e $PVE_VM2LXC_PROFILES/$file ]]
ln -s "$root/VERSION" "$PVE_VM2LXC_PROFILES/vm-117-ct-118-20261120T153203Z.json"
if profile_delete 'vm-117-ct-118-20261120T153203Z.json'; then exit 1; fi
[[ "$(bash "$root/bin/pve-vm2lxc" --version)" == '1.0.0' ]]
grep -q 'ENGINE_LOG_DIR=.*logs' "$root/lib/engine.sh"
if grep -R -q '/var/log/pve-vm2lxc' "$root/lib/"*.sh; then echo 'legacy log path' >&2; exit 1; fi
printf 'PASS: safe profile deletion, version and local log paths\n'
