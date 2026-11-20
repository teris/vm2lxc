#!/usr/bin/env bash
set -Eeuo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
source "$root/lib/tui.sh"
UI_PAGE=vms UI_VM='' UI_CURSOR=0 UI_ACTIVE=1
collects=0 draws=0 repaints=0 idx=0
keys=(down down up refresh down q)
ui_collect() { ((collects+=1)); UI_IDS=(101 102 103); UI_DESCS=('one' 'two' 'three'); }
ui_draw() { ((draws+=1)); }
ui_menu_repaint_row() { ((repaints+=1)); }
ui_width() { printf 100; }
ui_height() { printf 30; }
ui_readkey() { UI_KEY=${keys[idx]}; ((idx+=1)); }
ui_event_loop
[[ $collects -eq 2 ]] || { echo "Expected 2 scans (initial and Alt+R), got $collects" >&2; exit 1; }
[[ $draws -eq 2 ]] || { echo "Expected 2 full frames (initial and Alt+R), got $draws" >&2; exit 1; }
[[ $repaints -eq 8 ]] || { echo "Expected 8 partial rows, got $repaints" >&2; exit 1; }
printf 'PASS: VM list is cached during arrows, refreshed with Alt+R\n'
