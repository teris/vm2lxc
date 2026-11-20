#!/usr/bin/env bash
# PVE VM2LXC 0.2.1 - interactive, fail-closed migration assistant
# SPDX-License-Identifier: MIT
set -Eeuo pipefail
IFS=$'\n\t'
VERSION=0.2.1
BASE_DIR=/var/lib/pve-vm2lxc
LOG_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/logs
RUN_ID=$(date -u +%Y%m%dT%H%M%SZ)-$$
VMID='' CTID='' VM_IP='' SOURCE_IF='' NET_CONFIG='' ROOT_STORE='' ROOT_GB='' TEMPLATE='' STAGE='' LOG='' TMP_PATH='' CT_MOUNTED=0
SSH_OPTS=(-o StrictHostKeyChecking=yes -o ConnectTimeout=8 -o ServerAliveInterval=20)
RSYNC_SSH="ssh -o StrictHostKeyChecking=yes -o ConnectTimeout=8 -o ServerAliveInterval=20"
DIALOG=dialog
GUEST_MOUNTS=() MOUNT_STORES=() MOUNT_SIZES=() SRC_DEVS=() MACS=() BRIDGES=() IPS=() GWS=() IFACES=()

msg() { "$DIALOG" --title 'PVE VM → LXC' --msgbox "$1" 12 86; }
die() { printf 'FEHLER: %s\n' "$*" >&2; [[ -n $LOG ]] && printf '[ERROR] %s\n' "$*" >> "$LOG"; exit 1; }
log() { printf '[%s] %s\n' "$(date -Is)" "$*" | tee -a "$LOG" >&2; }
ask() { "$DIALOG" --stdout --title 'PVE VM → LXC' --inputbox "$1" 12 85 "${2:-}"; }
confirm() { "$DIALOG" --title 'PVE VM → LXC' --yes-label 'Ja' --no-label 'Nein' --yesno "$1" 14 86; }
select_menu() { local title=$1; shift; "$DIALOG" --stdout --title "$title" --menu 'Mit Pfeiltasten auswählen, Enter bestätigen' 22 100 13 "$@"; }
require() { local x; for x in "$@"; do command -v "$x" >/dev/null || die "Benötigtes Programm fehlt: $x"; done; }
check_root() { [[ $EUID -eq 0 ]] || die 'Bitte als root auf einem Proxmox-Host starten.'; }
init() {
  check_root; require qm pct pvesm pveam rsync ssh "$DIALOG" awk sed grep findmnt df du ip
  mkdir -p "$BASE_DIR" "$LOG_DIR"
  LOG="$LOG_DIR/$RUN_ID.log"; : > "$LOG"; chmod 600 "$LOG"
  trap 'on_exit $?' EXIT
}
on_exit() {
  local rc=$1
  if (( CT_MOUNTED )); then pct unmount "$CTID" >>"$LOG" 2>&1 || true; fi
  if [[ $rc -ne 0 && -n $LOG ]]; then printf '[%s] Unvollständiger Lauf (rc=%d). Quell-VM wurde vom Fehlerhandler NICHT gestartet oder verändert.\n' "$(date -Is)" "$rc" >>"$LOG"; fi
}
check_id() { [[ $1 =~ ^[1-9][0-9]{1,8}$ ]] || die "Ungültige Proxmox-ID: $1"; }
# QEMU ostype is only a prefilter; an actual Linux guest is verified over SSH.
vm_os_hint() {
  local id=$1 cfg
  cfg=$(qm config "$id" 2>/dev/null) || return 1
  case $(awk -F': ' '$1=="ostype" {print $2; exit}' <<<"$cfg") in
    l24|l26) printf 'Linux (noch nicht verifiziert)' ;;
    win*|wvista|w2k*|wxp) printf 'Windows – ausgeschlossen' ;;
    other|'') printf 'Unbekannt – Prüfung erforderlich' ;;
    *) printf 'Nicht-Linux/Unbekannt – Prüfung erforderlich' ;;
  esac
}
list_vms() {
  local -a opt=(); local vm name stat mem hint
  while IFS=$'\t' read -r vm name stat mem; do
    [[ $vm =~ ^[0-9]+$ ]] || continue
    hint=$(vm_os_hint "$vm")
    opt+=("$vm" "$name [$stat] · ${mem} MiB · $hint")
  done < <(qm list | awk 'NR>1 {printf "%s\t%s\t%s\t%s\n",$1,$2,$3,$4}')
  ((${#opt[@]})) || die 'Keine lokalen VMs gefunden.'
  VMID=$(select_menu '1/7 · Quell-VM auswählen' "${opt[@]}") || exit 0
  check_id "$VMID"
  hint=$(vm_os_hint "$VMID")
  if [[ $hint == *ausgeschlossen* ]]; then
    msg "Die VM $VMID ist laut Proxmox als Windows konfiguriert. Eine Migration nach Linux-LXC ist ausgeschlossen."
    return 1
  fi
  [[ $(qm status "$VMID" 2>/dev/null) == *running* ]] || die 'Quell-VM muss für SSH-Analyse und Vorsynchronisierung laufen.'
  log "Quell-VM $VMID gewählt (OS-Hinweis: $hint)"
}

select_ct() {
  CTID=$(ask 'Neue, noch freie LXC-ID:' "$(pvesh get /cluster/nextid --output-format text 2>/dev/null | tr -cd '0-9' || true)") || exit 0
  check_id "$CTID"; [[ ! -e /etc/pve/lxc/$CTID.conf && ! -e /etc/pve/qemu-server/$CTID.conf ]] || die "ID $CTID bereits belegt"
}
select_root_storage() {
  local -a opt=(); local name type stat total used avail pct
  while IFS=$'\t' read -r name type stat total used avail pct; do
    [[ $name == Name || -z $name ]] && continue
    [[ $stat == active ]] || continue
    [[ $(pvesm status --content rootdir 2>/dev/null | awk -v n="$name" '$1==n {print $1}') == "$name" ]] || continue
    opt+=("$name" "$type · frei ${avail} KiB")
  done < <(pvesm status | awk 'NR>1 {printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n",$1,$2,$3,$4,$5,$6,$7}')
  ((${#opt[@]})) || die 'Kein aktiver Storage mit Inhaltstyp rootdir gefunden.'
  ROOT_STORE=$(select_menu '3/7 · LXC-Rootfs Storage' "${opt[@]}") || exit 0
}
select_template() {
  local -a options=(); local vol size other
  while IFS=' ' read -r vol size other; do
    [[ $vol == *debian-13* && $vol == *tar* ]] && options+=("$vol" "Debian 13 Template")
  done < <(pveam list local 2>/dev/null | tail -n +2)
  if ((${#options[@]})); then
    TEMPLATE=$(select_menu '2/7 · Debian-13-Template als LXC-Basis' "${options[@]}") || exit 0
  else
    msg 'Kein lokales Debian-13-Template gefunden. Bitte zuerst über Proxmox ein Debian-13-LXC-Template herunterladen.'
    exit 1
  fi
}
ssh_guest() { ssh "${SSH_OPTS[@]}" "root@$VM_IP" "$@"; }
validate_ssh() {
  VM_IP=$(ask 'IP-Adresse der Quell-VM für SSH (z. B. 10.77.0.118):') || exit 0
  [[ $VM_IP =~ ^[0-9a-fA-F:.]+$ ]] || die 'Ungültiges IP-Format'
  msg 'SSH muss vom Proxmox-Host zur VM bereits funktionieren. Host-Keys werden strikt geprüft; Passwörter werden nicht gespeichert. Bitte SSH-Key oder SSH-Agent bereitstellen.'
  ssh_guest 'id -u' >"$BASE_DIR/$RUN_ID.ssh" || die 'SSH zur Quell-VM fehlgeschlagen.'
  [[ $(cat "$BASE_DIR/$RUN_ID.ssh") == 0 ]] || die 'SSH benötigt Root-Berechtigung.'
  rm -f "$BASE_DIR/$RUN_ID.ssh"
  local guest_id
  guest_id=$(ssh_guest 'test -r /etc/os-release && . /etc/os-release && printf "%s|%s" "${ID:-}" "${VERSION_ID:-}"' 2>/dev/null) || die 'Gastbetriebssystem nicht bestätigt: /etc/os-release fehlt oder ist unlesbar.'
  [[ $guest_id == *'|'* && $guest_id != '|' ]] || die 'Linux-Betriebssystemidentität nicht verifizierbar.'
  log "Linux-Gast bestätigt: $guest_id; SSH Root geprüft"
}
# Get VM NICs and match by actual MAC inside Linux. Guest IP and GW remain manual-review items.
discover_nics() {
  local raw key val mac bridge line guest nic ip4 gw4 mask id opts
  while IFS= read -r line; do
    [[ $line =~ ^net[0-9]+: ]] || continue
    key=${line%%:*}; val=${line#*: }
    mac=$(grep -oE '([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}' <<<"$val" | head -1 || true)
    bridge=$(grep -oE 'bridge=[A-Za-z0-9_.-]+' <<<"$val" | head -1 | cut -d= -f2 || true)
    [[ -n $mac && -n $bridge ]] || die "$key: MAC oder Bridge fehlt; Automatik abgebrochen"
    guest=$(ssh_guest "for n in /sys/class/net/*; do [ \"\$(cat \"\$n/address\" 2>/dev/null)\" = '${mac,,}' ] && basename \"\$n\"; done" 2>/dev/null | head -1 || true)
    [[ -n $guest ]] || die "MAC $mac im Gast nicht gefunden; manuell prüfen."
    ip4=$(ssh_guest "ip -o -4 addr show dev '$guest' scope global | awk 'NR==1 {print \$4}'" || true)
    gw4=$(ssh_guest "ip -4 route show default dev '$guest' | awk 'NR==1 {print \$3}'" || true)
    [[ -n $ip4 ]] || die "Keine IPv4-Adresse für $guest ($mac); kein stiller DHCP-Fallback"
    MACS+=("${mac,,}"); BRIDGES+=("$bridge"); IPS+=("$ip4"); GWS+=("$gw4"); IFACES+=("$guest")
    log "$key bridge=$bridge hwaddr=${mac,,} guest=$guest ip=$ip4 gw=${gw4:-none}"
  done < <(qm config "$VMID")
  ((${#MACS[@]})) || die 'Keine unterstützte VM-NIC gefunden.'
}
list_mounts() {
  local raw target source fstype opts used gb size idx
  # JSON-free stable parsing: no whitespace in mountpoints supported (abort).
  raw=$(ssh_guest "findmnt -rn -o TARGET,SOURCE,FSTYPE -t ext4,xfs,btrfs" || true)
  while IFS=' ' read -r target source fstype; do
    [[ $target == / ]] && continue
    [[ $target == /boot* ]] && continue
    [[ $target == /var/lib/docker* ]] && continue
    [[ $target == /* && $target != *' '* ]] || continue
    GUEST_MOUNTS+=("$target")
    SRC_DEVS+=("$source")
  done <<< "$raw"
  log "Zusätzliche Dateisysteme erkannt: ${GUEST_MOUNTS[*]:-keine}"
}
choose_sizes() {
  local used suggested val mount i
  used=$(ssh_guest "du -sxBG / 2>/dev/null | awk '{gsub(/G/,\"\",\$1); print \$1}'" || true)
  [[ $used =~ ^[0-9]+$ ]] || die 'Rootfs-Belegung nicht ermittelbar'
  suggested=$(( used + used / 4 + 8 ))
  ROOT_GB=$(ask "Rootfs-Größe in GiB. Aktuell ca. $used GiB belegt (andere Mounts ausgeschlossen). Verkleinern nur über ausreichende freie Kapazität!" "$suggested") || exit 0
  [[ $ROOT_GB =~ ^[1-9][0-9]*$ ]] && (( ROOT_GB > used + 2 )) || die 'Rootfs kleiner als sichere Mindestgröße.'
  local -a opts=(); local storage
  for ((i=0;i<${#GUEST_MOUNTS[@]};i++)); do
    mount=${GUEST_MOUNTS[$i]}
    if confirm "Zusätzliches Dateisystem $mount (${SRC_DEVS[$i]}) als separates LXC-Volume übernehmen?\n\nNein = Migration aus Sicherheitsgründen abbrechen, NICHT überspringen."; then
      local size
      size=$(ssh_guest "du -sxBG '$mount' 2>/dev/null | awk '{gsub(/G/,\"\",\$1); print \$1}'") || die "Größe von $mount nicht lesbar"
      [[ $size =~ ^[0-9]+$ ]] || die "Größe von $mount nicht parsebar"
      local desired=$((size + size/4 + 5))
      local new_size
      new_size=$(ask "Volume $mount: ungefähr $size GiB belegt; neue Größe (GiB):" "$desired") || exit 0
      [[ $new_size =~ ^[1-9][0-9]*$ ]] && (( new_size > size + 1 )) || die 'Volume zu klein'
      GUEST_MOUNTS[$i]=$mount; MOUNT_SIZES+=("$new_size")
      # This storage is asked separately; default root storage, and validated with pvesm.
      storage=$(ask "Storage für $mount (rootdir-fähig):" "$ROOT_STORE") || exit 0
      [[ $(pvesm status --storage "$storage" --content rootdir 2>/dev/null | awk 'NR>1 {print $1}') == "$storage" ]] || die "Storage $storage unterstützt kein rootdir"
      MOUNT_STORES+=("$storage")
    else
      die "Mount $mount wurde nicht zugeordnet. Migration abgebrochen."
    fi
  done
}
choose_temp() {
  # rsync-direct pipeline: no tar; user can place state/logs on a mounted path.
  TMP_PATH=$(ask 'Arbeitsverzeichnis für Logs/Status (bestehender Host-Mountpoint; keine kompletten Archive notwendig):' "$BASE_DIR") || exit 0
  [[ $TMP_PATH == /* && -d $TMP_PATH && ! -L $TMP_PATH ]] || die "Arbeitsverzeichnis ungültig: $TMP_PATH"
  [[ -w $TMP_PATH ]] || die "Arbeitsverzeichnis nicht beschreibbar: $TMP_PATH"
  STAGE="$TMP_PATH/pve-vm2lxc-$RUN_ID"
  mkdir -m 700 -- "$STAGE"
  log "Arbeitsverzeichnis $STAGE"
}
review() {
  local report="$STAGE/plan.txt" i
  {
    printf 'PVE VM2LXC %s – PLAN / KEINE AKTIONEN AUSGEFÜHRT\n' "$VERSION"
    printf 'Quelle VM: %s; Ziel LXC: %s; SSH: %s\n' "$VMID" "$CTID" "$VM_IP"
    printf 'Rootfs: %s:%s GiB\nTemplate: noch nicht festgelegt (Gast-OS-spezifisch)\n' "$ROOT_STORE" "$ROOT_GB"
    printf 'Weitere Dateisysteme:\n'
    for ((i=0;i<${#GUEST_MOUNTS[@]};i++)); do printf '  %s -> mp%d / %s:%s GiB\n' "${GUEST_MOUNTS[$i]}" "$i" "${MOUNT_STORES[$i]}" "${MOUNT_SIZES[$i]}"; done
    printf 'Netzwerk: gleicher MAC-Wert, IP, Bridge. Ziel NICs zunächst LINK_DOWN=1.\n'
    for ((i=0;i<${#MACS[@]};i++)); do printf '  net%d %s bridge=%s IP=%s GW=%s\n' "$i" "${MACS[$i]}" "${BRIDGES[$i]}" "${IPS[$i]}" "${GWS[$i]:--}"; done
    printf 'Quell-VM wird NUR nach eigener Bestätigung kontrolliert heruntergefahren.\n'
    printf 'LXC-Start wird verweigert solange VM läuft. Netzkonfigurationen im Gast müssen geprüft werden.\n'
    printf 'WARNUNG: IPv6, VLAN, NIC-MTU, Proxmox-Firewall, Cloud-init, Gast-Spezialdienste müssen manuell überprüft werden.\n'
    printf 'WARNUNG: Live-Rsync liefert keine konsistente Datenbank. Finales Sync nur nach Schreibstopp.\n'
  } > "$report"
  "$DIALOG" --title '6/7 · Plan prüfen' --textbox "$report" 23 112
  if ! confirm 'SICHERE V0.1: Möchtest du die Migrationsdaten als Plan speichern?\n\nDie automatische Migration ist in dieser Version bewusst NICHT freigeschaltet, weil vor einem produktiven Cutover noch eine zuverlässige Offline-Synchronisierung, UID/GID-Behandlung und Netzwerkvalidierung erforderlich sind.'; then exit 0; fi
  msg "Plan gespeichert: $report\n\nOriginal-VM unverändert. Keine CT-Datenträger oder Netzwerke erstellt."
  log "Plan gespeichert: $report"
}
show_menu() {
  local choice
  while true; do
    choice=$(select_menu 'PVE VM2LXC · Proxmox 9 · v0.2.1' \
      '1' 'Migration planen (VM auswählen, Speicher und Netzwerke)' \
      '2' 'VMs und Status anzeigen' \
      '3' 'Proxmox Storages anzeigen' \
      '4' 'Über das Projekt / Sicherheit' \
      '0' 'Beenden') || exit 0
    case $choice in
      1) list_vms; select_ct; validate_ssh; discover_nics; list_mounts; select_root_storage; choose_sizes; choose_temp; review; exit 0;;
      2) qm list > /tmp/pve-vm2lxc-list-$$; "$DIALOG" --title 'VMs' --textbox /tmp/pve-vm2lxc-list-$$ 22 100; rm -f /tmp/pve-vm2lxc-list-$$;;
      3) pvesm status > /tmp/pve-vm2lxc-storage-$$; "$DIALOG" --title 'Storages' --textbox /tmp/pve-vm2lxc-storage-$$ 22 100; rm -f /tmp/pve-vm2lxc-storage-$$;;
      4) msg 'PVE VM2LXC 0.2.1 - Konservativer Planungsassistent. Keine automatische Umschaltung. Quelle bleibt unverändert.\nGitHub-fähiges Bash-Projekt, MIT-Lizenz.\nSSH-Hostkeys werden geprüft.';;
      0) exit 0;;
    esac
  done
}
main() {
  case ${1:-tui} in
    help|--help|-h) printf 'PVE VM2LXC %s\nBenutzung: %s [tui|help|version]\n' "$VERSION" "$0"; return 0;;
    version|--version) printf '%s\n' "$VERSION"; return 0;;
  esac
  init
  case ${1:-tui} in
    tui) show_menu;;
    help|--help|-h) printf 'PVE VM2LXC %s\nBenutzung: %s [tui|help|version]\n' "$VERSION" "$0";;
    version|--version) printf '%s\n' "$VERSION";;
    *) die 'Unbekannter Modus. --help' ;;
  esac
}
main "$@"
