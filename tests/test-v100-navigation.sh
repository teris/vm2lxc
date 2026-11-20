#!/usr/bin/env bash
set -Eeuo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
source "$root/lib/tui.sh"
UI_STEP_ACTIVE=1 UI_STEP_REPLAY=0 UI_STEP_INDEX=0
UI_STEP_NAMES=() UI_STEP_VALUES=()
ui_wizard_frame() { :; }
ui_height() { echo 25; }
ui_width() { echo 100; }
ui_put() { :; }
ui_readkey() { UI_KEY=${KEYS[KEY_INDEX]}; KEY_INDEX=$((KEY_INDEX+1)); }
KEYS=(enter enter step_back)
KEY_INDEX=0
ui_wizard_choice 'First' 'One' a 'One' b 'Two'
[[ $UI_PICK == a && $UI_STEP_INDEX -eq 1 ]]
ui_wizard_choice 'Second' 'Two' yes 'Yes' no 'No'
[[ $UI_PICK == yes && $UI_STEP_INDEX -eq 2 ]]
if ui_wizard_choice 'Third' 'Three' yes 'Yes'; then echo 'Ctrl+R failed' >&2; exit 1; fi
[[ $UI_STEP_BACK == 1 && $UI_STEP_INDEX -eq 3 ]]
UI_STEP_REPLAY=$((UI_STEP_INDEX-2)); UI_STEP_INDEX=0; UI_STEP_BACK=0
ui_wizard_choice 'First' 'One' a 'One' b 'Two'
[[ $UI_PICK == a && $UI_STEP_INDEX == 1 && $KEY_INDEX == 3 ]]
KEYS+=(down enter)
ui_wizard_choice 'Second' 'Two' yes 'Yes' no 'No'
[[ $UI_PICK == no && $UI_STEP_INDEX == 2 ]]
UI_STEP_INDEX=0; UI_STEP_REPLAY=2
ui_wizard_choice 'First' 'One' a 'One' b 'Two'
ui_wizard_choice 'Second' 'Two' yes 'Yes' no 'No'
[[ $UI_PICK == no && $KEY_INDEX == 5 ]]
# Esc restarts wizard, discarding all cached answers.
UI_STEP_ACTIVE=0; UI_PAGE=vm; UI_VM=117; UI_NAV_STACK=(home vms)
ui_restart
[[ $UI_PAGE == home && -z $UI_VM && ${#UI_NAV_STACK[@]} == 0 ]]
printf 'PASS: Ctrl+R history replay, branch replacement and Esc restart\n'
