#!/usr/bin/env bash
set -Eeuo pipefail
BASE=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/guest/etc" "$tmp/work"
printf 'ID=debian\n' > "$tmp/guest/etc/os-release"
printf 'root:x:0:0:root:/root:/bin/bash\n' > "$tmp/guest/etc/passwd"
printf 'root:x:0:\n' > "$tmp/guest/etc/group"
( source "$BASE/lib/engine.sh"
  VMID=999; ENGINE_ROOT="$tmp/work"
  engine_build_seed "$tmp/guest"
  [[ $ENGINE_CT_OS == debian && -s $ENGINE_SEED_ARCHIVE ]]
  tar -tf "$ENGINE_SEED_ARCHIVE" | grep -q '^./etc/os-release$'
  [[ $(stat -c '%s' "$ENGINE_SEED_ARCHIVE") -lt 1048576 ]]
  engine_temp_cleanup
)
echo 'seed archive test passed'
