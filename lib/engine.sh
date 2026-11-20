#!/usr/bin/env bash
# Offline VM-to-LXC migration engine. Never edit source images.
# SPDX-License-Identifier: MIT
set -Eeuo pipefail
ENGINE_DEBUG=${ENGINE_DEBUG:-0}
ENGINE_LOG_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/logs
ENGINE_ROOT=${ENGINE_ROOT:-/var/lib/pve-vm2lxc}
ENGINE_VERSION=$(cat "$(dirname -- "${BASH_SOURCE[0]}")/../VERSION")
ENGINE_LIB_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$ENGINE_LIB_DIR/owner-restore.sh"
source "$ENGINE_LIB_DIR/hardware.sh"
source "$ENGINE_LIB_DIR/guest-config.sh"
engine_die() { printf 'FEHLER: %s\n' "$*" >&2; [[ -n ${ENGINE_LOG:-} ]] && printf '[ERROR] %s\n' "$*" >> "$ENGINE_LOG"; exit 1; }
engine_info() { printf '[INFO] %s\n' "$*"; }
engine_warn() { printf '[WARNUNG] %s\n' "$*" >&2; }
engine_need() { local c; for c in "$@"; do command -v "$c" >/dev/null || engine_die "Fehlendes Programm: $c (siehe README)"; done; }
engine_confirm() {
 local prompt=$1 answer iterations=1 i debuglabel=""
 if [[ $ENGINE_DEBUG == 1 ]]; then iterations=2; fi
 for ((i=1;i<=iterations;i++)); do
  debuglabel=""; [[ $ENGINE_DEBUG == 1 ]] && debuglabel=" ($i/$iterations)"
  if [[ -n ${ENGINE_CONFIRM_REQ:-} && -n ${ENGINE_CONFIRM_RESP:-} ]]; then
   # UI owns the terminal; exchange only simple, line-oriented messages over FIFOs.
   printf 'CONFIRM|%s|%s|%s\n' "$prompt" "$i" "$iterations" > "$ENGINE_CONFIRM_REQ" || engine_die 'TUI control unavailable'
   IFS= read -r answer < "$ENGINE_CONFIRM_RESP" || engine_die 'TUI confirmation unavailable'
  else
   if [[ ${ENGINE_LANG:-de} == en ]]; then
    read -r -p "$prompt [y/n]${debuglabel}: " answer </dev/tty || engine_die 'Confirmation unavailable'
   else
    read -r -p "$prompt [y/n]${debuglabel}: " answer </dev/tty || engine_die 'Bestätigung nicht möglich'
   fi
  fi
  case ${answer,,} in y|yes|j|ja) :;; n|no|nein|q) engine_die 'Aktion durch Benutzer abgebrochen';; *) engine_die 'Bestätigung ungültig (nur y/n)';; esac
 done
}

engine_decision() {
 local answer prompt=$1
 if [[ -n ${ENGINE_CONFIRM_REQ:-} && -n ${ENGINE_CONFIRM_RESP:-} ]]; then
  printf 'CONFIRM|%s|1|1\n' "$prompt" > "$ENGINE_CONFIRM_REQ" || return 1
  IFS= read -r answer < "$ENGINE_CONFIRM_RESP" || return 1
 else
  read -r -p "$prompt [y/N]: " answer </dev/tty || return 1
 fi
 [[ ${answer,,} == y || ${answer,,} == yes || ${answer,,} == j || ${answer,,} == ja ]]
}

engine_started_log() {
 install -d -m 0700 "$ENGINE_LOG_DIR" "$ENGINE_ROOT"
 ENGINE_LOG="$ENGINE_LOG_DIR/$(date -u +%Y%m%dT%H%M%SZ)-vm${VMID}-ct${CTID}.log"
 : > "$ENGINE_LOG"; chmod 0600 "$ENGINE_LOG"
 # Record all stdout/stderr; no password or secret data is logged.
 exec > >(tee -a "$ENGINE_LOG") 2>&1
 engine_info "Protokoll: $ENGINE_LOG"
}
engine_parse() {
 VMID='' CTID='' TARGET_STORAGE='' ARCHIVE_DIR='' TARGET_SIZE='' HOSTNAME='' NAMESERVERS='' SHUTDOWN=0
 HW_CORES='' HW_MEMORY='' HW_SWAP='' HW_CPULIMIT='' HW_CPUUNITS='' OWNER_MAP_FILE='' NESTING_CHOICE=auto
 declare -gA DEVICE_SKIPS=() DEVICE_MAPS=()
 declare -gA IP_OVERRIDES=() GW_OVERRIDES=() IP6_OVERRIDES=() GW6_OVERRIDES=()
 while (($#)); do case $1 in
   --vmid) VMID=${2:?}; shift 2;; --ctid) CTID=${2:?}; shift 2;;
   --storage) TARGET_STORAGE=${2:?}; shift 2;; --archive-dir) ARCHIVE_DIR=${2:?}; shift 2;;
   --size) TARGET_SIZE=${2:?}; shift 2;; --hostname) HOSTNAME=${2:?}; shift 2;;
   --nameserver) NAMESERVERS=${2:?}; shift 2;;
   --cores) HW_CORES=${2:?}; shift 2;;
   --memory) HW_MEMORY=${2:?}; shift 2;;
   --swap) HW_SWAP=${2:?}; shift 2;;
   --cpulimit) HW_CPULIMIT=${2:?}; shift 2;;
   --cpuunits) HW_CPUUNITS=${2:?}; shift 2;;
   --owner-map-file) OWNER_MAP_FILE=${2:?}; shift 2;;
   --nesting) NESTING_CHOICE=${2:?}; shift 2;;
   --device-skip) [[ ${2:-} =~ ^(usb|hostpci|serial|parallel)[0-9]+$ || ${2:-} == args ]] || engine_die 'Invalid device key'; DEVICE_SKIPS[$2]=1; shift 2;;
   --device-map) [[ ${2:-} == *=* ]] || engine_die '--device-map expects SOURCE=/dev/path'; local dkey=${2%%=*} dpath=${2#*=}; [[ $dkey =~ ^(usb|hostpci|serial|parallel)[0-9]+$ || $dkey == args ]] || engine_die 'Invalid source device key'; DEVICE_MAPS[$dkey]=$dpath; shift 2;;
   --ip-net[0-9]*) local idx=${1#--ip-net}; IP_OVERRIDES[$idx]=${2:?}; shift 2;;
   --gw-net[0-9]*) local idx=${1#--gw-net}; GW_OVERRIDES[$idx]=${2:?}; shift 2;;
   --ip6-net[0-9]*) local idx=${1#--ip6-net}; IP6_OVERRIDES[$idx]=${2:?}; shift 2;;
   --gw6-net[0-9]*) local idx=${1#--gw6-net}; GW6_OVERRIDES[$idx]=${2:?}; shift 2;;
   --shutdown) SHUTDOWN=1; shift;; --debug) ENGINE_DEBUG=1; shift;;
   *) engine_die "Unbekannte Option: $1";;
 esac; done
 [[ $VMID =~ ^[0-9]+$ ]] || engine_die '--vmid muss numerisch sein'
 [[ $CTID =~ ^[0-9]+$ ]] || engine_die '--ctid muss numerisch sein'
 [[ $TARGET_SIZE =~ ^[1-9][0-9]*$ ]] || engine_die '--size muss eine positive Ganzzahl in GiB sein'
 [[ $TARGET_STORAGE =~ ^[a-zA-Z0-9_.-]+$ ]] || engine_die 'Ungültiger Storage-Name'
 [[ -d $ARCHIVE_DIR && $ARCHIVE_DIR == /* ]] || engine_die '--archive-dir muss ein vorhandenes absolutes Verzeichnis sein'
 [[ -z $HOSTNAME || $HOSTNAME =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*$ ]] || engine_die 'Ungültiger Hostname'
 if [[ -n $NAMESERVERS ]]; then
  local addr
  for addr in $NAMESERVERS; do
   [[ $addr =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]] || engine_die "Ungültiger DNS-Server: $addr"
   local -a octets
   IFS=. read -r -a octets <<< "$addr"
   local v
   for v in "${octets[@]}"; do ((10#$v<=255)) || engine_die "Ungültiger DNS-Server: $addr"; done
  done
 fi
 [[ -z $OWNER_MAP_FILE || -r $OWNER_MAP_FILE ]] || engine_die "Owner-Mapping-Datei nicht lesbar: $OWNER_MAP_FILE"
 [[ $NESTING_CHOICE == auto || $NESTING_CHOICE == on || $NESTING_CHOICE == off ]] || engine_die "--nesting nur auto|on|off"
 [[ $VMID != "$CTID" ]] || engine_die 'VMID und CTID dürfen nicht gleich sein'
}
# VM resource mapping. QEMU virtual CPU model, NUMA and passthrough devices
# are not LXC equivalents. Never silently copy raw hardware arguments.
engine_hardware() {
 local cfg vm_cores vm_sockets vm_mem vm_cpuunits vm_cpulimit vm_balloon
 cfg=$(qm config "$VMID") || engine_die "Hardwarekonfiguration der VM $VMID nicht lesbar"
 vm_cores=$(awk '$1=="cores:" {print $2;exit}' <<< "$cfg"); vm_cores=${vm_cores:-1}
 vm_sockets=$(awk '$1=="sockets:" {print $2;exit}' <<< "$cfg"); vm_sockets=${vm_sockets:-1}
 vm_mem=$(awk '$1=="memory:" {print $2;exit}' <<< "$cfg"); vm_mem=${vm_mem:-512}
 vm_cpulimit=$(awk '$1=="cpulimit:" {print $2;exit}' <<< "$cfg")
 vm_cpuunits=$(awk '$1=="cpuunits:" {print $2;exit}' <<< "$cfg")
 vm_balloon=$(awk '$1=="balloon:" {print $2;exit}' <<< "$cfg")
 local defaultcores=$((vm_cores * vm_sockets))
 HW_CORES=${HW_CORES:-$defaultcores}
 HW_MEMORY=${HW_MEMORY:-$vm_mem}
 # VM ballooning has no 1:1 swap equivalent: default to no additional swap.
 HW_SWAP=${HW_SWAP:-0}
 HW_CPULIMIT=${HW_CPULIMIT:-$vm_cpulimit}
 HW_CPUUNITS=${HW_CPUUNITS:-$vm_cpuunits}
 [[ $HW_CORES =~ ^[1-9][0-9]*$ ]] && ((HW_CORES<=1024)) || engine_die "Ungültige LXC-Kernzahl: $HW_CORES"
 [[ $HW_MEMORY =~ ^[1-9][0-9]*$ ]] && ((HW_MEMORY>=16)) || engine_die "Ungültiger LXC-RAM: $HW_MEMORY"
 [[ $HW_SWAP =~ ^[0-9]+$ ]] || engine_die "Ungültiger LXC-Swap: $HW_SWAP"
 [[ -z $HW_CPULIMIT || $HW_CPULIMIT =~ ^[0-9]+([.][0-9]+)?$ ]] || engine_die "Ungültiges CPU-Limit: $HW_CPULIMIT"
 [[ -z $HW_CPUUNITS || $HW_CPUUNITS =~ ^[1-9][0-9]*$ ]] || engine_die "Ungültige CPU-Gewichtung: $HW_CPUUNITS"
 engine_info "Hardware: LXC cores=$HW_CORES RAM=${HW_MEMORY}MiB swap=${HW_SWAP}MiB cpulimit=${HW_CPULIMIT:-default} cpuunits=${HW_CPUUNITS:-default}"
 if [[ -n $vm_balloon ]]; then engine_warn "VM-Ballooning ($vm_balloon MiB) ist kein LXC-Swap. Speicherlimit wird separat gesetzt."; fi
 # Virtual QEMU consoles need no Linux device passthrough. Physical devices
 # must have an explicit per-device decision; never silently disappear.
 local line devkey class
 while IFS= read -r line; do
  [[ -n $line ]] || continue
  devkey=$(hw_device_key "$line"); class=$(hw_device_class "$line")
  if [[ $class == virtual-console ]]; then
   engine_info "Virtuelle Konsole $devkey wird durch LXC-Konsole ersetzt (kein Mapping notwendig)."
  elif [[ -v DEVICE_SKIPS[$devkey] ]]; then
   engine_warn "Gerät $devkey bewusst ausgelassen: $line"
  elif [[ -v DEVICE_MAPS[$devkey] ]]; then
   engine_info "Gerät $devkey soll über LXC devN auf ${DEVICE_MAPS[$devkey]} abgebildet werden (nicht 1:1 PCI/USB-Emulation)."
  fi
 done < <(hw_device_lines "$cfg")
 hw_validate_decisions "$cfg" DEVICE_SKIPS DEVICE_MAPS || engine_die 'Geräteentscheidungen fehlen oder sind ungültig.' 
 if grep -Eq '^(cpu|numa|vcpus):' <<< "$cfg"; then
  engine_warn 'VM CPU-Modell, NUMA bzw. vcpus können nicht 1:1 als LXC-Hardware emuliert werden.'
 fi
}
engine_ostype() {
 local ostype
 ostype=$(qm config "$VMID" | sed -n 's/^ostype: //p' | head -1)
 case "$ostype" in
  win*|wvista|w2k*|wxp) engine_die 'Windows-VM: nicht LXC-fähig';;
  l24|l26) :;;
  *) engine_warn "Gast-OS ist nicht verifiziert (Proxmox ostype=$ostype). Prüfung per libguestfs erforderlich.";;
 esac
}
engine_disks() {
 local line key item vol path
 declare -ga DISK_PATHS=()
 declare -ga DISK_VOLUMES=()
 while IFS= read -r line; do
  [[ $line =~ ^((scsi|sata|virtio|ide)[0-9]+):[[:space:]]*([^,]+) ]] || continue
  key=${BASH_REMATCH[1]}; vol=${BASH_REMATCH[3]}
  [[ $vol == none || $vol == cloudinit || $line == *'media=cdrom'* ]] && continue
  [[ $vol == *:* ]] || engine_die "Nicht verwalteter Datenträger $key: $vol"
  path=$(pvesm path "$vol") || engine_die "Storage-Pfad nicht verfügbar: $vol"
  [[ -e $path ]] || engine_die "Datenträger existiert nicht: $path"
  DISK_PATHS+=("$path"); DISK_VOLUMES+=("$vol")
 done < <(qm config "$VMID")
 ((${#DISK_PATHS[@]})) || engine_die 'Keine lesbaren Datenträger gefunden'
}
engine_net() {
 local cfg line id raw mac bridge tag mtu firewall netstr cidr gw gw6 ip6 gateway_count=0
 declare -ga NET_ARGS=()
 declare -ga NET_DESCS=()
 cfg=$(qm config "$VMID")
 while IFS= read -r line; do
  [[ $line =~ ^net([0-9]+):[[:space:]]*(.*)$ ]] || continue
  id=${BASH_REMATCH[1]}; raw=${BASH_REMATCH[2]}
  mac=$(sed -nE 's/.*(virtio|e1000|rtl8139|vmxnet3|ne2k_pci|i82551|i82557|i82559)=([0-9A-Fa-f:]{17}).*/\2/p' <<< "$raw")
  [[ -n $mac ]] || engine_die "MAC für net$id nicht identifizierbar"
  bridge=$(grep -oE '(^|,)bridge=[A-Za-z0-9_.-]+' <<< "$raw" | head -1 | cut -d= -f2)
  [[ -n $bridge ]] || engine_die "Bridge für net$id nicht identifizierbar"
  # Static IP cannot generally be recovered from a QEMU NIC config.
  cidr=${IP_OVERRIDES[$id]:-}
  [[ -n $cidr ]] || engine_die "IP von net$id unbekannt. Mit --ip-net$id CIDR (oder dhcp) explizit angeben. MAC=$mac"
  [[ $cidr == dhcp || $cidr == manual || $cidr =~ ^[0-9a-fA-F:.]+/[0-9]+$ ]] || engine_die "Ungültige IP-Angabe für net$id: $cidr"
  [[ $cidr != manual ]] || engine_die "net$id: 'manual' nur bei vorab dokumentierter Gast-Konfiguration, nicht automatisiert"
  netstr="name=eth$id,bridge=$bridge,hwaddr=$mac,ip=$cidr"
  ip6=${IP6_OVERRIDES[$id]:-manual}; gw6=${GW6_OVERRIDES[$id]:-}
  [[ $ip6 == auto || $ip6 == dhcp || $ip6 == manual || $ip6 =~ ^[0-9a-fA-F:]+/[0-9]{1,3}$ ]] || engine_die "IPv6 für net$id ungültig: $ip6"
  netstr+=",ip6=$ip6"
  if [[ -n $gw6 ]]; then
    [[ $gw6 =~ ^[0-9a-fA-F:]+(%[[:alnum:]_.-]+)?$ ]] || engine_die "IPv6-Gateway ungültig: $gw6"
    netstr+=",gw6=$gw6"
  fi
  gw=${GW_OVERRIDES[$id]:-}
  if [[ -n $gw ]]; then
    [[ $gw =~ ^[0-9a-fA-F:.]+$ ]] || engine_die "Gateway für net$id ungültig: $gw"
    netstr+=",gw=$gw"
    ((gateway_count+=1))
  fi
  tag=$(grep -oE '(^|,)tag=[0-9]+' <<< "$raw" | head -1 | cut -d= -f2 || :)
  mtu=$(grep -oE '(^|,)mtu=[0-9]+' <<< "$raw" | head -1 | cut -d= -f2 || :)
  [[ -z $tag ]] || netstr+=",tag=$tag"
  [[ -z $mtu ]] || netstr+=",mtu=$mtu"
  NET_ARGS+=("--net$id" "$netstr")
  NET_DESCS+=("net$id: $netstr")
 done <<< "$cfg"
 ((gateway_count <= 1)) || engine_die "Mehrere IPv4-Standard-Gateways konfiguriert. Bitte Routing vor Migration prüfen."
}
engine_storage_check() {
 local listing status
 listing=$(pvesm status --content rootdir 2>&1) || engine_die "Proxmox Storage-Abfrage fehlgeschlagen: $listing"
 status=$(awk -v s="$TARGET_STORAGE" '$1==s {print $3; exit}' <<< "$listing")
 [[ $status == active ]] || engine_die "Storage '$TARGET_STORAGE' ist nicht aktiv oder unterstützt keine rootdir-Volumes (pvesm status --content rootdir)"
 [[ -w $ARCHIVE_DIR ]] || engine_die "Kein Schreibzugriff auf $ARCHIVE_DIR"
}
# Source guest OS metadata from a RUNNING VM only; never treat QGA as disk validation.
engine_agent_osinfo() {
 local output id pretty arch
 [[ $(qm status "$VMID" 2>/dev/null) == 'status: running' ]] || return 1
 command -v jq >/dev/null 2>&1 || { engine_warn 'jq fehlt: QEMU-Agent-OS-Details nicht auswertbar'; return 1; }
 output=$(timeout 12 qm guest cmd "$VMID" get-osinfo 2>&1) || {
   engine_warn "QEMU Guest Agent antwortet nicht: ${output:0:300}"; return 1;
 }
 id=$(jq -r '.id // empty' <<< "$output" 2>/dev/null) || return 1
 pretty=$(jq -r '."pretty-name" // .name // empty' <<< "$output" 2>/dev/null) || return 1
 arch=$(jq -r '.machine // empty' <<< "$output" 2>/dev/null) || return 1
 [[ -n $id ]] || { engine_warn 'QEMU-Agent liefert keine OS-ID'; return 1; }
 case ${id,,} in
  windows*|freebsd*|openbsd*|netbsd*|darwin*|macos*) engine_die "Nicht-Linux-Gast (Agent): $pretty ($id)";;
 esac
 engine_info "QEMU-Agent: ${pretty:-$id} (ID=$id; Architektur=${arch:-unbekannt})"
 return 0
}

# Inspect disks using ONE persistent guestfish handle. This supports all Linux
# distributions recognized by libguestfs; never hard-code Debian or Ubuntu.
engine_guest_inspect() {
 local path launch oss type root first=1
 local -a args=() roots=()
 engine_need guestfish guestmount guestunmount virt-filesystems tar pct qm pvesm flock
 [[ $(qm status "$VMID" 2>/dev/null) == 'status: stopped' ]] || {
   engine_warn 'Offline-Datenträgerinspektion verschoben: VM ist noch aktiv.'
   engine_agent_osinfo || engine_warn 'Weder QEMU-Agent-OS-Info noch Offline-Inspektion verfügbar; für valide Prüfung VM stoppen.'
   return 0
 }
 for path in "${DISK_PATHS[@]}"; do args+=(-a "$path"); done
 local gf_err gf_log
 install -d -m 0700 "$ENGINE_LOG_DIR" || engine_die 'Logverzeichnis nicht beschreibbar'
 gf_log=$(mktemp "$ENGINE_LOG_DIR/guestfish-XXXXXXXX.log") || engine_die 'Kein temporäres Log möglich'
 if ! launch=$(guestfish --ro "${args[@]}" --listen 2>"$gf_log"); then
   engine_warn "guestfish: $(tail -n 8 "$gf_log")"
   rm -f "$gf_log"
   engine_die 'libguestfs konnte keine Read-Only-Sitzung starten'
 fi
 rm -f "$gf_log"
 # guestfish --listen prints GUESTFISH_PID=...; export GUESTFISH_PID
 if [[ $launch =~ GUESTFISH_PID=([0-9]+) ]]; then
   local GUESTFISH_PID=${BASH_REMATCH[1]}
   export GUESTFISH_PID
 else
   engine_die "guestfish --listen gab keine gültige Sitzungs-ID zurück: ${launch:0:200}"
 fi
 if ! gf_err=$(guestfish --remote run 2>&1); then
   guestfish --remote exit >/dev/null 2>&1 || :
   engine_die "libguestfs run fehlgeschlagen: ${gf_err:0:800}"
 fi
 if ! oss=$(guestfish --remote inspect-os 2>&1); then
   guestfish --remote exit >/dev/null 2>&1 || :
   engine_die "libguestfs inspect-os fehlgeschlagen: ${oss:0:800}"
 fi
 while IFS= read -r root; do [[ -n $root ]] && roots+=("$root"); done <<< "$oss"
 if ((${#roots[@]} != 1)); then
   guestfish --remote exit >/dev/null 2>&1 || :
   engine_die "Erwartet genau ein Root-Dateisystem, erkannt: ${#roots[@]} (${oss:0:300})"
 fi
 root=${roots[0]}
 if ! type=$(guestfish --remote inspect-get-type "$root" 2>&1); then
   guestfish --remote exit >/dev/null 2>&1 || :
   engine_die "Gast-Typ nicht lesbar (Root=$root): ${type:0:800}"
 fi
 guestfish --remote exit >/dev/null 2>&1 || :
 [[ $type == linux ]] || engine_die "Nicht-Linux erkannt: $type (Root=$root)"
 engine_info "Offline-System bestätigt: Linux (Root=$root)"
}
# Verify target bridge names while the source VM is still running. Different
# VM and LXC networking semantics require later verification as well.
engine_check_target_network_bridges() {
 local i bridge cfg
 for ((i=0;i<${#NET_ARGS[@]};i+=2)); do
  cfg=${NET_ARGS[i+1]}
  bridge=$(sed -n 's/.*\(^\|,\)bridge=\([^,]*\).*/\2/p' <<< "$cfg")
  [[ -n $bridge ]] || engine_die "Netzwerk ${NET_ARGS[i]} enthaelt keine Bridge"
  [[ -d /sys/class/net/$bridge ]] || engine_die "Netzwerk-Bridge '$bridge' fehlt auf diesem Proxmox-Host"
 done
}
engine_preflight() {
 engine_need qm pct pvesm awk sed grep findmnt df flock guestfish guestmount guestunmount virt-filesystems tar script jq setfacl getfacl getfattr setfattr
 [[ $(id -u) == 0 ]] || engine_die 'Nur als root auf dem Proxmox-Host'
 qm config "$VMID" >/dev/null || engine_die "VM $VMID existiert nicht"
 ! pct config "$CTID" >/dev/null 2>&1 || engine_die "CT $CTID existiert bereits"
 ! qm config "$CTID" >/dev/null 2>&1 || engine_die "ID $CTID wird bereits von einer VM verwendet"
 engine_ostype; engine_disks; engine_net; engine_hardware; engine_storage_check; engine_guest_inspect
 engine_check_target_network_bridges
 local cfg
 cfg=$(qm config "$VMID")
 # Device choices were validated in engine_hardware; do not blanket-block PCI/USB.
 grep -q '^efidisk' <<< "$cfg" && engine_warn 'EFI-Festplatte wird nicht als Container-Mount übernommen (LXC benötigt keinen Bootloader).'
 if [[ $(qm status "$VMID" | awk '{print $2}') == running ]]; then
  engine_warn "VM $VMID läuft: Für konsistente Offline-Übernahme wird ein Shutdown benötigt"
 fi
 engine_info "VM $VMID -> CT $CTID; Ziel: $TARGET_STORAGE (${TARGET_SIZE}G); Archiv: $ARCHIVE_DIR"
 printf '%s\n' "${DISK_VOLUMES[@]}" | sed 's/^/  Disk: /'
 printf '%s\n' "${NET_DESCS[@]}" | sed 's/^/  NIC: /'
 engine_warn 'Es werden ALLE erkannten Gast-Mounts in das ROOTFS-Archiv übernommen (zusammengeführt).'
 engine_warn 'Virtuelle Speichergrößen werden NICHT als echte Filesystem-Shrinks interpretiert. Das Ziel muss alle Nutzdaten fassen.'
}
# Only this run's resources are eligible for cleanup. Other Proxmox mounts,
# particularly /etc/pve, must never be touched.
engine_mount_is_active() {
 local mount=${1:?}
 findmnt -rn --mountpoint "$mount" >/dev/null 2>&1
}
engine_release_guest_mount() {
 local mount=${GUEST_MOUNT:-} attempt
 [[ -n $mount && -d $mount ]] || return 0
 if engine_mount_is_active "$mount"; then
  for ((attempt=1;attempt<=3;attempt++)); do
   if guestunmount --retry=2 "$mount" && ! engine_mount_is_active "$mount"; then break; fi
   engine_warn "guestunmount Versuch $attempt fehlgeschlagen: $mount"
   sleep 1
  done
  if engine_mount_is_active "$mount"; then
   engine_warn "GUEST-MOUNT WEITERHIN AKTIV: $mount. Manuelle Pruefung erforderlich."
   ENGINE_CLEANUP_FAILED=1
   return 1
  fi
 fi
 if ! rmdir -- "$mount" 2>/dev/null; then
  engine_warn "Gast-Mountverzeichnis nicht leer: $mount"
  ENGINE_CLEANUP_FAILED=1
  return 1
 fi
 GUEST_MOUNT=''
 return 0
}
engine_temp_cleanup() {
 local original_rc=$? status='unknown' partial=0
 trap - EXIT INT TERM HUP
 # For errors, leave unfinished CTs STOPPED. Do not auto-unlock or destroy
 # foreign/partial Proxmox resources, whose task worker may still be active.
 if [[ ${CT_STAGING_MOUNTED:-0} == 1 && -n ${CTID:-} ]]; then
  if engine_pve_worker pct unmount "$CTID" >/dev/null 2>&1; then
   CT_STAGING_MOUNTED=0
  else
   engine_warn "CT $CTID ist noch im Staging gemountet; pct unmount manuell pruefen"
   ENGINE_CLEANUP_FAILED=1
  fi
 fi
 engine_release_guest_mount || :
 if [[ -n ${ENGINE_SEED_DIR:-} && -d ${ENGINE_SEED_DIR:-} ]]; then
  # Seed dirs are created by mktemp in ENGINE_ROOT; never accept arbitrary paths.
  if [[ $ENGINE_SEED_DIR == "$ENGINE_ROOT"/seed-"$VMID"-* ]]; then
   rm -rf -- "$ENGINE_SEED_DIR" || ENGINE_CLEANUP_FAILED=1
  fi
 fi
 if [[ ${ENGINE_CT_CREATE_ATTEMPTED:-0} == 1 && -n ${CTID:-} ]] && pct config "$CTID" >/dev/null 2>&1; then
  status=$(pct status "$CTID" 2>/dev/null || :)
  if [[ $status != 'status: stopped' ]]; then
   engine_warn "CT $CTID Status $status – manuelle Kontrolle erforderlich"
   ENGINE_CLEANUP_FAILED=1
  fi
  if [[ ${ENGINE_MIGRATION_READY:-0} != 1 ]]; then
   engine_warn "CT $CTID ist TEILWEISE erstellt und NICHT startbereit; bitte nicht starten."
   engine_warn "Proxmox-CT und Datentraeger bleiben zur Diagnose erhalten (KEINE automatische Loeschung)."
   partial=1
  fi
 fi
 if ((original_rc!=0 || ${ENGINE_CLEANUP_FAILED:-0}!=0 || partial!=0)); then
  engine_warn "Migration/Beendigung mit Fehler (exit=$original_rc), Log: ${ENGINE_LOG:-nicht gesetzt}"
  [[ -z ${GUEST_MOUNT:-} ]] || engine_warn "Moeglicher Rest-Mount: $GUEST_MOUNT"
 fi
 if (( ${ENGINE_CLEANUP_FAILED:-0} != 0 && original_rc == 0 )); then exit 1; fi
 return "$original_rc"
}
engine_signal_abort() {
 local signal=${1:-TERM}
 engine_warn "Signal $signal: laufbezogene Bereinigung wird ausgefuehrt"
 case $signal in INT) exit 130;; HUP) exit 129;; *) exit 143;; esac
}
engine_install_cleanup_traps() {
 trap 'engine_temp_cleanup' EXIT
 trap 'engine_signal_abort INT' INT
 trap 'engine_signal_abort TERM' TERM
 trap 'engine_signal_abort HUP' HUP
}

# Build a tiny owner-neutral bootstrap template. Proxmox allocates its own rootfs;
# the complete original archive is restored only after pct create has succeeded.
engine_build_seed() {
 local source=$1 osid out
 ENGINE_SEED_DIR=$(mktemp -d "$ENGINE_ROOT/seed-${VMID}-XXXXXXXX") || engine_die 'Seed-Verzeichnis kann nicht erstellt werden'
 mkdir -p "$ENGINE_SEED_DIR/root/etc" "$ENGINE_SEED_DIR/root/usr/lib"
 for out in os-release passwd group hostname hosts resolv.conf debian_version redhat-release alpine-release; do
  if [[ -f $source/etc/$out ]]; then
   cp -L -- "$source/etc/$out" "$ENGINE_SEED_DIR/root/etc/$out"
  fi
 done
 [[ -f $ENGINE_SEED_DIR/root/etc/os-release ]] || engine_die 'Seed benötigt etc/os-release'
 ENGINE_SEED_ARCHIVE="$ENGINE_SEED_DIR/seed.tar"
 tar -C "$ENGINE_SEED_DIR/root" --numeric-owner --owner=0 --group=0 -cf "$ENGINE_SEED_ARCHIVE" . || engine_die 'Seed-TAR fehlgeschlagen'
 osid=$(sed -n 's/^ID=//p' "$ENGINE_SEED_DIR/root/etc/os-release" | head -1 | tr -d '"')
 case ${osid,,} in
  debian|ubuntu|alpine|arch|archlinux|fedora|centos|opensuse|gentoo|devuan|nixos) ENGINE_CT_OS=${osid,,} ;;
  rocky|almalinux|rhel|ol) ENGINE_CT_OS=centos ;;
  opensuse-leap|opensuse-tumbleweed|sles) ENGINE_CT_OS=opensuse ;;
  *) ENGINE_CT_OS=unmanaged; engine_warn "Keine PVE-Systemvorlage für Distribution $osid – LXC ostype=unmanaged; Gastanpassung prüfen" ;;
 esac
 [[ $ENGINE_CT_OS != archlinux ]] || ENGINE_CT_OS=archlinux
}

# Keep the original owner metadata in the full TAR, but suppress chown during
# extraction into the container's host-mounted rootfs. Owners are translated
# afterwards through a verified default unprivileged ID mapping.
engine_staging_restore() {
 local rootfs=$1 uidbase gidbase
 engine_need tar stat chown
 [[ -d $rootfs/etc && -f $rootfs/etc/os-release ]] || engine_die 'Seed-Rootfs unvollständig'
 [[ -n ${GUEST_MOUNT:-} && -f $GUEST_MOUNT/etc/os-release ]] || engine_die 'Quell-Mount ist nicht mehr verfügbar'
 uidbase=$(stat -c %u "$rootfs/etc/os-release") || engine_die 'UID-Basis nicht ermittelbar'
 gidbase=$(stat -c %g "$rootfs/etc/os-release") || engine_die 'GID-Basis nicht ermittelbar'
 [[ $uidbase == 100000 && $gidbase == 100000 ]] || engine_die "Nicht unterstützte ID-Basis: $uidbase:$gidbase"
 if pct config "$CTID" | grep -q '^lxc.idmap:'; then
  engine_die 'Benutzerdefiniertes lxc.idmap wird vom vereinfachten Import nicht unterstützt'
 fi
 [[ -z $OWNER_MAP_FILE ]] || engine_die 'Explizite Owner-Maps benötigen die derzeit deaktivierte detailgenaue Wiederherstellung'
 engine_warn 'SCHNELLIMPORT: Keine Einzeldatei-UID/GID-, ACL- oder Xattr-Prüfung. Original-Metadaten bleiben im TAR.'
 engine_warn 'Alle extrahierten Einträge erhalten zunächst Container-root als Eigentümer; Dienstkonten und spezielle Rechte nach Import prüfen.'
 engine_info '[PROGRESS] phase=extract'
 tar --numeric-owner --no-same-owner --no-same-permissions \
   --delay-directory-restore --no-overwrite-dir \
   -C "$rootfs" -xpf "$guest_archive" || engine_die 'Staging-Extraktion fehlgeschlagen'
 engine_info '[PROGRESS] phase=owner_baseline'
 # Proxmox exposes an unprivileged rootfs via a host mount: container UID 0
 # corresponds to host UID 100000 under the supported default ID mapping.
 # This is a deliberately lossy temporary compatibility mode. Never touch the source.
 chown -R -h -- "$uidbase:$gidbase" "$rootfs" || engine_die 'Container-root Eigentümerbasis fehlgeschlagen; CT bleibt gestoppt'
 engine_info 'Vereinfachte Eigentümerbasis gesetzt. Detaillierte Rechte bleiben im Original-TAR gesichert.'
}

# Run Proxmox worker commands through a dedicated controlling PTY.
# The TUI launches the engine in a detached session, which otherwise causes
# "failed to tcsetpgrp" / "got no worker upid" on some PVE versions.
# All command arguments are passed as positional parameters, shell-quoted, and
# never evaluated as raw user-supplied shell fragments.
engine_pve_worker() {
 local command_string='' quoted arg
 engine_need script
 (($# > 0)) || engine_die 'PTY worker: command missing'
 for arg in "$@"; do
  printf -v quoted '%q' "$arg"
  command_string+="${command_string:+ }${quoted}"
 done
 # Announce a worker before launch so the TUI can attach the real PVE task log.
 if [[ ${1:-} == pct && ${2:-} == create ]]; then
  engine_info "[TASK] type=vzcreate vmid=${3:-} since=$(date +%s)"
 elif [[ ${1:-} == pct && ${2:-} == start ]]; then
  engine_info "[TASK] type=vzstart vmid=${3:-} since=$(date +%s)"
 elif [[ ${1:-} == qm && ${2:-} == shutdown ]]; then
  engine_info "[TASK] type=qmshutdown vmid=${3:-} since=$(date +%s)"
 fi
 script -q -e -c "$command_string" /dev/null </dev/null
}

# Proxmox worker commands can require a controlling terminal. The TUI migration
# runs in a detached process group, so create a dedicated PTY for qm shutdown.
# IMPORTANT: never force-stop a running guest if the graceful shutdown fails.
engine_shutdown_vm() {
 local state attempt
 engine_info "Fordere kontrollierten Shutdown fuer VM $VMID an (PTY)."
 # VMID is strictly numeric (validated by engine_parse), avoiding shell injection.
 if ! engine_pve_worker qm shutdown "$VMID" --timeout 180; then
  engine_die "Proxmox-Shutdown fehlgeschlagen. Status mit qm status $VMID pruefen; kein qm stop ausgefuehrt."
 fi
 for ((attempt=0;attempt<15;attempt++)); do
  state=$(qm status "$VMID" 2>/dev/null | awk '{print $2}') || state='unknown'
  [[ $state == stopped ]] && { engine_info "VM $VMID ist gestoppt."; return 0; }
  sleep 1
 done
 engine_die "Shutdown gemeldet, aber VM $VMID ist nicht nachweislich gestoppt. Lesezugriff auf Datentraeger verweigert."
}

engine_request_root_hash() {
 local hash='' first='' second='' count
 engine_need openssl
 if [[ -n ${ENGINE_CONFIRM_REQ:-} && -n ${ENGINE_CONFIRM_RESP:-} ]]; then
  # The UI reads both hidden password entries, hashes them and sends only
  # an SHA-512 crypt hash over the private control FIFO. Never write it to logs.
  printf 'ROOTPASSWORD|%s\n' "$CTID" > "$ENGINE_CONFIRM_REQ" || engine_die 'Passwortdialog nicht erreichbar'
  IFS= read -r hash < "$ENGINE_CONFIRM_RESP" || engine_die 'Passwortdialog nicht erreichbar'
 else
  for ((count=1;count<=3;count++)); do
   printf 'Neues LXC-root-Passwort (mindestens 8 Zeichen): ' > /dev/tty
   IFS= read -rs first </dev/tty || engine_die 'Passwortdialog abgebrochen'
   printf '\nPasswort wiederholen: ' > /dev/tty
   IFS= read -rs second </dev/tty || engine_die 'Passwortdialog abgebrochen'
   printf '\n' > /dev/tty
   if (( ${#first} >= 8 )) && [[ $first == "$second" ]]; then
    hash=$(printf '%s\n' "$first" | openssl passwd -6 -stdin) || engine_die 'Passwort-Hash fehlgeschlagen'
    first='' second=''
    break
   fi
   first='' second=''
   printf 'Passwörter stimmen nicht überein oder sind zu kurz.\n' > /dev/tty
  done
 fi
 [[ $hash =~ ^\$6\$[a-zA-Z0-9./$]+$ ]] || engine_die 'Kein gültiges Passwort erhalten; Ziel bleibt gestoppt'
 GC_ROOT_HASH=$hash
}

engine_select_nesting() {
 local version label
 gc_systemd_version "$GUEST_MOUNT"
 ENGINE_NESTING=0
 if ((GC_SYSTEMD_PRESENT)); then
  version=$GC_SYSTEMD_VERSION
  engine_info "Gast-Init: systemd ${version}"
  if [[ $NESTING_CHOICE == on ]]; then ENGINE_NESTING=1
  elif [[ $NESTING_CHOICE == off ]]; then ENGINE_NESTING=0
  elif [[ $version =~ ^[0-9]+$ ]] && ((version > 241)); then
   engine_warn "systemd $version: Nesting wird für die LXC-Konsole und Dienst-Isolation empfohlen."
   if engine_decision "systemd $version erkannt: Nesting aktivieren (empfohlen)?"; then ENGINE_NESTING=1; fi
  elif [[ $version == unknown ]]; then
   engine_warn 'systemd erkannt, Version nicht zuverlässig bestimmbar. Nesting optional (standardmäßig AUS).'
   if engine_decision 'systemd-Version unbekannt: Nesting aktivieren?'; then ENGINE_NESTING=1; fi
  fi
 else
  engine_info 'Kein systemd-Init erkannt; Nesting bleibt standardmäßig aus.'
  [[ $NESTING_CHOICE != on ]] || ENGINE_NESTING=1
 fi
 engine_info "Nesting-Auswahl: $ENGINE_NESTING"
}

engine_convert() {
 # Required on every supported PVE host; fail before shutting down the VM.
 engine_need openssl
 openssl passwd -6 -stdin </dev/null >/dev/null 2>&1 || engine_die "OpenSSL ohne SHA-512 crypt-Unterstützung: Passwort kann nicht gesetzt werden"
 engine_started_log
 engine_preflight
 engine_info "Start: $(date -Is)"
 engine_confirm "Offline-Migration VM $VMID nach CT $CTID vorbereiten?"
 if [[ $(qm status "$VMID" | awk '{print $2}') != stopped ]]; then
  [[ $SHUTDOWN == 1 ]] || engine_die 'VM läuft. Für geplantes Herunterfahren --shutdown angeben oder VM selbst stoppen.'
  engine_confirm "VM $VMID kontrolliert herunterfahren?"
  engine_shutdown_vm
  [[ $(qm status "$VMID" | awk '{print $2}') == stopped ]] || engine_die 'VM nicht gestoppt – LXC-Start verboten'
 fi
 # Revalidate the OFFLINE image after the shutdown; a guest agent is not a disk check.
 engine_guest_inspect
 # Lock against multiple converters; source stays intact.
 local diskargs=() disk guest_archive
 for disk in "${DISK_PATHS[@]}"; do diskargs+=(-a "$disk"); done
 ENGINE_CT_CREATE_ATTEMPTED=0 ENGINE_MIGRATION_READY=0 ENGINE_CLEANUP_FAILED=0 CT_STAGING_MOUNTED=0
 GUEST_MOUNT=$(mktemp -d "$ENGINE_ROOT/guest-${VMID}-XXXXXXXX")
 engine_install_cleanup_traps
 engine_info 'Gast-Filesysteme werden READ-ONLY eingehängt.'
 guestmount --ro "${diskargs[@]}" -i "$GUEST_MOUNT" || engine_die 'Gastmount fehlgeschlagen. Quelle bleibt unverändert.'
 engine_mount_is_active "$GUEST_MOUNT" || engine_die 'guestmount meldet Erfolg, aber der Quell-Mount ist nicht in der Mount-Tabelle sichtbar'
 [[ -f "$GUEST_MOUNT/etc/os-release" ]] || engine_die 'Gast-Root enthält keine /etc/os-release'
 local osid
 osid=$(sed -n 's/^ID=//p' "$GUEST_MOUNT/etc/os-release" | head -1 | tr -d '"')
 engine_info "Distribution: $osid"
 engine_select_nesting
 guest_archive=$(mktemp "$ARCHIVE_DIR/pve-vm2lxc-${VMID}-XXXXXX.tar")
 # Do not glob-exclude user data based on extension; no '*.sql', '*.gz' etc.
 engine_info "Schreibe TAR-Archiv: $guest_archive"
 # No expensive full FUSE traversal just to estimate progress.
 # TARGET_SIZE is a capacity reference, NOT a prediction of TAR bytes or ETA.
 local capacity_bytes=$((TARGET_SIZE * 1024 * 1024 * 1024))
 engine_info "[PROGRESS] archive=$guest_archive"
 engine_info "[PROGRESS] capacity_bytes=$capacity_bytes"
 engine_info '[PROGRESS] phase=archive'
 tar --sparse --acls --xattrs --xattrs-include='*' --numeric-owner --warning=no-file-changed \
   --exclude='./proc' --exclude='./sys' --exclude='./dev' --exclude='./run' \
   --exclude='./mnt/pve-vm2lxc' \
   -C "$GUEST_MOUNT" -cpf "$guest_archive" . || engine_die 'Archiv fehlgeschlagen – Quelle nicht verändert'
 engine_info "Archiv erstellt: $(du -h "$guest_archive" | awk '{print $1}')"
 local archive_bytes target_bytes
 archive_bytes=$(stat -c %s "$guest_archive")
 target_bytes=$((TARGET_SIZE * 1024 * 1024 * 1024))
 ((archive_bytes < target_bytes * 90 / 100)) || engine_die "Datenumfang des Archivs ist für die Zielgröße zu groß; mehr Platz wählen. Archiv bleibt erhalten."
 engine_confirm "CT $CTID aus dem Archiv auf $TARGET_STORAGE erstellen?"
 local hostarg=() rootfs='' seed_os=''
 [[ -n $HOSTNAME ]] && hostarg=(--hostname "$HOSTNAME")
 # No network configured during import. CT remains stopped.
 # Bootstrap template is intentionally small; this avoids Proxmox's tar owner
 # restoration rejecting source IDs outside the default unprivileged uidmap.
 # Restore the FULL archive into the mounted rootfs in a separate operation.
 engine_build_seed "$GUEST_MOUNT"
 # CRITICAL: Keep the source guestmount alive until staging extraction and initial ownership setup
 # completes. Previously it was unmounted here, leaving seed-only CTs.
 engine_info '[PROGRESS] phase=seed_create'
 engine_info 'Quell-Dateisystem bleibt bis zum abgeschlossenen Staging-Import eingehängt.'
 engine_info "Proxmox-Worker: pct create CT $CTID aus neutralem Seed-Archiv (PTY)."
 ENGINE_CT_CREATE_ATTEMPTED=1
 engine_pve_worker pct create "$CTID" "$ENGINE_SEED_ARCHIVE" --rootfs "$TARGET_STORAGE:$TARGET_SIZE" \
   --ostype unmanaged --memory "$HW_MEMORY" --cores "$HW_CORES" --swap "$HW_SWAP" \
   --unprivileged 1 --onboot 0 "${hostarg[@]}" || engine_die 'pct create Seed fehlgeschlagen. CT eventuell gesperrt; Proxmox-Tasklog prüfen.'
 ENGINE_CT_CREATED=1
 [[ $(pct status "$CTID") == 'status: stopped' ]] || engine_die 'Neuer Container ist nicht gestoppt – kein Restore'
 engine_info 'Hänge das neue CT-Rootfs ausschließlich für den Staging-Import ein.'
 engine_pve_worker pct mount "$CTID" || engine_die 'pct mount fehlgeschlagen'
 CT_STAGING_MOUNTED=1
 rootfs="/var/lib/lxc/$CTID/rootfs"
 [[ -d $rootfs ]] || engine_die "Das Proxmox-Rootfs-Verzeichnis fehlt: $rootfs"
 engine_staging_restore "$rootfs"
 [[ -f $rootfs/etc/os-release ]] || engine_die 'Restore unvollständig: etc/os-release fehlt'
 # A seed-only rootfs is not a valid restored Linux system.
 if [[ ! -e $rootfs/sbin/init && ! -e $rootfs/lib/systemd/systemd && ! -e $rootfs/usr/lib/systemd/systemd ]]; then
  engine_die 'Restore nicht startbereit: bekannter Init-Pfad fehlt; Ziel bleibt gestoppt'
 fi
 engine_info '[PROGRESS] phase=root_password'
 engine_request_root_hash
 gc_set_root_hash "$rootfs" "$GC_ROOT_HASH" || engine_die 'Root-Passwort konnte nicht sicher in /etc/shadow gesetzt werden; Container bleibt gestoppt'
 GC_ROOT_HASH=''
 engine_info 'Neues LXC-root-Passwort im gestoppten Container gesetzt (nicht protokolliert).'
 engine_info '[PROGRESS] phase=restore_verified'
 engine_release_guest_mount || engine_die 'Quell-Mount konnte nicht vollstaendig freigegeben werden'
 engine_pve_worker pct unmount "$CTID" || engine_die 'pct unmount fehlgeschlagen'
 CT_STAGING_MOUNTED=0
 engine_info 'LXC-Rootfs vollständig wiederhergestellt; Konfiguration folgt.'
 # Only select the distribution-specific CT setup after the original system
 # is fully restored. The bootstrap archive may lack distro-specific files.
 if [[ $ENGINE_CT_OS != unmanaged ]]; then
  engine_pve_worker pct set "$CTID" --ostype "$ENGINE_CT_OS" || engine_die 'CT-OS-Typ konnte nach Restore nicht gesetzt werden; CT bleibt gestoppt'
 fi
 [[ -z $HW_CPULIMIT ]] || engine_pve_worker pct set "$CTID" --cpulimit "$HW_CPULIMIT" || engine_die 'CPU-Limit konnte nicht gesetzt werden'
 [[ -z $HW_CPUUNITS ]] || engine_pve_worker pct set "$CTID" --cpuunits "$HW_CPUUNITS" || engine_die 'CPU-Gewichtung konnte nicht gesetzt werden' 
 # Apply the explicit nesting choice while the CT is stopped. Verify it
 # immediately so no warning is mistaken for a successful configuration.
 gc_apply_nesting "$CTID" "$ENGINE_NESTING" || engine_die 'Nesting-Konfiguration konnte nicht gesetzt oder verifiziert werden'
 engine_info "Nesting verifiziert: ${ENGINE_NESTING}"
 # Pass explicitly selected, verified host device nodes to the *stopped* LXC.
 # A devN exposes a node, NOT a full PCI controller or QEMU USB emulation.
 local devkey devpath devnum=0
 for devkey in $(printf '%s\n' "${!DEVICE_MAPS[@]}" | sort); do
  [[ -n $devkey ]] || continue
  devpath=${DEVICE_MAPS[$devkey]}
  hw_valid_node "$devpath" || engine_die "Host-Gerät für $devkey fehlt: $devpath (CT bleibt gestoppt)"
  engine_pve_worker pct set "$CTID" "--dev${devnum}" "path=${devpath}" || engine_die "LXC dev${devnum} für $devkey fehlgeschlagen"
  engine_info "LXC dev${devnum}: $devkey -> $devpath. Zugriff und Gruppenrechte müssen im Container geprüft werden."
  ((devnum+=1))
 done
 local i
 for ((i=0;i<${#NET_ARGS[@]};i+=2)); do
   engine_pve_worker pct set "$CTID" "${NET_ARGS[i]}" "${NET_ARGS[i+1]}" || engine_die 'NIC-Konfiguration fehlgeschlagen – Container NICHT starten'
 done
 if [[ -n $NAMESERVERS ]]; then
  engine_pve_worker pct set "$CTID" --nameserver "$NAMESERVERS" || engine_die 'DNS-Konfiguration fehlgeschlagen – Container NICHT starten'
 fi
 engine_pve_worker pct set "$CTID" --description "Migration from VM $VMID; original VM retained; verify before starting" || :
 # Network configuration must be present before reporting successful conversion.
 local actual_ct_config netindex
 actual_ct_config=$(pct config "$CTID") || engine_die 'CT-Konfiguration nicht lesbar'
 for ((i=0;i<${#NET_ARGS[@]};i+=2)); do
  [[ ${NET_ARGS[i]} =~ ^--net([0-9]+)$ ]] || engine_die 'Ungültiger Netzwerkindex'
  netindex=${BASH_REMATCH[1]}
  grep -q "^net${netindex}: " <<< "$actual_ct_config" || engine_die "net${netindex} fehlt im Zielcontainer"
 done
 engine_info '[PROGRESS] phase=network_verified'
 engine_warn 'ACHTUNG: VM-spezifische Init-/Netzwerk-/fstab-Konfigurationen müssen vor einem Start geprüft werden.'
 engine_warn 'Automatischer LXC-Start ist bewusst gesperrt, bis Gast-/Mount-/Netzwerk-Semantik verifiziert ist.'
 engine_info "Ergebnis: CT $CTID angelegt, stopped. Original-VM $VMID bleibt erhalten und stopped."
 engine_info "Archiv bleibt für Review: $guest_archive"
 ENGINE_MIGRATION_READY=1
}
engine_check_mac_conflicts() {
 local ctconf mac vmline ctid line conf id status
 ctconf=$(pct config "$CTID")
 while IFS= read -r mac; do
  [[ -n $mac ]] || continue
  # Only running guests are relevant for a live layer-2 collision.
  while read -r id _; do
   [[ $id =~ ^[0-9]+$ && $id != "$VMID" ]] || continue
   status=$(qm status "$id" 2>/dev/null || :)
   [[ $status == 'status: running' ]] || continue
   conf=$(qm config "$id" 2>/dev/null || :)
   if grep -Fqi "$mac" <<< "$conf"; then engine_die "MAC $mac auch in laufender VM $id vorhanden"; fi
  done < <(qm list | tail -n +2)
  while read -r id _; do
   [[ $id =~ ^[0-9]+$ && $id != "$CTID" ]] || continue
   status=$(pct status "$id" 2>/dev/null || :)
   [[ $status == 'status: running' ]] || continue
   conf=$(pct config "$id" 2>/dev/null || :)
   if grep -Fqi "$mac" <<< "$conf"; then engine_die "MAC $mac auch in laufendem LXC $id vorhanden"; fi
  done < <(pct list | tail -n +2)
 done < <(grep -oEi 'hwaddr=[[:xdigit:]:]{17}' <<< "$ctconf" | cut -d= -f2)
}
engine_activate() {
 engine_need qm pct
 [[ $(id -u) == 0 ]] || engine_die "Root erforderlich"
 qm config "$VMID" >/dev/null || engine_die "VM fehlt"
 pct config "$CTID" >/dev/null || engine_die "Container fehlt"
 [[ $(qm status "$VMID" | awk '{print $2}') == stopped ]] || engine_die "Quell-VM ist noch aktiv; Start verboten"
 [[ $(pct status "$CTID" | awk '{print $2}') == stopped ]] || engine_die "Ziel-LXC ist nicht gestoppt"
 local ctconf; ctconf=$(pct config "$CTID")
 grep -Fq "Migration from VM $VMID;" <<< "$ctconf" || engine_die "CT gehört nicht nachweislich zu VM $VMID"
 if qm config "$VMID" | grep -Eq "^onboot: 1$"; then engine_die "Quell-VM hat onboot=1. Erst Abschalten der Autostartfunktion bestätigen und manuell konfigurieren"; fi
 if command -v ha-manager >/dev/null && ha-manager config 2>/dev/null | grep -Eq "vm:$VMID([[:space:]]|$)"; then engine_die "VM wird von Proxmox HA verwaltet; Umschaltung erst nach HA-Anpassung"; fi
 engine_check_mac_conflicts
 engine_started_log
 engine_confirm "LXC $CTID mit geklonter MAC/IP starten? Quelle VM $VMID muss aus bleiben."
 [[ $(qm status "$VMID" | awk '{print $2}') == stopped ]] || engine_die "VM hat während der Freigabe gestartet"
 engine_pve_worker pct start "$CTID" || engine_die "Start fehlgeschlagen; Quell-VM bleibt unverändert gestoppt"
 pct status "$CTID"
 engine_info "LXC gestartet. Dienste, Gastnetzwerk und Datenintegrität jetzt prüfen. KEIN automatischer Erfolg behauptet."
}
# Destructive removal is deliberately not part of the migration transaction.
# An explicit, separately invoked, verified finalize command offers the choice.
engine_finalize() {
 engine_need qm pct
 local vm=$1 ct=$2 answer
 [[ $vm =~ ^[0-9]+$ && $ct =~ ^[0-9]+$ && $vm != "$ct" ]] || engine_die 'Gültige VMID und CTID erforderlich'
 qm config "$vm" >/dev/null || engine_die 'Quell-VM fehlt'
 pct config "$ct" >/dev/null || engine_die 'Ziel-CT fehlt'
 [[ $(qm status "$vm" 2>/dev/null) == 'status: stopped' ]] || engine_die 'Quell-VM muss gestoppt sein'
 [[ $(pct status "$ct" 2>/dev/null) == 'status: running' ]] || engine_die 'Ziel-CT muss gestartet und vorab vollständig geprüft sein'
 pct config "$ct" | grep -Fq "Migration from VM $vm;" || engine_die 'CT ist nicht als Migration dieser VM gekennzeichnet'
 echo "WARNUNG: Die Datenintegrität und Anwendungen können nicht automatisch vollständig zertifiziert werden."
 echo "Quell-VM $vm bleibt standardmäßig erhalten."
 engine_confirm "Quell-VM $vm wirklich endgültig löschen (nach extern geprüftem Backup)?"
 read -r -p "Zur Bestätigung VM-ID erneut eingeben: " answer </dev/tty || engine_die 'Abbruch'
 [[ $answer == "$vm" ]] || engine_die 'VM-ID stimmt nicht überein'
 [[ $(qm status "$vm" 2>/dev/null) == 'status: stopped' ]] || engine_die 'VM wurde zwischenzeitlich gestartet'
 if qm config "$vm" | grep -Eq '^lock:|^template: 1$'; then engine_die 'VM gesperrt oder Template'; fi
 if command -v ha-manager >/dev/null && ha-manager config 2>/dev/null | grep -Eq "vm:$vm([[:space:]]|$)"; then engine_die 'HA-verwalterte VM: vorher aus HA nehmen'; fi
 # Never remove archives or backups. qm destroy is explicitly irreversible.
 engine_pve_worker qm destroy "$vm" || engine_die 'VM-Löschung fehlgeschlagen'
 engine_info "VM $vm wurde nach separater Bestätigung gelöscht. Backups und Archive bleiben unverändert."
}

engine_main() {
 local sub=${1:-help}; shift || :
 case $sub in
   plan|convert) engine_parse "$@"; if [[ $sub == plan ]]; then [[ $ENGINE_DEBUG == 1 ]] && engine_started_log; engine_preflight; else engine_convert; fi;;
   finalize) local fvm='' fct=''; while (($#)); do case $1 in --vmid) fvm=${2:?}; shift 2;; --ctid) fct=${2:?}; shift 2;; *) engine_die "Unbekannte finalize-Option: $1";; esac; done; VMID=$fvm; CTID=$fct; engine_started_log; engine_finalize "$fvm" "$fct";;
   activate) VMID="" CTID=""; while (($#)); do case $1 in --vmid) VMID=$2;shift 2;; --ctid) CTID=$2;shift 2;; --debug) ENGINE_DEBUG=1;shift;; *) engine_die "Unbekannte activate-Option: $1";; esac; done; [[ $VMID =~ ^[0-9]+$ && $CTID =~ ^[0-9]+$ ]] || engine_die "--vmid und --ctid erforderlich"; engine_activate;;
   help|-h|--help) cat <<'HELP'
Usage:
  pve-vm2lxc plan    --vmid ID --ctid ID --storage NAME --size GiB --archive-dir PATH --ip-net0 CIDR|dhcp [--gw-net0 IP] [--ip-net1 ...]
  pve-vm2lxc activate --vmid ID --ctid ID [--debug]
  pve-vm2lxc finalize --vmid ID --ctid ID # separate, optional deletion
  pve-vm2lxc convert --vmid ID --ctid ID --storage NAME --size GiB --archive-dir PATH --ip-net0 CIDR|dhcp [--ip6-net0 auto|dhcp|CIDR] [--gw6-net0 IP] [--shutdown] [--debug]

Note: --owner-map-file is temporarily disabled in simplified import mode.
--nesting auto|on|off (auto offers nesting for systemd >241); root password is mandatory.
Offline-import: preserves source disk, creates an unprivileged stopped CT; no auto-start.
--debug: repeat each y/n confirmation; detailed audit log.
HELP
   ;;
   *) engine_die "Unbekannter Befehl: $sub";;
 esac
}
