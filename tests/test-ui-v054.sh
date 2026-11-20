#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
export ROOT_DIR="$ROOT"
source "$ROOT/lib/tui.sh"
# Tests that do not need Proxmox or a TTY.
[[ $(ui_loc 'Ziel-Storage') == 'Ziel-Storage' ]]
ui_lang_toggle
[[ $UI_LANG == en ]]
[[ $(ui_loc 'Ziel-Storage') == 'Destination storage' ]]
[[ $(ui_t 'Sprache' 'Language') == Language ]]
ui_lang_toggle
[[ $UI_LANG == de ]]
# Confirmations use y/n (instead of typed magic words), and debug doubles.
req=$(mktemp -u /tmp/pve-ui-req.XXXXXX)
resp=$(mktemp -u /tmp/pve-ui-resp.XXXXXX)
mkfifo "$req" "$resp"
trap 'rm -f "$req" "$resp"' EXIT
(
  export ENGINE_CONFIRM_REQ="$req" ENGINE_CONFIRM_RESP="$resp" ENGINE_DEBUG=0
  source "$ROOT/lib/engine.sh"
  engine_confirm 'Proceed?'
) & pid=$!
IFS= read -r question < "$req"
[[ $question == CONFIRM\|Proceed\?\|1\|1 ]]
printf 'y\n' > "$resp"
wait "$pid"
(
  export ENGINE_CONFIRM_REQ="$req" ENGINE_CONFIRM_RESP="$resp" ENGINE_DEBUG=1
  source "$ROOT/lib/engine.sh"
  engine_confirm 'Proceed?'
) & pid=$!
for n in 1 2; do
 IFS= read -r question < "$req"
 [[ $question == "CONFIRM|Proceed?|$n|2" ]]
 printf 'y\n' > "$resp"
done
wait "$pid"
printf '%s\n' 'UI/confirmation tests passed'
