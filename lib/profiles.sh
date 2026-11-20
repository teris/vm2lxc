#!/usr/bin/env bash
# Structured per-migration plans; no credentials, no automatic execution.
# SPDX-License-Identifier: MIT
profiles_directory() { printf '%s' "${PVE_VM2LXC_PROFILES:-$ROOT_DIR/profiles}"; }
profile_save() {
 local vm=$1 ct=$2 store=$3 size=$4 archive=$5 action=$6 shutdown=$7; shift 7
 local dir filename stamp file temp options_json hw_json
 command -v jq >/dev/null || { echo 'jq erforderlich' >&2; return 1; }
 [[ $vm =~ ^[0-9]+$ && $ct =~ ^[0-9]+$ ]] || return 1
 dir=$(profiles_directory); install -d -m 0700 "$dir" || return 1
 stamp=$(date -u +%Y%m%dT%H%M%SZ)
 filename="vm-${vm}-ct-${ct}-${stamp}.json"
 file="$dir/$filename"
 temp=$(mktemp "$dir/.profile.XXXXXXXX") || return 1
 # args are JSON strings, never interpolated into shell. No ssh credentials saved.
 hw_json=${PVE_VM2LXC_HW_JSON:-\{\}}
 options_json=$(printf '%s\n' "$@" | jq -Rsc 'split("\n")[:-1]') || return 1
 jq -n --arg created "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --argjson vm "$vm" --argjson ct "$ct" --arg store "$store" \
   --argjson size "$size" --arg archive "$archive" --arg action "$action" \
   --argjson shutdown "$shutdown" --argjson delete_after_verification "${PVE_VM2LXC_DELETE_INTENT:-false}" --argjson options "$options_json" --argjson hw "$hw_json" '{schema:1,created_at:$created,vmid:$vm,ctid:$ct,storage:$store,rootfs_gib:$size,archive_dir:$archive,action:$action,shutdown:$shutdown,delete_after_verification:$delete_after_verification,engine_options:$options,hardware_inventory:$hw}' > "$temp" || { rm -f "$temp"; return 1; }
 chmod 0600 "$temp" && mv -n "$temp" "$file" || { rm -f "$temp"; return 1; }
 echo "$file"
}
profile_list() {
 local dir; dir=$(profiles_directory)
 [[ -d $dir ]] || return 0
 find "$dir" -maxdepth 1 -type f -name 'vm-*-ct-*.json' -printf '%f\n' | sort -r
}
profile_load() {
 local file=$1 dir; dir=$(profiles_directory)
 [[ $file =~ ^vm-[0-9]+-ct-[0-9]+-[0-9]{8}T[0-9]{6}Z\.json$ ]] || return 1
 [[ -f $dir/$file && ! -L $dir/$file ]] || return 1
 jq -e '.schema==1 and (.vmid|type=="number") and (.ctid|type=="number") and (.rootfs_gib|type=="number") and (.engine_options|type=="array")' "$dir/$file" >/dev/null
}
profile_run() {
 local file=$1 path vm ct store size archive action shutdown
 profile_load "$file" || { echo 'Ungültiges Profil' >&2; return 1; }
 path="$(profiles_directory)/$file"
 vm=$(jq -r .vmid "$path"); ct=$(jq -r .ctid "$path")
 store=$(jq -r .storage "$path"); size=$(jq -r .rootfs_gib "$path")
 archive=$(jq -r .archive_dir "$path"); action=$(jq -r .action "$path"); shutdown=$(jq -r .shutdown "$path")
 [[ $action == convert || $action == plan ]] || return 1
 local -a options=() cmd=()
 mapfile -t options < <(jq -r '.engine_options[]' "$path")
 cmd=("$action" --vmid "$vm" --ctid "$ct" --storage "$store" --size "$size" --archive-dir "$archive")
 cmd+=("${options[@]}")
 [[ $shutdown == true && $action == convert ]] && cmd+=(--shutdown)
 echo "Profil: $file"
 echo "Aktion: $action, VM: $vm, CT: $ct, Storage: $store, Rootfs: $size GiB"
 echo 'Alle Prüfungen werden erneut durchgeführt. Bei convert sind Bestätigungen erforderlich.'
 engine_main "${cmd[@]}"
}

# Delete a single validated profile, never follow symlinks or arbitrary paths.
profile_delete() {
 local file=${1:-} dir
 [[ $file =~ ^vm-[0-9]+-ct-[0-9]+-[0-9]{8}T[0-9]{6}Z\.json$ ]] || return 1
 dir=$(profiles_directory)
 [[ -f "$dir/$file" && ! -L "$dir/$file" ]] || return 1
 rm -- "$dir/$file"
}
