#!/usr/bin/env bash
set -euo pipefail
base=$(cd -- "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
cat > "$tmp/pvesh" <<'MOCK'
#!/usr/bin/env bash
case "$*" in
 *'/tasks --source all'* )
 cat <<'JSON'
[{"upid":"UPID:server:ABC:OLD:","type":"vzcreate","id":"117","starttime":1700000010},{"upid":"UPID:server:ABC:NEW:","type":"vzcreate","id":"117","starttime":1700000020}]
JSON
 ;;
 *'/log --start 0'* )
 cat <<'JSON'
[{"n":1,"t":"Creating filesystem"},{"n":2,"t":"Extracting archive"}]
JSON
 ;;
 *'/log --start 2'* )
 cat <<'JSON'
[{"n":3,"t":"Cannot change ownership to uid 123456789: Invalid argument"}]
JSON
 ;;
 *'/log --start 3'* ) echo '[]';;
 *'/status'* ) echo '{"status":"stopped","exitstatus":"ERROR: extract failed"}';;
 * ) echo "Unexpected pvesh: $*" >&2; exit 1;;
esac
MOCK
chmod +x "$tmp/pvesh"
export PATH="$tmp:$PATH"
source "$base/lib/task-monitor.sh"
tm_available
tm_find server 117 vzcreate 1700000015
[[ $TM_UPID == 'UPID:server:ABC:NEW:' ]]
tm_poll "$tmp/log"
tm_poll "$tmp/log"
tm_poll "$tmp/log"
[[ $TM_LAST_N == 3 ]]
[[ $TM_STATUS == stopped ]]
[[ $TM_EXITSTATUS == 'ERROR: extract failed' ]]
[[ $(wc -l < "$tmp/log") == 3 ]]
[[ $(grep -c 'Creating filesystem' "$tmp/log") == 1 ]]
echo 'PASS task monitor discovery, incremental log, status, no duplicates'
