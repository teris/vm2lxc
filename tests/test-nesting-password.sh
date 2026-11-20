#!/usr/bin/env bash
set -Eeuo pipefail
base=$(cd -- "$(dirname "$0")/.." && pwd)
source "$base/lib/guest-config.sh"
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/etc" "$work/usr/lib/systemd" "$work/var/lib/dpkg"
: > "$work/usr/lib/systemd/systemd"
cat > "$work/var/lib/dpkg/status" <<'STATUS'
Package: bash
Version: 5.2

Package: systemd
Status: install ok installed
Version: 257.9-1~deb13u1

STATUS
gc_systemd_version "$work"
[[ $GC_SYSTEMD_PRESENT == 1 && $GC_SYSTEMD_VERSION == 257 ]]
cat > "$work/etc/shadow" <<'SHADOW'
root:!:19000:0:99999:7:::
daemon:*:19000:0:99999:7:::
SHADOW
h=$(printf '%s\n' 'secure-test-password' | openssl passwd -6 -stdin)
gc_set_root_hash "$work" "$h"
[[ $(sed -n 's/^root:\([^:]*\):.*/\1/p' "$work/etc/shadow") == "$h" ]]
[[ $(sed -n '/^daemon:/p' "$work/etc/shadow") == 'daemon:*:19000:0:99999:7:::' ]]
# Observe only supported PVE interactions without calling a live host.
pct() {
 case $1 in
  config) printf 'features: keyctl=1\n';;
  set) [[ $3 == '--features' && $4 == 'keyctl=1,nesting=1' ]];;
 esac
}
# Test config verification with simulated current state that is updated by pct set.
mockcfg='features: keyctl=1'
pct() {
 if [[ $1 == config ]]; then echo "$mockcfg"; else
  [[ $1 == set && $3 == --features ]] || return 1
  mockcfg="features: $4"
 fi
}
gc_apply_nesting 999 1
[[ $mockcfg == 'features: keyctl=1,nesting=1' ]]
gc_apply_nesting 999 0
[[ $mockcfg == 'features: keyctl=1,nesting=0' ]]
printf '%s\n' 'PASS: systemd detection, shadow update, nesting feature preservation'
