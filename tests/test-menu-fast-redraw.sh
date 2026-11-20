#!/usr/bin/env bash
set -Eeuo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
source "$root/lib/tui.sh"
VERSION=0.6.4
UI_VM=102
UI_LANG=de
UI_SELECTED='' UI_WHITE='' UI_RESET='' UI_BOLD='' UI_BLUE='' UI_MUTED='' UI_AMBER=''
UI_KEYS=(down up enter)
idx=0
ui_readkey() { UI_KEY=${UI_KEYS[$idx]}; ((idx+=1)); }
ui_loc() { printf '%s' "$1"; }
ui_height() { printf '30'; }
ui_width() { printf '100'; }
# Run a menu in a non-interactive mock. Exactly one full frame should be drawn.
out=$(ui_wizard_choice 'Test' 'description' one 'Option one' two 'Option two' 2>&1)
count=$(grep -o $'\033\[H\033\[2J' <<< "$out" | wc -l)
[[ $count == 1 ]] || { echo "Full frames: $count (wanted 1)" >&2; exit 1; }
printf 'PASS: navigation changes rows without repainting full frame\n'
