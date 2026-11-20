#!/usr/bin/env bash
# Pure mocked regression tests: NO live Proxmox operations.
set -Eeuo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/bin"
cat > "$work/bin/qm" <<'QM'
#!/usr/bin/env bash
case "$*" in
  'status 102') echo "status: ${MOCK_STATUS:-stopped}" ;;
  *) echo "unexpected qm invocation: $*" >&2; exit 42 ;;
esac
QM
cat > "$work/bin/script" <<'SCRIPT'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$MOCK_SCRIPT_LOG"
[[ "$*" == '-q -e -c qm shutdown 102 --timeout 180 /dev/null' ]] || exit 72
[[ "${MOCK_SCRIPT_EXIT:-0}" == 0 ]] || exit "$MOCK_SCRIPT_EXIT"
SCRIPT
chmod +x "$work/bin/qm" "$work/bin/script"
export PATH="$work/bin:$PATH" MOCK_SCRIPT_LOG="$work/script.log"
export MOCK_STATUS=stopped MOCK_SCRIPT_EXIT=0
bash -c 'source "$1"; VMID=102; engine_shutdown_vm' _ "$root/lib/engine.sh" > "$work/out"
grep -q 'VM 102 ist gestoppt' "$work/out"
grep -q 'qm shutdown 102 --timeout 180' "$MOCK_SCRIPT_LOG"
# If worker failed, must fail closed even if status claims stopped.
export MOCK_SCRIPT_EXIT=3
if bash -c 'source "$1"; VMID=102; engine_shutdown_vm' _ "$root/lib/engine.sh" > "$work/out" 2>&1; then
 echo 'FAIL: shutdown subprocess error was accepted' >&2; exit 1
fi
grep -q 'Shutdown fehlgeschlagen' "$work/out" || grep -q 'Proxmox-Shutdown fehlgeschlagen' "$work/out"
# A clean worker result with VM still running is also a hard failure; limit waits in mock by overriding sleep.
cat > "$work/bin/sleep" <<'SLEEP'
#!/bin/sh
exit 0
SLEEP
chmod +x "$work/bin/sleep"
export MOCK_SCRIPT_EXIT=0 MOCK_STATUS=running
if bash -c 'source "$1"; VMID=102; engine_shutdown_vm' _ "$root/lib/engine.sh" > "$work/out" 2>&1; then
 echo 'FAIL: running VM accepted after shutdown' >&2; exit 1
fi
grep -q 'nicht nachweislich gestoppt' "$work/out"
if grep -Eq 'qm stop|destroy|kill' "$MOCK_SCRIPT_LOG"; then echo 'FAIL: unsafe operation' >&2; exit 1; fi
echo 'PASS shutdown PTY: success, failure, still-running VM'
