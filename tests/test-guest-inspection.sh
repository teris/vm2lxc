#!/usr/bin/env bash
# Regression tests for QGA + persistent guestfish OS inspection, no Proxmox needed.
set -Eeuo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin"
cat > "$work/bin/qm" <<'QM'
#!/usr/bin/env bash
case "$*" in
 'status 102') echo "status: ${MOCK_STATUS:-stopped}";;
 'guest cmd 102 get-osinfo') echo '{"id":"alpine","pretty-name":"Alpine Linux 3.22","machine":"x86_64"}' ;;
 *) echo "Unexpected qm $*" >&2; exit 1;;
esac
QM
cat > "$work/bin/guestfish" <<'GF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$MOCK_CALLS"
case "$*" in
 *--listen*) echo 'GUESTFISH_PID=12345; export GUESTFISH_PID';;
 '--remote run') : ;;
 '--remote inspect-os') echo /dev/sda2;;
 '--remote inspect-get-type /dev/sda2') echo "${MOCK_TYPE:-linux}";;
 '--remote exit') : ;;
 *) exit 22;;
esac
GF
for name in guestmount guestunmount virt-filesystems pct pvesm flock; do printf '#!/bin/sh\nexit 0\n' > "$work/bin/$name"; done
chmod +x "$work/bin/"*
export PATH="$work/bin:$PATH" MOCK_CALLS="$work/calls" MOCK_STATUS=stopped
: > "$MOCK_CALLS"
# A successful offline check should make one guestfish handle and never re-run inspect-os in a second process.
bash -c 'source "$1"; VMID=102; DISK_PATHS=(/fake/disk.qcow2); engine_guest_inspect' _ "$root/lib/engine.sh" > "$work/out"
grep -q 'Offline-System bestätigt: Linux' "$work/out"
[[ $(grep -c -- '--listen' "$MOCK_CALLS") == 1 ]]
grep -q -- '--remote inspect-os' "$MOCK_CALLS"
grep -q -- '--remote inspect-get-type /dev/sda2' "$MOCK_CALLS"
# Different OS family (Alpine) from QGA, offline still generic linux.
export MOCK_STATUS=running
: > "$MOCK_CALLS"
bash -c 'source "$1"; VMID=102; DISK_PATHS=(/fake/disk.qcow2); engine_guest_inspect' _ "$root/lib/engine.sh" > "$work/out" 2>&1
grep -q 'Alpine Linux 3.22' "$work/out"
[[ ! -s "$MOCK_CALLS" ]]
# Explicit non-linux root is rejected.
export MOCK_STATUS=stopped MOCK_TYPE=windows
if bash -c 'source "$1"; VMID=102; DISK_PATHS=(/fake/disk.qcow2); engine_guest_inspect' _ "$root/lib/engine.sh" > "$work/out" 2>&1; then
 echo 'FAIL: non-linux disk was accepted' >&2; exit 1
fi
grep -q 'Nicht-Linux erkannt' "$work/out"
echo 'PASS guest inspection (Linux offline, Alpine via agent, non-Linux rejection)'
