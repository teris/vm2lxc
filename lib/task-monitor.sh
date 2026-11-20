#!/usr/bin/env bash
# Read-only adapter for live PVE task logs. Optional; no host mutations.
# Requires jq, pvesh. All state is held in the invoking shell.
# SPDX-License-Identifier: MIT
TM_UPID='' TM_NODE='' TM_LAST_N=0 TM_STATUS='' TM_EXITSTATUS=''
tm_available() { command -v pvesh >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; }
tm_find() {
  local node=$1 vmid=$2 type=$3 since=$4 result upid
  [[ $vmid =~ ^[0-9]+$ && $since =~ ^[0-9]+$ ]] || return 1
  result=$(timeout 4 pvesh get "/nodes/$node/tasks" --source all --vmid "$vmid" --typefilter "$type" --since "$since" --limit 30 --output-format json 2>/dev/null) || return 1
  upid=$(jq -r --arg type "$type" --arg vmid "$vmid" --argjson since "$since" '[.[] | select(.type==$type and (.id|tostring)==$vmid and (.starttime|tonumber)>=$since)] | sort_by(.starttime) | last | .upid // empty' <<< "$result" 2>/dev/null) || return 1
  [[ $upid == UPID:* ]] || return 1
  TM_NODE=$node TM_UPID=$upid TM_LAST_N=0 TM_STATUS=running TM_EXITSTATUS=''
}
tm_poll() {
 local outfile=$1 result status
 [[ $TM_UPID == UPID:* && -n $TM_NODE ]] || return 1
 # Proxmox line numbers start with 1; API start is a zero-based offset.
 result=$(timeout 4 pvesh get "/nodes/$TM_NODE/tasks/$TM_UPID/log" --start "$TM_LAST_N" --limit 100 --output-format json 2>/dev/null) || return 1
 if jq -e 'type=="array"' >/dev/null 2>&1 <<< "$result"; then
  jq -r --argjson last "$TM_LAST_N" '.[] | select((.n|tonumber)>$last) | .t // empty' <<< "$result" >> "$outfile" 2>/dev/null || :
  local n
  n=$(jq -r '[.[] | .n | tonumber] | max // 0' <<< "$result" 2>/dev/null) || n=0
  [[ $n =~ ^[0-9]+$ ]] && ((n>TM_LAST_N)) && TM_LAST_N=$n
 fi
 status=$(timeout 4 pvesh get "/nodes/$TM_NODE/tasks/$TM_UPID/status" --output-format json 2>/dev/null) || return 0
 TM_STATUS=$(jq -r '.status // "unknown"' <<< "$status" 2>/dev/null) || TM_STATUS=unknown
 TM_EXITSTATUS=$(jq -r '.exitstatus // ""' <<< "$status" 2>/dev/null) || TM_EXITSTATUS=''
}
tm_safe_text() {
 # Hide ANSI/control sequences from untrusted worker output before writing to UI.
 LC_ALL=C sed -E $'s/\033\[[0-9;?]*[ -/]*[@-~]//g; s/[\001-\010\013-\037\177]/ /g'
}
