#!/usr/bin/env bash
# Worker invocation tests use mocks and never contact a live Proxmox host.
set -Eeuo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/bin"
cat > "$work/bin/script" <<'SCRIPT'
#!/usr/bin/env bash
[[ $1 == -q && $2 == -e && $3 == -c && $5 == /dev/null ]] || exit 90
printf '%s\n' "$4" >> "$MOCK_PTY_LOG"
[[ ${MOCK_PTY_EXIT:-0} == 0 ]] || exit "$MOCK_PTY_EXIT"
SCRIPT
chmod +x "$work/bin/script"
export PATH="$work/bin:$PATH" MOCK_PTY_LOG="$work/calls"
source "$root/lib/engine.sh"
engine_pve_worker pct create 117 '/tmp/archive with space.tar' --rootfs 'store02:80'
engine_pve_worker pct set 117 --net0 'name=eth0,bridge=vmbr0,hwaddr=02:00:00:00:00:01,ip=dhcp'
engine_pve_worker pct start 117
engine_pve_worker qm shutdown 102 --timeout 180
[[ $(wc -l < "$MOCK_PTY_LOG") == 4 ]]
grep -Fq 'pct create 117 /tmp/archive\ with\ space.tar --rootfs store02:80' "$MOCK_PTY_LOG"
grep -Fq 'pct set 117 --net0' "$MOCK_PTY_LOG"
grep -Fq 'pct start 117' "$MOCK_PTY_LOG"
grep -Fq 'qm shutdown 102 --timeout 180' "$MOCK_PTY_LOG"
export MOCK_PTY_EXIT=9
if engine_pve_worker pct create 118 /tmp/a.tar --rootfs store02:80; then
 echo 'FAIL: failed worker returned success' >&2; exit 1
fi
if grep -Eq '^qm stop|^pct destroy|^qm destroy' "$MOCK_PTY_LOG"; then
 echo 'FAIL: unexpected destructive commands' >&2; exit 1
fi
echo 'PASS: PTY worker quoting, create/set/start/shutdown, exit status'
