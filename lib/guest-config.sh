#!/usr/bin/env bash
# Portable, Bash-only post-import guest configuration. No Python or guest execution.
# SPDX-License-Identifier: MIT

# Discover systemd from the offline root. Parse native Debian / pacman metadata;
# do not execute untrusted guest binaries or guess for other distributions.
gc_systemd_version() {
 local root=$1 v='' line found=0
 GC_SYSTEMD_PRESENT=0 GC_SYSTEMD_VERSION=unknown
 if [[ -e $root/usr/lib/systemd/systemd || -e $root/lib/systemd/systemd ]]; then
  GC_SYSTEMD_PRESENT=1
 else
  return 0
 fi
 if [[ -r $root/var/lib/dpkg/status ]]; then
  while IFS= read -r line || [[ -n $line ]]; do
   if [[ $line == 'Package: systemd' ]]; then found=1; continue; fi
   if ((found)) && [[ $line == 'Version: '* ]]; then
    v=${line#Version: }; break
   fi
   [[ -z $line ]] && found=0
  done < "$root/var/lib/dpkg/status"
 fi
 if [[ -z $v && -d $root/var/lib/pacman/local ]]; then
  local f
  for f in "$root"/var/lib/pacman/local/systemd-[0-9]*/desc; do
   [[ -r $f ]] || continue
   while IFS= read -r line; do
    if [[ $line == '%VERSION%' ]]; then IFS= read -r v || :; break; fi
   done < "$f"
   [[ -n $v ]] && break
  done
 fi
 if [[ $v =~ ([0-9]{3,}) ]]; then GC_SYSTEMD_VERSION=${BASH_REMATCH[1]}; fi
}

# Hash is received in-memory from trusted terminal UI. Never print or log it.
# Write an atomic shadow replacement with only Bash builtins and host utilities;
# preserving the existing mapped owner and other shadow entries.
gc_set_root_hash() {
 local root=$1 hash=$2 shadow dir tmp line rest suffix seen=0 uid gid mode
 shadow="$root/etc/shadow"
 [[ -f $shadow && ! -L $shadow ]] || return 1
 [[ $hash =~ ^\$6\$[a-zA-Z0-9./$]+$ ]] || return 1
 uid=$(stat -c %u -- "$shadow") || return 1
 gid=$(stat -c %g -- "$shadow") || return 1
 mode=$(stat -c %a -- "$shadow") || return 1
 dir="$root/etc"
 tmp=$(mktemp "$dir/.vm2lxc-shadow.XXXXXXXX") || return 1
 chmod 0600 "$tmp" || { rm -f -- "$tmp"; return 1; }
 while IFS= read -r line || [[ -n $line ]]; do
  if [[ $line == root:* ]]; then
   rest=${line#root:}
   [[ $rest == *:* ]] || { rm -f -- "$tmp"; return 1; }
   suffix=${rest#*:}
   printf 'root:%s:%s\n' "$hash" "$suffix" >> "$tmp" || { rm -f -- "$tmp"; return 1; }
   seen=$((seen+1))
  else
   printf '%s\n' "$line" >> "$tmp" || { rm -f -- "$tmp"; return 1; }
  fi
 done < "$shadow"
 if ((seen != 1)); then rm -f -- "$tmp"; return 1; fi
 chown -- "$uid:$gid" "$tmp" && chmod "$mode" "$tmp" && mv -f -- "$tmp" "$shadow" || {
  rm -f -- "$tmp"; return 1;
 }
 # Check that root's hash is committed without displaying the hash.
 IFS= read -r line < "$shadow" || :
 grep -q '^root:\$6\$' "$shadow"
}

# Set only the selected nesting flag, preserve other Proxmox features.
gc_apply_nesting() {
 local ctid=$1 chosen=$2 existing feature output item value='' part
 [[ $chosen == 0 || $chosen == 1 ]] || return 1
 existing=$(pct config "$ctid" | sed -n 's/^features: //p' | head -n 1) || return 1
 if [[ -n $existing ]]; then
  local -a parts=() clean=()
  IFS=, read -r -a parts <<< "$existing"
  for part in "${parts[@]}"; do [[ $part == nesting=* || -z $part ]] || clean+=("$part"); done
  clean+=("nesting=$chosen")
  local IFS=,
  value="${clean[*]}"
 else
  value="nesting=$chosen"
 fi
 pct set "$ctid" --features "$value" || return 1
 output=$(pct config "$ctid") || return 1
 feature=$(sed -n 's/^features: //p' <<< "$output" | head -n 1)
 [[ ,$feature, == *,nesting=$chosen,* ]]
}
