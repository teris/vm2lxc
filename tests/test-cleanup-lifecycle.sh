#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "$0")/.." && pwd)
ROOT="$ROOT" bash <<'BASH'
set -Eeuo pipefail
source "$ROOT/lib/engine.sh"
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
ENGINE_ROOT=$work
ENGINE_LOG="$work/log"
: > "$ENGINE_LOG"
VMID=444
CTID=555
GUEST_MOUNT=$(mktemp -d "$work/guest-444-XXXXXXXX")
CT_STAGING_MOUNTED=0
ENGINE_CT_CREATE_ATTEMPTED=1
ENGINE_MIGRATION_READY=0
ENGINE_CLEANUP_FAILED=0
attempts=0
mounted=1
# Mock the external commands, never touch real Proxmox mounts.
engine_mount_is_active() { [[ $mounted == 1 ]]; }
guestunmount() { ((attempts+=1)); if ((attempts>=2)); then mounted=0; return 0; else return 1; fi; }
pct() { case $1 in config) return 0;;status) echo 'status: stopped';;*) echo "unexpected pct $*" >&2; return 1;; esac; }
engine_pve_worker() { echo 'Unexpected worker during cleanup' >&2; return 1; }
ENGINE_SEED_DIR=''
engine_temp_cleanup 2> "$work/warnings"
[[ $attempts == 2 ]]
[[ ! -d $GUEST_MOUNT ]]
grep -q 'TEILWEISE erstellt' "$work/warnings"
[[ $(grep -c 'guestunmount Versuch' "$work/warnings") -eq 1 ]]
[[ $(grep -c 'Migration/Beendigung' "$work/warnings") -eq 1 ]]
echo 'PASS: run-scoped retry, mount verification and partial-CT warning'
BASH
