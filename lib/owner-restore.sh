#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Restore numeric identities from an offline, read-only guestmount into a
# stopped, host-mounted, *default-idmapped* Proxmox LXC rootfs.
# This never modifies the guest or the archive.
# Usage: owner_restore scan|apply|verify SOURCE ROOTFS UIDBASE GIDBASE [JSON_MAP]
owner_restore() {
 local action=$1 source=$2 dest=$3 uidbase=$4 gidbase=$5 mapping=${6:-}
 local rel uid gid mapped_uid mapped_gid path target mode typ processed=0 error=0
 local -a directories=() ; local -A uid_cache=() gid_cache=() seen_uid=() seen_gid=()
 [[ $action == scan || $action == apply || $action == verify ]] || { echo 'owner_restore: invalid action' >&2; return 2; }
 [[ -d $source && -d $dest && $source != "$dest" ]] || { echo 'owner_restore: source/target unavailable' >&2; return 2; }
 [[ $uidbase =~ ^[0-9]+$ && $gidbase =~ ^[0-9]+$ ]] || return 2
 if [[ -n $mapping ]]; then
  [[ -r $mapping ]] && jq -e 'type=="object" and ((.uids//{})|type=="object") and ((.gids//{})|type=="object")' "$mapping" >/dev/null || { echo 'owner_restore: invalid JSON map' >&2; return 2; }
 fi
 # A line-oriented manifest would corrupt filenames containing newlines. Read
 # paths as NUL-separated records. The source remains mounted until verification.
 while IFS= read -r -d '' path; do
  rel=${path#"$source"/}
  [[ $path == "$source" ]] && rel=.
  # The full TAR intentionally excludes these *top-level* runtime trees.
  case $rel in proc|proc/*|sys|sys/*|dev|dev/*|run|run/*|mnt/pve-vm2lxc|mnt/pve-vm2lxc/*) continue;; esac
  # The destination must not be reached through an ancestor symlink. Never
  # follow a symlink when applying chown/chmod.
  if [[ $rel == . ]]; then target=$dest; else target=$dest/$rel; fi
  if [[ $action != scan && ! -e $target && ! -L $target ]]; then
   printf 'Missing extracted path: %q\n' "$rel" >&2; error=1; continue
  fi
  if [[ $action != scan ]]; then
   local parent=$target
   while [[ $parent != "$dest" ]]; do
    parent=${parent%/*}; [[ -n $parent ]] || break
    if [[ -L $parent ]]; then printf 'Symlink ancestor rejected: %q\n' "$rel" >&2; error=1; continue 2; fi
   done
  fi
  uid=$(stat -c '%u' -- "$path") || return 2
  gid=$(stat -c '%g' -- "$path") || return 2
  mode=$(stat -c '%a' -- "$path") || return 2
  typ=$(stat -c '%F' -- "$path") || return 2
  if [[ ! -v uid_cache[$uid] ]]; then
   local next=$uid
   if ((uid>=65536)); then
    next=''
    [[ -z $mapping ]] || next=$(jq -er --arg id "$uid" '.uids[$id] // empty' "$mapping" 2>/dev/null) || next=''
   fi
   [[ $next =~ ^[0-9]+$ ]] && ((next<65536)) || { printf 'Unmappable UID %s: %q\n' "$uid" "$rel" >&2; error=1; continue; }
   uid_cache[$uid]=$((uidbase+next))
  fi
  if [[ ! -v gid_cache[$gid] ]]; then
   local next=$gid
   if ((gid>=65536)); then
    next=''
    [[ -z $mapping ]] || next=$(jq -er --arg id "$gid" '.gids[$id] // empty' "$mapping" 2>/dev/null) || next=''
   fi
   [[ $next =~ ^[0-9]+$ ]] && ((next<65536)) || { printf 'Unmappable GID %s: %q\n' "$gid" "$rel" >&2; error=1; continue; }
   gid_cache[$gid]=$((gidbase+next))
  fi
  mapped_uid=${uid_cache[$uid]}; mapped_gid=${gid_cache[$gid]}
  if [[ -v seen_uid[$mapped_uid] && ${seen_uid[$mapped_uid]} != "$uid" ]]; then
   printf 'UID mapping collision: %s and %s -> %s\n' "${seen_uid[$mapped_uid]}" "$uid" "$mapped_uid" >&2; error=1; continue
  fi
  if [[ -v seen_gid[$mapped_gid] && ${seen_gid[$mapped_gid]} != "$gid" ]]; then
   printf 'GID mapping collision: %s and %s -> %s\n' "${seen_gid[$mapped_gid]}" "$gid" "$mapped_gid" >&2; error=1; continue
  fi
  seen_uid[$mapped_uid]=$uid; seen_gid[$mapped_gid]=$gid
  ((processed+=1))
  [[ $action == scan ]] && continue
  if [[ $action == apply ]]; then
   # Directory chown and ACLs are performed after their children.
   if [[ -d $path && ! -L $path ]]; then directories+=("$path"); continue; fi
   chown -h -- "$mapped_uid:$mapped_gid" "$target" || { printf 'chown failed: %q\n' "$rel" >&2; error=1; continue; }
   if [[ ! -L $path ]]; then
    chmod -- "$mode" "$target" || error=1
    owner_restore_acl "$path" "$target" "$uidbase" "$gidbase" "$mapping" || error=1
    owner_restore_xattr "$path" "$target" || error=1
   fi
  else
   if [[ $(stat -c '%u:%g' -- "$target") != "$mapped_uid:$mapped_gid" ]]; then
    printf 'Ownership mismatch: %q\n' "$rel" >&2; error=1
   fi
  fi
 done < <(find "$source" \( -path "$source/proc" -o -path "$source/sys" -o -path "$source/dev" -o -path "$source/run" -o -path "$source/mnt/pve-vm2lxc" \) -prune -o -print0)
 if [[ $action == apply ]]; then
  local i d target
  for ((i=${#directories[@]}-1;i>=0;i--)); do
   d=${directories[i]}; rel=${d#"$source"/}; [[ $d == "$source" ]] && rel=.
   [[ $rel == . ]] && target=$dest || target=$dest/$rel
   uid=$(stat -c %u -- "$d"); gid=$(stat -c %g -- "$d")
   mapped_uid=${uid_cache[$uid]}; mapped_gid=${gid_cache[$gid]}
   mode=$(stat -c %a -- "$d")
   chown -h -- "$mapped_uid:$mapped_gid" "$target" && chmod -- "$mode" "$target" || error=1
   owner_restore_acl "$d" "$target" "$uidbase" "$gidbase" "$mapping" || error=1
   owner_restore_xattr "$d" "$target" || error=1
  done
 fi
 printf 'Owner %s: %d paths, %d errors\n' "$action" "$processed" "$error"
 ((error==0))
}
owner_restore_acl() {
 local source=$1 target=$2 ub=$3 gb=$4 map=${5:-}
 local line prefix kind id suffix mapped acltmp
 acltmp=$(mktemp) || return 1
 while IFS= read -r line; do
  if [[ $line =~ ^(default:)?(user|group):([0-9]+):(.*)$ ]]; then
   prefix=${BASH_REMATCH[1]}; kind=${BASH_REMATCH[2]}; id=${BASH_REMATCH[3]}; suffix=${BASH_REMATCH[4]}
   if ((id>=65536)); then
    local section=uids; [[ $kind == group ]] && section=gids
    [[ -n $map ]] || { rm -f "$acltmp"; return 2; }
    mapped=$(jq -er --arg id "$id" --arg section "$section" '.[$section][$id] // empty' "$map" 2>/dev/null) || { rm -f "$acltmp"; return 2; }
   else mapped=$id; fi
   [[ $mapped =~ ^[0-9]+$ ]] && ((mapped<65536)) || { rm -f "$acltmp"; return 2; }
   if [[ $kind == user ]]; then mapped=$((mapped+ub)); else mapped=$((mapped+gb)); fi
   line="${prefix}${kind}:${mapped}:${suffix}"
  fi
  printf '%s\n' "$line" >> "$acltmp"
 done < <(getfacl -cpn -- "$source" 2>/dev/null)
 setfacl --set-file="$acltmp" -- "$target"
 local rc=$?
 rm -f "$acltmp"
 return "$rc"
}
owner_restore_xattr() {
 local source=$1 target=$2 line key value rc=0
 command -v getfattr >/dev/null || return 0
 # Hex encoding preserves arbitrary binary xattr values in a Bash pipeline.
 while IFS= read -r line; do
  [[ $line == *=* ]] || continue
  key=${line%%=*}; value=${line#*=}
  [[ $key == *.* ]] || continue
  setfattr -n "$key" -v "$value" -- "$target" || rc=1
 done < <(getfattr -dm - --encoding=hex -- "$source" 2>/dev/null)
 return "$rc"
}
