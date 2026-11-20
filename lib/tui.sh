#!/usr/bin/env bash
# ANSI/termios UI: uses Bash and stty, no dialog, no Python or Go required.
# SPDX-License-Identifier: MIT
UI_ESC=$'\033'; UI_RESET=$'\033[0m'; UI_BLUE=$'\033[38;5;75m'; UI_MUTED=$'\033[38;5;245m'; UI_GREEN=$'\033[38;5;78m'; UI_AMBER=$'\033[38;5;214m'; UI_WHITE=$'\033[97m'; UI_SELECTED=$'\033[48;5;24m\033[97m'; UI_BOLD=$'\033[1m'
UI_PAGE=home UI_CURSOR=0 UI_VM='' UI_STATUS='' UI_ACTIVE=1
UI_LANG=${PVE_VM2LXC_LANG:-de}
[[ $UI_LANG == de || $UI_LANG == en ]] || UI_LANG=de
ui_loc() {
 local str=$1
 [[ $UI_LANG == en ]] || { printf '%s' "$str"; return; }
 case $str in
  'Vorprüfung: fehlende Werkzeuge') printf '%s' 'Preflight: missing tools';;
  'Fehlende Pakete nach Zustimmung installieren') printf '%s' 'Install missing packages with approval';;
  'Abbrechen und zur VM zurückkehren') printf '%s' 'Cancel and return to VM';;
  'Installation nicht verfügbar') printf '%s' 'Installation unavailable';;
  'Paketinstallation bestätigen') printf '%s' 'Confirm package installation';;
  'Ja, Paketinstallation starten') printf '%s' 'Yes, install packages';;
  'Nein, abbrechen') printf '%s' 'No, cancel';;
  'Paketprüfung fehlgeschlagen') printf '%s' 'Package check failed';;
  'Unsichere Paketänderung blockiert') printf '%s' 'Unsafe package change blocked';;
  'Systemabhängigkeiten installieren') printf '%s' 'Install system dependencies';;
  'Paketinstallation fehlgeschlagen') printf '%s' 'Package installation failed';;
  'Installation fehlgeschlagen') printf '%s' 'Installation failed';;
  'Installation unvollständig') printf '%s' 'Installation incomplete';;
  'ID-Erkennung fehlgeschlagen') printf '%s' 'Could not determine CT ID';;
  'Ziel-CT-ID') printf '%s' 'Destination CT ID';;
  'Ungültige CT-ID') printf '%s' 'Invalid CT ID';;
  'CT-ID bereits vergeben') printf '%s' 'CT ID already in use';;
  'Storage-Abfrage fehlgeschlagen') printf '%s' 'Storage query failed';;
  'Keine LXC-Storages gefunden') printf '%s' 'No LXC storage found';;
  'Ziel-Storage') printf '%s' 'Destination storage';;
  'Größe des Ziel-Rootfs') printf '%s' 'Destination rootfs size';;
  'Ungültige Größe') printf '%s' 'Invalid size';;
  'Temporäres Archiv') printf '%s' 'Temporary archive';;
  'Archivverzeichnis') printf '%s' 'Archive directory';;
  'Archivpfad ungültig') printf '%s' 'Invalid archive path';;
  'Gastnetzwerk erkennen') printf '%s' 'Detect guest network';;
  'Gast-Zugriff') printf '%s' 'Guest access';;
  'SSH-Zugang konfigurieren') printf '%s' 'Configure SSH access';;
  'Ohne Anmeldung fortfahren (Netzwerke manuell festlegen)') printf '%s' 'Continue without login (unknown IPs: DHCP)';;
  'SSH-Adresse des Gastes') printf '%s' 'Guest SSH address';;
  'SSH-Benutzer') printf '%s' 'SSH username';;
  'Berechtigungen') printf '%s' 'Permissions';;
  'Benutzer besitzt sudo-Rechte') printf '%s' 'User has sudo privileges';;
  'Kein sudo verfügbar') printf '%s' 'No sudo available';;
  'SSH-Authentifizierung') printf '%s' 'SSH authentication';;
  'SSH-Schlüssel oder SSH-Agent (bevorzugt)') printf '%s' 'SSH key or SSH agent (preferred)';;
  'SSH-Passwort (benötigt sshpass)') printf '%s' 'SSH password (requires sshpass)';;
  'SSH-Passwort') printf '%s' 'SSH password';;
  'Gastnetzwerk abfragen') printf '%s' 'Read guest network';;
  'DHCP verwenden (keine sichere statische IP gefunden)') printf '%s' 'Use DHCP (no verified static IP)';;
  'Erkannte IP übernehmen (DHCP/statisch noch nicht unterschieden)') printf '%s' 'Keep detected IP (DHCP/static not yet distinguished)';;
  'Erkannte DHCP-Konfiguration übernehmen') printf '%s' 'Keep detected DHCP configuration';;
  'Aktuelle IP bewusst als statisch setzen') printf '%s' 'Explicitly set current IP as static';;
  'Statisch (Konfiguration erkannt)') printf '%s' 'Static (configuration verified)';;
  'Erkannte statische Konfiguration übernehmen') printf '%s' 'Keep detected static configuration';;
  'DHCP verwenden (statische Adresse nicht ermittelt)') printf '%s' 'Use DHCP (static IP not detected)';;
  'DHCP verwenden (Konfiguration unbekannt)') printf '%s' 'Use DHCP (configuration unknown)';;
  'Aktuelle IP als statisch setzen (nicht verifiziert)') printf '%s' 'Set current IP as static (unverified)';;
  'DHCP verwenden') printf '%s' 'Use DHCP';;
  'Erkanntes Default-Gateway') printf '%s' 'Detected default gateway';;
  'Kein Gateway für diese NIC (üblich bei internen Netzen)') printf '%s' 'No gateway for this NIC (usual for internal networks)';;
  'Gateway manuell festlegen') printf '%s' 'Specify gateway manually';;
  'Ungültiges Gateway') printf '%s' 'Invalid gateway';;
  'Aktion wählen') printf '%s' 'Select action';;
  'Nur Prüfungen ausführen (Quelle bleibt unverändert)') printf '%s' 'Run checks only (source unchanged)';;
  'Offline-Konvertierung vorbereiten (ggf. herunterfahren)') printf '%s' 'Prepare offline conversion (may shut down VM)';;
  'VM-Shutdown') printf '%s' 'VM shutdown';;
  'Kontrolliertes Herunterfahren ausdrücklich erlauben') printf '%s' 'Allow controlled shutdown';;
  'Nur konvertieren, falls VM bereits gestoppt ist') printf '%s' 'Convert only if VM is already stopped';;
  'Zusammenfassung') printf '%s' 'Summary';;
  'Ausführung bestätigen') printf '%s' 'Confirm execution';;
  'Ausgewählte Aktion starten') printf '%s' 'Start selected action';;
  'Abbrechen und zurück zur VM') printf '%s' 'Cancel and return to VM';;
  'Freie Proxmox-ID wird automatisch vorgeschlagen.') printf '%s' 'A free Proxmox ID is suggested automatically.';;
  'Bitte nur Zahlen verwenden.') printf '%s' 'Please enter digits only.';;
  'Nur aktive rootdir-fähige Proxmox-Storages werden angeboten.') printf '%s' 'Only active Proxmox storage with rootdir support is listed.';;
  'GiB. Platzbedarf aller Quelldaten und Dateisysteme vorher prüfen.') printf '%s' 'GiB. Verify required size of all source data and filesystems.';;
  'Eine positive Ganzzahl in GiB erforderlich.') printf '%s' 'A positive integer in GiB is required.';;
  'Aktive direkt eingebundene Verzeichnisse; FTP/SFTP nur als eingebundener Pfad.') printf '%s' 'Active mounted directories; FTP/SFTP only as a mounted path.';;
  'Vorhandener absoluter Pfad; freie Kapazität beachten.') printf '%s' 'Existing absolute path; verify free space.';;
  'QEMU Guest Agent wird zuerst verwendet. VM-IP nicht aus qm config raten.') printf '%s' 'QEMU Guest Agent is tried first. Do not guess the guest IP from qm config.';;
  'Kein QEMU Guest Agent erreichbar. SSH-Zugang für Netzwerkanalyse anbieten.') printf '%s' 'QEMU guest agent unavailable. Offer SSH access for network analysis.';;
  'IP oder Hostname – nicht durch den Proxmox-Host vorgegeben.') printf '%s' 'IP or hostname; not assumed from Proxmox host.';;
  'Root oder normaler Benutzer mit sudo.') printf '%s' 'Root or a regular user with sudo.';;
  'Bei weiteren geschützten Abfragen sudo -n oder interaktive Freigabe erforderlich.') printf '%s' 'Privileged queries require sudo -n or explicit interactive authorization.';;
  'Host-Key-Prüfung bleibt eingeschaltet.') printf '%s' 'Host-key verification remains enabled.';;
  'Wird nicht in Argumenten oder Logs gespeichert.') printf '%s' 'Not recorded in arguments or logs.';;
  'SSH-Verbindung und Netzwerkprüfung laufen ...') printf '%s' 'SSH connection and network checks in progress ...';;
  'IPv4-Adresse des Gateways (nicht CIDR).') printf '%s' 'IPv4 address of the gateway (not CIDR).';;
  'Erwartet wird eine IPv4-Adresse.') printf '%s' 'Enter an IPv4 address.';;
  'Konvertierung benötigt eine gestoppte VM. Original bleibt erhalten.') printf '%s' 'Conversion requires a stopped VM. Original is retained.';;
  'Der Import kann eine VM herunterfahren. Prüfe Backup und freien Speicher.') printf '%s' 'Import may shut down a VM. Check backup and free space.';;
  'Eigenen absoluten Pfad angeben') printf '%s' 'Specify custom absolute path';;
  'Offline-Konvertierung jetzt starten (VM ggf. herunterfahren)') printf '%s' 'Start offline conversion now (may shut down VM)';;
  'Originalgröße beibehalten') printf '%s' 'Keep original capacity';;
  'Manuelle Größe festlegen') printf '%s' 'Enter custom capacity';;
  'Ziel zu klein') printf '%s' 'Destination too small';;
  'Gast-OS unbekannt') printf '%s' 'Unknown guest OS';;
  'Ungültige Hardwarewerte') printf '%s' 'Invalid hardware values';;
  'CPU-Limit ungültig') printf '%s' 'Invalid CPU limit';;
  'CPU-Gewichtung ungültig') printf '%s' 'Invalid CPU weight';;
  'CPU-Gewichtung') printf '%s' 'CPU weight';;
  'Fehlende Abhängigkeit') printf '%s' 'Missing dependency';;
  "$(ui_t 'IPv6 nicht bekannt' 'IPv6 unknown')") printf '%s' 'IPv6 not detected';;
  "$(ui_t 'IPv6 ungültig' 'Invalid IPv6')") printf '%s' 'Invalid IPv6 address';;
  "$(ui_t 'IPv6 Gateway' 'IPv6 gateway')") printf '%s' 'IPv6 gateway';;
  "$(ui_t 'Adresse/CIDR erforderlich' 'Address/CIDR required')") printf '%s' 'Address/CIDR is required';;
  'IPv6/CIDR') printf '%s' 'IPv6/CIDR';;
  "$(ui_t 'Globale IPv6-Adresse mit Prefix, z.B. 2001:db8::5/64' 'Global IPv6 address with prefix, e.g. 2001:db8::5/64')") printf '%s' 'Global IPv6 address with prefix, e.g. 2001:db8::5/64';;
  "$(ui_t 'Optional: IPv6 Gateway (leer falls keines)' 'Optional: IPv6 gateway (empty if none)')") printf '%s' 'Optional: IPv6 gateway (leave empty if none)';;
  "$(ui_t 'Keine eindeutige globale IPv6/CIDR gefunden. Manuell wählen.' 'No valid global IPv6/CIDR found. Choose manual.')") printf '%s' 'No unambiguous global IPv6/CIDR found. Choose manual.';;
  'Der Import kann eine VM herunterfahren. Prüfe Backup und freien Speicher.') printf '%s' 'Import may shut down a VM. Check backup and free space.';;
  'Jetzt Migration ausführen') printf '%s' 'Run migration now';;
  'Abbrechen und zurück zur VM') printf '%s' 'Cancel and return to VM';;
  'Profil ungültig') printf '%s' 'Invalid profile';;
  'Zusammenfassung') printf '%s' 'Summary';;
  'Migrationsstart fehlgeschlagen') printf '%s' 'Migration launch failed';;
  'Archivpfad ungültig') printf '%s' 'Invalid archive path';;
  'Unbekannter Proxmox-Fehler') printf '%s' 'Unknown Proxmox error';;
  'Keine gültige IP erkannt') printf '%s' 'No valid IP detected';;
  'Gerätezuordnung') printf '%s' 'Device mapping';;
  'Host-Gerätepfad') printf '%s' 'Host device path';;
  'Gerät nicht verfügbar') printf '%s' 'Device unavailable';;
  'Paketprotokoll') printf '%s' 'Package log';;
  'Paketinstallation bestätigen') printf '%s' 'Confirm package installation';;
  'Ja, Paketinstallation starten') printf '%s' 'Yes, install packages';;
  'Nein, abbrechen') printf '%s' 'No, cancel';;
  'Quell-VM behalten (empfohlen)') printf '%s' 'Keep source VM (recommended)';;
  'Später nach Verifizierung Löschung anbieten') printf '%s' 'Offer deletion later after verification';;
  'Prüfe das Protokoll:') printf '%s' 'Check the log:';;
  'CPU-Limit') printf '%s' 'CPU limit';;
  'Nicht ermittelt') printf '%s' 'Not detected';;
  'Gastnetzwerk erkennen') printf '%s' 'Detect guest network';;
  'Gastnetzwerk abfragen') printf '%s' 'Query guest network';;
  'Ausführung bestätigen') printf '%s' 'Confirm execution';;
  'Kein sudo verfügbar') printf '%s' 'No sudo available';;
  'Storage-Abfrage fehlgeschlagen') printf '%s' 'Storage query failed';;
  'Keine LXC-Storages gefunden') printf '%s' 'No LXC storages found';;
  'Ziel-Storage') printf '%s' 'Destination storage';;
  'Temporäres Archiv') printf '%s' 'Temporary archive';;
  'Ziel-CT-ID') printf '%s' 'Destination CT ID';;
  'VM-Shutdown') printf '%s' 'VM shutdown';;
  'Aktion wählen') printf '%s' 'Select action';;
  *) printf '%s' "$str";;
 esac
}
ui_lang_toggle() { if [[ $UI_LANG == de ]]; then UI_LANG=en; else UI_LANG=de; fi; export PVE_VM2LXC_LANG=$UI_LANG; }
ui_t() {
 local de=$1 en=${2:-$1}
 if [[ $UI_LANG == en ]]; then printf '%s' "$en"; else printf '%s' "$de"; fi
}

UI_OLD_STTY='' UI_LINES=() UI_DESCS=() UI_IDS=()
ui_cleanup() { [[ -n ${UI_OLD_STTY:-} ]] && stty "$UI_OLD_STTY" 2>/dev/null || :; printf '\033[?25h\033[?1049l\033[0m\033[H\033[2J\033[3J'; }
ui_shorten() { local str=$1 max=$2; if ((${#str}>max)); then printf '%s…' "${str:0:max-1}"; else printf '%s' "$str"; fi; }
ui_width() { local w; w=$(tput cols 2>/dev/null || echo 100); [[ $w =~ ^[0-9]+$ ]] || w=100; ((w<50)) && w=50; printf '%s' "$w"; }
ui_height() { local h; h=$(tput lines 2>/dev/null || echo 30); [[ $h =~ ^[0-9]+$ ]] || h=30; ((h<15)) && h=15; printf '%s' "$h"; }
ui_put() { local y=$1 x=$2; shift 2; printf '\033[%d;%dH%s' "$y" "$x" "$*"; }
ui_monitor_line() { local y=$1; shift; printf '\033[%d;1H\033[2K' "$y"; ui_put "$y" 5 "$*"; }

ui_rule() { local w=$1 pad; printf -v pad '%*s' "$w" ''; printf '%s' "${pad// /─}"; }
ui_collect() {
 UI_IDS=() UI_DESCS=()
 case $UI_PAGE in
 home)
  UI_IDS=(vms profiles storage about quit); UI_DESCS=("$(ui_t 'Virtuelle Maschinen auswählen' 'Select virtual machines')" "$(ui_t 'Gespeicherte Migrationsprofile' 'Saved migration profiles')" "$(ui_t 'Proxmox Storages anzeigen' 'Show Proxmox storage')" "$(ui_t 'Projekt und Sicherheit' 'Project and safety')" "$(ui_t 'Beenden' 'Exit')");;
 vms)
  local line id name status mem hint cfg ostype
  while IFS= read -r line; do
   [[ $line =~ ^[[:space:]]*([0-9]+)[[:space:]]+([^[:space:]]+)[[:space:]]+([^[:space:]]+)[[:space:]]+([0-9]+) ]] || continue
   id=${BASH_REMATCH[1]}; name=${BASH_REMATCH[2]}; status=${BASH_REMATCH[3]}; mem=${BASH_REMATCH[4]}
   cfg=$(qm config "$id" 2>/dev/null || :); ostype=$(sed -n 's/^ostype: //p' <<<"$cfg" | head -1)
   case $ostype in win*|wvista|w2k*|wxp) hint="$(ui_t 'NICHT KONVERTIERBAR · Windows' 'NOT CONVERTIBLE · Windows')";; l24|l26) hint="$(ui_t 'Linux · nicht verifiziert' 'Linux · not verified')";; *) hint="$(ui_t 'Gast-OS ungeprüft' 'Guest OS unverified')";; esac
   UI_IDS+=("$id"); UI_DESCS+=("$id  $name  [$status]  ${mem} MiB  ·  $hint")
  done < <(qm list 2>/dev/null || :)
  ;;
 profiles)
  local prof
  while IFS= read -r prof; do
   [[ -n $prof ]] || continue
   UI_IDS+=("$prof"); UI_DESCS+=("$prof")
  done < <(profile_list)
  ;;
 storage)
  local line name type status size used available percent
  while read -r name type status size used available percent; do
   [[ $name == Name || -z $name ]] && continue
   UI_IDS+=("$name"); UI_DESCS+=("$name   $type   $status   $(ui_t "frei:" "free:") ${available} KiB   $(ui_t "belegt:" "used:") $percent")
  done < <(pvesm status 2>/dev/null || :)
  ;;
 about) UI_IDS=(back); UI_DESCS=("$(ui_t 'Zurück zum Hauptmenü' 'Back to main menu')");;
 vm) UI_IDS=(migration back); UI_DESCS=("$(ui_t 'Migration planen oder starten' 'Plan or start migration')" "$(ui_t 'Zurück zur VM-Liste' 'Back to VM list')");;
 esac
 if ((${#UI_IDS[@]}==0)); then UI_CURSOR=0; elif ((UI_CURSOR>=${#UI_IDS[@]})); then UI_CURSOR=$((${#UI_IDS[@]}-1)); fi
}
ui_draw() {
 local w h line max visible start i y selected desc title subtitle bar foot
 w=$(ui_width); h=$(ui_height); max=$((w-6)); visible=$((h-13)); ((visible<1)) && visible=1
 printf '\033[H\033[2J'
 ui_put 2 4 "${UI_BOLD}${UI_BLUE}◆ PVE VM2LXC${UI_RESET}  ${UI_MUTED}v${VERSION:-1.0.0}   /   Proxmox VE   /   $(ui_t "Migrationsassistent" "Migration Wizard")${UI_RESET}"
 ui_put 3 4 "${UI_MUTED}$(ui_rule "$((w-7))")${UI_RESET}"
 case $UI_PAGE in
 home) title=$(ui_t 'Dashboard' 'Dashboard'); subtitle=$(ui_t 'Wähle einen Bereich. Migrationen erfordern explizite Bestätigungen.' 'Choose an area. Migrations require explicit confirmation.');;
 vms) title=$(ui_t 'Virtuelle Maschinen' 'Virtual machines'); subtitle=$(ui_t 'Pfeiltasten: wählen  ·  Enter: Details  ·  Alt+R: aktualisieren' 'Arrow keys: select · Enter: details · Alt+R: refresh');;
 profiles) title=$(ui_t 'Gespeicherte Profile' 'Saved profiles'); subtitle=$(ui_t 'Enter: ausführen · Strg+D: Profil löschen; keine Passwörter gespeichert' 'Enter: run · Ctrl+D: delete profile; no passwords stored');;
 storage) title=$(ui_t 'Storages' 'Storage pools'); subtitle=$(ui_t 'Echte Proxmox-Storage-Informationen (pvesm status)' 'Proxmox storage information (pvesm status)');;
 vm) title="VM ${UI_VM} · $(ui_t 'Details' 'Details')"; subtitle=$(ui_t 'Quelle wird nicht geändert. Mit Enter Migrationsassistent öffnen; Quelle bleibt bis zur Abschlussphase erhalten.' 'Source is preserved. Press Enter to open migration wizard.');;
 about) title=$(ui_t 'Über das Projekt' 'About this project'); subtitle=$(ui_t 'Sicherheitsstatus und Funktionsumfang' 'Safety status and features');;
 esac
 ui_put 5 4 "${UI_BOLD}${UI_WHITE}$title${UI_RESET}"
 ui_put 6 4 "${UI_MUTED}$(ui_shorten "$subtitle" "$max")${UI_RESET}"
 ui_put 8 4 "${UI_MUTED}$(ui_rule "$((w-7))")${UI_RESET}"
 if [[ $UI_PAGE == vm ]]; then
  local cfg network disks osinfo
  cfg=$(qm config "$UI_VM" 2>/dev/null || :)
  osinfo=$(sed -n 's/^ostype: //p' <<< "$cfg" | head -1)
  network=$(grep -E '^net[0-9]+:' <<<"$cfg" || :)
  disks=$(grep -E '^(scsi|sata|virtio|ide)[0-9]+:' <<<"$cfg" || :)
  ui_put 10 5 "${UI_BLUE}$(ui_t "Betriebssystem-Hinweis:" "Guest OS hint:")${UI_RESET} $(ui_shorten "${osinfo:-unbekannt}" "$((max-22))")"
  y=12; ui_put "$y" 5 "${UI_BLUE}$(ui_t "Netzwerkschnittstellen" "Network interfaces")${UI_RESET}"; ((y+=1))
  while IFS= read -r line; do [[ -n $line ]] || continue; ((y<h-6)) || break; ui_put "$y" 6 "$(ui_shorten "$line" "$((max-3))")"; ((y+=1)); done <<< "$network"
  ((y+=1)); if ((y<h-6)); then ui_put "$y" 5 "${UI_BLUE}$(ui_t "Datenträger" "Disks")${UI_RESET}"; ((y+=1)); fi
  while IFS= read -r line; do [[ -n $line ]] || continue; ((y<h-5)) || break; ui_put "$y" 6 "$(ui_shorten "$line" "$((max-3))")"; ((y+=1)); done <<< "$disks"
  ui_put "$((h-7))" 4 "${UI_AMBER}$(ui_t "Gast-OS, IPs und LXC-Kompatibilität sind noch NICHT verifiziert." "Guest OS, IPs and LXC compatibility are NOT yet verified.")${UI_RESET}"
  ui_put "$((h-5))" 5 "${UI_BLUE}$(ui_t "Enter: Migrationsassistent starten · Strg+R: zurück" "Enter: start migration wizard · Ctrl+R: back")${UI_RESET}"
 elif [[ $UI_PAGE == about ]]; then
  ui_put 10 5 "$(ui_t 'Dieses Release enthält einen Offline-Migrationsmotor für Linux-Gäste.' 'This release includes an offline migration engine for Linux guests.')"
  ui_put 12 5 "$(ui_t 'VM-Auswahl, Detailansichten und Storage-Übersicht: lesend.' 'VM selection, detail views and storage overview: read-only.')"
  ui_put 14 5 "$(ui_t 'Nach dem Import bleibt der Container bis zur finalen Prüfung ausgeschaltet.' 'After import, the CT remains stopped until final checks.')"
  ui_put 16 5 "$(ui_t 'Alter Planungsassistent: pve-vm2lxc legacy-plan' 'Legacy planner: pve-vm2lxc legacy-plan')"
 else
  start=0; ((UI_CURSOR>=visible)) && start=$((UI_CURSOR-visible+1))
  for ((i=start;i<${#UI_IDS[@]}&&i<start+visible;i++)); do
   y=$((10+i-start)); desc=$(ui_shorten "${UI_DESCS[i]}" "$((max-5))")
   if ((i==UI_CURSOR)); then ui_put "$y" 5 "${UI_SELECTED} › $(printf '%-*s' "$((max-3))" "$desc") ${UI_RESET}";
   else ui_put "$y" 5 "  ${UI_WHITE}$desc${UI_RESET}"; fi
  done
  ((${#UI_IDS[@]}==0)) && ui_put 11 5 "${UI_AMBER}$(ui_t "Keine Einträge gefunden." "No entries found.")${UI_RESET}"
 fi
 ui_put "$((h-3))" 4 "${UI_MUTED}$(ui_rule "$((w-7))")${UI_RESET}"
 ui_put "$((h-2))" 4 "${UI_MUTED}$(ui_t "↑ ↓ Auswahl  Enter Weiter  Esc Neustart  Strg+R Zurück  Alt+R Neu  Strg+L Sprache  Strg+D Löschen  Q Ende" "↑ ↓ Select  Enter Next  Esc Restart  Ctrl+R Back  Alt+R Refresh  Ctrl+L Language  Ctrl+D Delete  Q Quit")${UI_RESET}"
}
# Both direct wizard execution and the saved-profile menu use this single path.
# Never execute an incomplete or invalid profile. The engine rechecks the source
# VM and target CT before making changes.
ui_start_saved_profile() {
 local file=$1 pf vm ct store size archive action shutdown
 local -a options=()
 if ! profile_load "$file"; then
  ui_wizard_notice "$(ui_t 'Profil ungültig' 'Invalid profile')" "$file" || :
  return 1
 fi
 pf="$(profiles_directory)/$file"
 vm=$(jq -er '.vmid' "$pf") || return 1
 ct=$(jq -er '.ctid' "$pf") || return 1
 store=$(jq -er '.storage' "$pf") || return 1
 size=$(jq -er '.rootfs_gib' "$pf") || return 1
 archive=$(jq -er '.archive_dir' "$pf") || return 1
 action=$(jq -er '.action' "$pf") || return 1
 shutdown=$(jq -er '.shutdown' "$pf") || return 1
 [[ $action == convert || $action == plan ]] || return 1
 mapfile -t options < <(jq -r '.engine_options[]' "$pf")
 if [[ $shutdown == true && $action == convert ]]; then
  local option has_shutdown=0
  for option in "${options[@]}"; do [[ $option == --shutdown ]] && has_shutdown=1; done
  ((has_shutdown)) || options+=(--shutdown)
 fi
 UI_VM=$vm
 # Do not propagate a failing engine-monitor exit into the set -e TUI loop.
 if ! ui_engine_monitor "$action" "$ct" "$store" "$size" "$archive" "${options[@]}"; then
  ui_wizard_notice "$(ui_t 'Migrationsstart fehlgeschlagen' 'Migration start failed')" \
   "$(ui_t 'Der Start wurde abgebrochen. Das gespeicherte Profil bleibt erhalten.' 'Start failed. The saved profile remains available.')" || :
  return 1
 fi
 return 0
}

ui_enter() {
 ((${#UI_IDS[@]})) || return 0
 local id=${UI_IDS[UI_CURSOR]}
 case $UI_PAGE in
 home) case $id in vms|profiles|storage|about) UI_NAV_STACK+=("$UI_PAGE"); UI_PAGE=$id; UI_CURSOR=0;; quit) UI_ACTIVE=0;; esac;;
 vms) UI_VM=$id; UI_NAV_STACK+=("$UI_PAGE"); UI_PAGE=vm; UI_CURSOR=0;;
 vm) if [[ $id == migration ]]; then ui_migration_wizard || :; else ui_back; fi;;
 profiles)
  if profile_load "$id"; then
   local pf="$(profiles_directory)/$id" pv pc ps psize pa pm
   pv=$(jq -r .vmid "$pf"); pc=$(jq -r .ctid "$pf"); ps=$(jq -r .storage "$pf")
   psize=$(jq -r .rootfs_gib "$pf"); pa=$(jq -r .archive_dir "$pf"); pm=$(jq -r .action "$pf")
   ui_wizard_choice "$(ui_t 'Profil ausführen' 'Run profile')" "VM $pv → CT $pc | $ps | ${psize}GiB
$(ui_t 'Aktuelle Voraussetzungen werden vor der Ausführung erneut geprüft.' 'Current prerequisites are rechecked before execution.')" \
    go "$(ui_t 'Erneut prüfen und ausführen' 'Recheck and execute')" cancel "$(ui_t 'Abbrechen' 'Cancel')" || return 0
   if [[ $UI_PICK == go ]]; then
    ui_start_saved_profile "$id" || :
   fi
  else ui_wizard_notice 'Profil ungültig' "$id" || :; fi
  ;;
 storage) : ;; about) ui_back;;
 esac
}
# Esc always restarts the assistant at the home screen.  Ctrl+R goes back
# exactly one navigation level (wizard prompts use their own step history).
UI_NAV_STACK=()
ui_back() {
 local prev
 if ((${#UI_NAV_STACK[@]})); then
  prev=${UI_NAV_STACK[${#UI_NAV_STACK[@]}-1]}
  unset 'UI_NAV_STACK[${#UI_NAV_STACK[@]}-1]'
  UI_PAGE=$prev
 else
  case $UI_PAGE in vm) UI_PAGE=vms;; *) UI_PAGE=home;; esac
 fi
 UI_CURSOR=0
}
ui_restart() { UI_PAGE=home; UI_VM=''; UI_CURSOR=0; UI_NAV_STACK=(); }
ui_delete_selected_profile() {
 [[ $UI_PAGE == profiles && ${#UI_IDS[@]} -gt 0 ]] || return 0
 local file=${UI_IDS[UI_CURSOR]}
 if ! profile_load "$file"; then
  ui_wizard_notice "$(ui_t 'Ungültiges Profil' 'Invalid profile')" "$file" || :
  return 0
 fi
 if ui_wizard_choice "$(ui_t 'Profil löschen' 'Delete profile')" \
    "$file" \
    no "$(ui_t 'Nein, behalten' 'No, keep it')" \
    yes "$(ui_t 'Ja, endgültig löschen' 'Yes, permanently delete')" && [[ $UI_PICK == yes ]]; then
   if profile_delete "$file"; then
    ui_wizard_notice "$(ui_t 'Profil gelöscht' 'Profile deleted')" "$file" || :
   else
    ui_wizard_notice "$(ui_t 'Löschen fehlgeschlagen' 'Delete failed')" "$file" || :
   fi
 fi
}

# Key decoding is shared by menus and the wizard.  PuTTY sends Ctrl+R=0x12,
# Ctrl+L=0x0c, Ctrl+D=0x04 and Alt+R=ESC r (Meta key).
ui_readkey() {
 local key='' next='' seq=''
 IFS= read -rsn1 key </dev/tty || return 1
 case $key in
  $'\022') key=step_back;;
  $'\014') key=language;;
  $'\004') key=delete_profile;;
  $'\e')
   IFS= read -rsn1 -t 0.18 next </dev/tty || next=''
   case $next in
    r|R) key=refresh;;
    '['|'O')
     IFS= read -rsn1 -t 0.18 seq </dev/tty || seq=''
     case $seq in A) key=up;; B) key=down;; *) key=unknown;; esac;;
    '') key=escape;;
    *) key=unknown;;
   esac;;
  '') key=enter;;
 esac
 UI_KEY=$key
}

# VM/Storage entries are a snapshot. Refresh only when opening the page or with R.
# Never call qm config for every arrow-key press.
ui_menu_repaint_row() {
 local index=$1 start=$2 visible=$3 w=$4 max=$5 row desc
 ((index>=start && index<start+visible)) || return 0
 row=$((10+index-start))
 desc=$(ui_shorten "${UI_DESCS[index]}" "$((max-5))")
 printf '\033[%d;5H\033[2K' "$row"
 if ((index==UI_CURSOR)); then
  ui_put "$row" 5 "${UI_SELECTED} › $(printf '%-*s' "$((max-3))" "$desc") ${UI_RESET}"
 else
  ui_put "$row" 5 "  ${UI_WHITE}$desc${UI_RESET}"
 fi
}
ui_menu_move() {
 local prev=$UI_CURSOR next=$1 h w visible prev_start next_start max
 ((next>=0 && next<${#UI_IDS[@]})) || return 0
 ((next!=prev)) || return 0
 UI_CURSOR=$next
 # The VM details page is not a list; it has no moving row highlight.
 [[ $UI_PAGE == vm ]] && return 0
 h=$(ui_height); w=$(ui_width); max=$((w-6)); visible=$((h-13))
 ((visible<1)) && visible=1
 prev_start=0; ((prev>=visible)) && prev_start=$((prev-visible+1))
 next_start=0; ((next>=visible)) && next_start=$((next-visible+1))
 if ((prev_start!=next_start)); then ui_draw; return; fi
 ui_menu_repaint_row "$prev" "$next_start" "$visible" "$w" "$max"
 ui_menu_repaint_row "$next" "$next_start" "$visible" "$w" "$max"
}
ui_event_loop() {
 local page_before vm_before redraw=1 refresh=1
 while ((UI_ACTIVE)); do
  if ((refresh)); then ui_collect; refresh=0; redraw=1; fi
  if ((redraw)); then ui_draw; redraw=0; fi
  ui_readkey || break
  page_before=$UI_PAGE; vm_before=$UI_VM
  case $UI_KEY in
   up|k) ui_menu_move "$((UI_CURSOR-1))";;
   down|j) ui_menu_move "$((UI_CURSOR+1))";;
   enter) ui_enter || :; redraw=1;;
   step_back) ui_back; redraw=1;;
   escape) ui_restart; redraw=1;;
   delete_profile) ui_delete_selected_profile; refresh=1;;
   q|Q) UI_ACTIVE=0;;
   refresh) refresh=1;;
   language) ui_lang_toggle; refresh=1;;
  esac
  # Even if a handler changed the page, do not reuse another page's VM entries.
  if [[ $UI_PAGE != "$page_before" || $UI_VM != "$vm_before" ]]; then refresh=1; fi
 done
}
tui_main() {
 [[ -t 0 && -t 1 ]] || { echo 'An interactive terminal (TTY) is required.' >&2; return 1; }
 command -v stty >/dev/null || { echo 'stty is required.' >&2; return 1; }
 UI_OLD_STTY=$(stty -g)
 trap 'ui_cleanup' EXIT INT TERM
 stty -echo -icanon min 1 time 0
 printf '\033[?1049h\033[?25l'
 ui_event_loop
}

# In-screen wizard: all prompts remain in the alternate terminal screen.
# Every prompt supports Q to cancel. The data engine is still invoked separately.
UI_CANCEL=0 UI_INPUT='' UI_PICK='' UI_WIZARD_LOG='' UI_CONFIRMING=0
# The wizard must never fail silently after a selection. Only stage names and
# VM/CT IDs are written. Credentials and engine arguments are never logged.
ui_wizard_checkpoint() {
 local stage=$1 base="$ROOT_DIR/logs"
 mkdir -p -m 0700 -- "$base" 2>/dev/null || return 0
 local logfile="$base/wizard-flow-${UI_VM:-unknown}.log"
 (umask 077; printf '[%s] stage=%s vm=%s ct=%s\n' "$(date -Is)" "$stage" "${UI_VM:-?}" "${UI_TARGET_CTID:-?}" >> "$logfile") 2>/dev/null || :
 return 0
}

ui_center_message() {
 local text=$1 h w
 h=$(ui_height); w=$(ui_width)
 ui_put "$((h-6))" 5 "\033[2K${UI_AMBER}$(ui_shorten "$text" "$((w-12))")${UI_RESET}"
}
# Multi-line wizard descriptions are rendered vertically. Options start below
# the description instead of overlapping it. Empty descriptions reserve one line.
ui_wizard_detail_lines() {
 local detail=${1:-} line count=0
 while IFS= read -r line || [[ -n $line ]]; do ((count+=1)); done <<< "$detail"
 printf '%s' "$count"
}
ui_wizard_frame() {
 local title=$1 detail=${2:-} w h line row=7 max_row
 w=$(ui_width); h=$(ui_height)
 title=$(ui_loc "$title")
 printf '\033[H\033[2J'
 ui_put 2 4 "${UI_BOLD}${UI_BLUE}◆ PVE VM2LXC${UI_RESET}  ${UI_MUTED}v${VERSION:-1.0.0} / VM ${UI_VM} / $(ui_t "Assistent" "Wizard")${UI_RESET}"
 ui_put 3 4 "${UI_MUTED}$(ui_rule "$((w-7))")${UI_RESET}"
 ui_put 5 5 "${UI_BOLD}${UI_WHITE}$(ui_shorten "$title" "$((w-12))")${UI_RESET}"
 max_row=$((h-7))
 while IFS= read -r line || [[ -n $line ]]; do
  ((row<=max_row)) || break
  ui_put "$row" 5 "${UI_MUTED}$(ui_shorten "$(ui_loc "$line")" "$((w-12))")${UI_RESET}"
  ((row+=1))
 done <<< "$detail"
 ui_put "$((h-3))" 4 "${UI_MUTED}$(ui_rule "$((w-7))")${UI_RESET}"
 ui_put "$((h-2))" 5 "${UI_MUTED}$(ui_t "↑ ↓ Auswahl · Enter Weiter · Strg+R Zurück · Esc Neustart · Strg+L Sprache · Q Abbruch" "↑ ↓ Select · Enter Next · Ctrl+R Back · Esc Restart · Ctrl+L Language · Q Cancel")${UI_RESET}"
}
# Structured overview of the current NIC (read-only; does not change migration options).
ui_network_detail() {
 local net=$1 raw=$2 mac=$3 ip=$4 gw=$5 method=${6:-UNKNOWN} model bridge vlan mtu line
 model=$(sed -nE 's/.*(virtio|e1000|rtl8139|vmxnet3|ne2k_pci|i82551|i82557|i82559)=([0-9A-Fa-f:]{17}).*/\1/p' <<< "$raw")
 bridge=$(sed -nE 's/.*[, ]bridge=([^, ]+).*/\1/p' <<< "$raw")
 vlan=$(sed -nE 's/.*[, ]tag=([0-9]+).*/\1/p' <<< "$raw")
 mtu=$(sed -nE 's/.*[, ]mtu=([0-9]+).*/\1/p' <<< "$raw")
 [[ -n $model ]] || model='—'
 [[ -n $bridge ]] || bridge='—'
 [[ -n $mac ]] || mac='—'
 [[ -n $ip ]] || ip=$(ui_t 'Nicht ermittelt' 'Not detected')
 [[ -n $gw ]] || gw=$(ui_t 'Keines erkannt' 'None detected')
 printf '%s\n' "$(ui_t 'Schnittstelle' 'Interface'): net$net" \
  "$(ui_t 'Adaptertyp' 'Adapter type'): $model" \
  "MAC: $mac" \
  "Bridge: $bridge${vlan:+  ·  VLAN: $vlan}${mtu:+  ·  MTU: $mtu}" \
  "IP/CIDR: $ip" \
  "$(ui_t "IPv4-Konfiguration" "IPv4 configuration"): $method" \
  "Gateway: $gw"
}
# Non-destructive wizard step history. Ctrl+R replays earlier choices locally
# and lands on the immediately previous prompt. Esc resets the wizard to step 1.
# Passwords are NEVER kept in step history, profiles or logs.
UI_STEP_ACTIVE=0 UI_STEP_INDEX=0 UI_STEP_REPLAY=0 UI_STEP_BACK=0 UI_STEP_RESTART=0
UI_STEP_NAMES=() UI_STEP_VALUES=()
ui_step_begin() {
 local kind=$1 title=$2 secret=${3:-0} index
 ((UI_STEP_ACTIVE)) || return 1
 index=$UI_STEP_INDEX; UI_STEP_INDEX=$((UI_STEP_INDEX+1))
 if ((index<UI_STEP_REPLAY)) && [[ ${UI_STEP_NAMES[index]-} == "$kind:$title" && $secret != 1 ]]; then
  UI_STEP_RESULT=${UI_STEP_VALUES[index]}
  return 0
 fi
 # A secret step is not replayable. Ask again rather than store credentials.
 ((index<UI_STEP_REPLAY)) && UI_STEP_REPLAY=$index
 return 1
}
ui_step_commit() {
 ((UI_STEP_ACTIVE)) || return 0
 local index=$((UI_STEP_INDEX-1))
 UI_STEP_NAMES[index]="$1:$2"
 UI_STEP_VALUES[index]=$3
 # Forget stale future answers whenever a step changes.
 UI_STEP_NAMES=("${UI_STEP_NAMES[@]:0:index+1}")
 UI_STEP_VALUES=("${UI_STEP_VALUES[@]:0:index+1}")
}
ui_step_navigation() {
 case $UI_KEY in
  step_back) UI_STEP_BACK=1; return 0;;
  escape) UI_STEP_RESTART=1; return 0;;
 esac
 return 1
}
# Read a line in raw TTY mode.  No echo for passwords; Ctrl+R and Esc are
# recognized immediately, including on text-input screens.
ui_line_edit() {
 local secret=${1:-0} key='' out='' printed=''
 while true; do
  IFS= read -rsn1 key </dev/tty || return 1
  case $key in
   '') UI_LINE=$out; printf '\033[?25l'; return 0;;
   $'\022') UI_STEP_BACK=1; return 1;;
   $'\e') UI_STEP_RESTART=1; return 1;;
   $'\014') ui_lang_toggle;;
   $'\177'|$'\010')
    if ((${#out})); then
     out=${out:0:${#out}-1}
     printf '\b \b'
    fi;;
   $'\003') UI_CANCEL=1; return 1;;
   *)
    [[ $key == [$'\000'-$'\037'] ]] && continue
    out+=$key
    if [[ $secret == 1 ]]; then printed='*'; else printed=$key; fi
    printf '%s' "$printed";;
  esac
 done
}
ui_wizard_input() {
 # Set UI_INPUT. Required input can have a non-empty default.
 local title=$1 help=$2 default=${3:-} secret=${4:-0} first='' second='' h
 if ui_step_begin input "$title" "$secret"; then UI_INPUT=$UI_STEP_RESULT; return 0; fi
 h=$(ui_height)
 while true; do
  ui_wizard_frame "$(ui_loc "$title")" "$(ui_loc "$help")"
  ui_put 10 5 "${UI_BLUE}$(ui_t "Eingabe" "Input")${UI_RESET} ${UI_MUTED}$(ui_t "(q = abbrechen, Enter = Standardwert)" "(q = cancel, Enter = default)")${UI_RESET}"
  ui_put 12 5 "${UI_MUTED}$(ui_t "Vorgabe:" "Default:") ${default:-$(ui_t "keine" "none")}${UI_RESET}"
  ui_put 14 5 '> '
  printf '\033[?25h'
  if ! ui_line_edit "$secret"; then printf '\033[?25l'; return 1; fi
  first=$UI_LINE
  if [[ ${first,,} == q ]]; then UI_CANCEL=1; return 1; fi
  [[ -n $first ]] || first=$default
  if [[ ${ENGINE_DEBUG:-0} == 1 ]]; then
   ui_wizard_frame "$title · DEBUG" "$(ui_t "Gib exakt denselben Wert erneut ein." "Enter exactly the same value again.")"
   ui_put 14 5 '> '
   printf '\033[?25h'
   if ! ui_line_edit "$secret"; then printf '\033[?25l'; return 1; fi
   second=$UI_LINE
   [[ ${second,,} == q ]] && { UI_CANCEL=1; return 1; }
   [[ -n $second ]] || second=$default
   if [[ $first != "$second" ]]; then
    ui_center_message "$(ui_t "Eingaben stimmen nicht überein. Nochmals eingeben." "Entries do not match. Try again.")"
    sleep 1; continue
   fi
  fi
  UI_INPUT=$first
  if [[ $secret != 1 ]]; then ui_step_commit input "$title" "$first"; fi
  return 0
 done
}
# Fast menu renderer. Only the two changed rows are updated on cursor movement;
# a full frame is rendered on first entry, language change or scroll.
ui_wizard_choice() {
 local title=$1 help=$2; shift 2
 local -a options=("$@")
 local cursor=0 previous=0 len=$(( ${#options[@]} / 2 )) h w visible start=0 newstart=0 y options_row key
 local resolved_title resolved_help label max_label i
 if [[ ${UI_CONFIRMING:-0} == 0 ]] && ui_step_begin choice "$title"; then
  UI_PICK=$UI_STEP_RESULT; return 0
 fi
 ((len>0)) || { ui_wizard_frame "$title" "$(ui_t 'Keine auswählbaren Optionen gefunden.' 'No selectable options found.')"; ui_readkey; return 1; }
 while true; do
  h=$(ui_height); w=$(ui_width)
  resolved_title=$(ui_loc "$title"); resolved_help=$(ui_loc "$help")
  options_row=$(( 7 + $(ui_wizard_detail_lines "$resolved_help") + 2 ))
  ((options_row<10)) && options_row=10
  visible=$((h-options_row-4)); ((visible<1)) && visible=1
  max_label=$((w-14)); ((max_label<8)) && max_label=8
  start=0; ((cursor>=visible)) && start=$((cursor-visible+1))
  ui_wizard_frame "$resolved_title" "$resolved_help"
  for ((i=start;i<len && i<start+visible;i++)); do
   y=$((options_row+i-start))
   label=$(ui_shorten "$(ui_loc "${options[i*2+1]}")" "$max_label")
   if ((i==cursor)); then
    ui_put "$y" 5 "${UI_SELECTED} › ${label} ${UI_RESET}"
   else
    ui_put "$y" 5 "  ${UI_WHITE}${label}${UI_RESET}"
   fi
  done
  while true; do
   ui_readkey || { UI_CANCEL=1; return 1; }
   previous=$cursor
   case $UI_KEY in
    up|k) ((cursor>0)) && ((cursor-=1)) || :;;
    down|j) ((cursor<len-1)) && ((cursor+=1)) || :;;
    enter)
     UI_PICK=${options[cursor*2]}
     if [[ ${ENGINE_DEBUG:-0} == 1 && ${UI_CONFIRMING:-0} == 0 ]]; then
      local first_choice=$UI_PICK second_choice
      UI_CONFIRMING=1
      if ! ui_wizard_choice "$title · DEBUG: Wiederholung" "$(ui_t 'Dieselbe Option erneut auswählen.' 'Select the same option again.')" "${options[@]}"; then
       UI_CONFIRMING=0; return 1
      fi
      second_choice=$UI_PICK; UI_CONFIRMING=0
      if [[ $first_choice != "$second_choice" ]]; then
       ui_center_message "$(ui_t 'Optionen stimmen nicht überein – erneut auswählen.' 'Options do not match – try again.')"
       sleep 1; break
      fi
      UI_PICK=$first_choice
     fi
     if [[ ${UI_CONFIRMING:-0} == 0 ]]; then ui_step_commit choice "$title" "$UI_PICK"; fi
     return 0;;
    language) ui_lang_toggle; break;;
    step_back|escape) ui_step_navigation; return 1;;
    q|Q) UI_CANCEL=1; return 1;;
    *) continue;;
   esac
   ((cursor==previous)) && continue
   newstart=0; ((cursor>=visible)) && newstart=$((cursor-visible+1))
   if ((newstart!=start)); then
    # Scroll changed: recreate the page only in this case.
    break
   fi
   # Overwrite both selection lines, clear to EOL to avoid leftover text.
   y=$((options_row+previous-start))
   label=$(ui_shorten "$(ui_loc "${options[previous*2+1]}")" "$max_label")
   printf '\033[%d;5H\033[2K  %s%s%s' "$y" "$UI_WHITE" "$label" "$UI_RESET"
   y=$((options_row+cursor-start))
   label=$(ui_shorten "$(ui_loc "${options[cursor*2+1]}")" "$max_label")
   printf '\033[%d;5H\033[2K%s › %s %s' "$y" "$UI_SELECTED" "$label" "$UI_RESET"
  done
 done
}

ui_wizard_notice() {
 ui_wizard_frame "$1" "$2"
 ui_put 11 5 "${UI_MUTED}$(ui_t "Enter: weiter · Strg+R: zurück · Esc: Neustart · Strg+L: Sprache · Q: Ende" "Enter: next · Ctrl+R: back · Esc: restart · Ctrl+L: language · Q: quit")${UI_RESET}"
 while true; do
  ui_readkey || return 1
  case $UI_KEY in language) ui_lang_toggle; ui_wizard_frame "$1" "$2";; enter) return 0;; step_back|escape) ui_step_navigation; return 1;; q|Q) UI_CANCEL=1; return 1;; esac
 done
}
ui_next_ctid() {
 # pct nextid scans the shared /etc/pve ID namespace.
 local next
 next=$(pvesh get /cluster/nextid 2>/dev/null | tr -d '\r\n') || next=''
 if [[ ! $next =~ ^[0-9]+$ ]]; then
  next=$(pct nextid 2>/dev/null | tr -d '\r\n') || next=''
 fi
 [[ $next =~ ^[0-9]+$ ]] || return 1
 printf '%s' "$next"
}
ui_storage_options() {
 local name type state total used free pct
 UI_STORAGE_OPTIONS=()
 # Proxmox itself filters by content type. 'pvesm config ID' is NOT a valid command.
 # Do not hide command errors: a failed query must be reported rather than mistaken
 # for a host with no compatible storage.
 local listing
 if ! listing=$(pvesm status --content rootdir 2>&1); then
  UI_STORAGE_ERROR="pvesm status --content rootdir: $listing"
  return 1
 fi
 UI_STORAGE_ERROR=''
 while read -r name type state total used free pct; do
  [[ $name == Name || -z $name || $state != active ]] && continue
  [[ $free =~ ^[0-9]+$ ]] || free=0
  UI_STORAGE_OPTIONS+=("$name" "$name · $type · frei: $((free/1048576)) GiB")
 done <<< "$listing"
}
ui_archive_options() {
 local storage cfg dir type state rest
 UI_ARCHIVE_OPTIONS=(custom 'Eigenen absoluten Pfad angeben')
 # The storage API contains path for directory-backed Proxmox storage.
 # Block storage (LVM/ZFS) has no suitable filesystem path for TAR archives.
 while read -r storage type state rest; do
  [[ $storage == Name || $state != active ]] && continue
  cfg=$(pvesh get "/storage/$storage" --output-format json 2>/dev/null || :)
  [[ -n $cfg ]] || continue
  dir=$(jq -r '.path // empty' <<< "$cfg" 2>/dev/null || :)
  [[ $dir == /* && -d $dir && -w $dir ]] || continue
  UI_ARCHIVE_OPTIONS+=("$dir" "$storage → $dir (direkt eingebundener Pfad)")
 done < <(pvesm status 2>/dev/null || :)
}
ui_guest_network_qga() {
 # Dynamic guest IPs are matched by MAC (never guessed from qm config).
 UI_QGA_JSON=''
 command -v jq >/dev/null || return 1
 UI_QGA_JSON=$(timeout 9 qm guest cmd "$UI_VM" network-get-interfaces 2>/dev/null) || return 1
 jq -e 'type=="array"' <<< "$UI_QGA_JSON" >/dev/null 2>&1 || return 1
 return 0
}
ui_guest_net_by_mac() {
 local mac=${1,,} typ=$2 rows cidr
 [[ -n ${UI_QGA_JSON:-} ]] || return 1
 rows=$(jq -r --arg mac "$mac" --arg typ "$typ" '
  .[] | select((."hardware-address" // "" | ascii_downcase)==$mac) |
  .["ip-addresses"][]? | select(.["ip-address-type"]==$typ) |
  "\(.["ip-address"])/\(.["prefix"])"' <<< "$UI_QGA_JSON" 2>/dev/null) || return 1
 [[ $(grep -c . <<< "$rows") -eq 1 ]] || return 1
 printf '%s' "$rows"
}
ui_guest_netname_by_mac() {
 local mac=${1,,}
 [[ -n ${UI_QGA_JSON:-} ]] || return 1
 jq -r --arg mac "$mac" '.[] | select((."hardware-address" // "" | ascii_downcase)==$mac) | .name' <<< "$UI_QGA_JSON" | head -1
}
ui_guest_route_qga() {
 local mac=$1 iface out route bin
 iface=$(ui_guest_netname_by_mac "$mac")
 [[ -n $iface ]] || return 1
 command -v jq >/dev/null || return 1
 for bin in /usr/bin/ip /sbin/ip; do
  out=$(timeout 12 qm guest exec "$UI_VM" -- "$bin" -4 route show default 2>/dev/null) || continue
  route=$(jq -r '."out-data" // empty' <<< "$out" 2>/dev/null) || continue
  [[ -n $route ]] || continue
  awk -v iface="$iface" '$1=="default" && $2=="via" && $4=="dev" && $5==iface {print $3;exit}' <<< "$route"
  return 0
 done
 return 1
}
# Determine DHCP vs static from the *active guest network configuration*.
# Address assignment as reported by QGA does not reveal its configuration method.
# Every probe is read-only, and an unrecognized configuration returns UNKNOWN.
ui_guest_ipv4_method() {
 local iface=$1 data='' method='' probe
 [[ $iface =~ ^[a-zA-Z0-9_.:@-]+$ ]] || { printf UNKNOWN; return 0; }
 probe=$(cat "${ROOT_DIR}/lib/guest-ipv4-method.sh") || { printf UNKNOWN; return 0; }
 if [[ ${1:-} && ${UI_GUEST_METHOD_SOURCE:-} == ssh ]]; then
  # Guest access was established earlier, do not bypass strict host-key checking.
  local -a sshargs=(-o StrictHostKeyChecking=yes -o ConnectTimeout=7)
  if [[ -n ${UI_SSH_PASS:-} ]]; then
   command -v sshpass >/dev/null || { printf UNKNOWN; return 0; }
   data=$(printf '%s\n' "$probe" | SSHPASS="$UI_SSH_PASS" sshpass -e ssh "${sshargs[@]}" -- "$UI_SSH_USER@$UI_SSH_HOST" "sh -s -- $(printf '%q' "$iface")" 2>/dev/null) || :
  else
   data=$(printf '%s\n' "$probe" | ssh -o BatchMode=yes "${sshargs[@]}" -- "$UI_SSH_USER@$UI_SSH_HOST" "sh -s -- $(printf '%q' "$iface")" 2>/dev/null) || :
  fi
 else
  # QGA runs inside the VM; parse output as reported by qm guest exec.
  local result
  result=$(timeout 15 qm guest exec "$UI_VM" -- /bin/sh -c "$probe" -- "$iface" 2>/dev/null) || result=''
  if [[ -n $result ]]; then
   local exitcode
   exitcode=$(jq -r '.exitcode // .exitCode // 0' <<< "$result" 2>/dev/null) || exitcode=1
   [[ $exitcode == 0 ]] && data=$(jq -r '."out-data" // .out_data // empty' <<< "$result" 2>/dev/null) || :
  fi
 fi
 method=$(printf '%s\n' "$data" | grep -m1 -E '^(DHCP|STATIC|MIXED|UNKNOWN)\|' || :)
 [[ -n $method ]] && printf '%s' "$method" || printf UNKNOWN
}
ui_guest_ssh_probe() {
 # Used only to retrieve IP/routing details when QGA unavailable.
 # Key-based SSH is preferred. Optional password via sshpass -e (never CLI argv).
 local sshhost=$1 sshuser=$2 mode=$3 pass=${4:-} reply='' cmd
 command -v ssh >/dev/null || return 1
 cmd='ip -o -4 addr show scope global; printf "\\nROUTES\\n"; ip -4 route show default; printf "\\nMACS\\n"; for d in /sys/class/net/*; do [ -e "$d/address" ] && printf "%s %s\\n" "${d##*/}" "$(cat "$d/address")"; done'
 local -a args=(-o BatchMode=yes -o ConnectTimeout=7 -o StrictHostKeyChecking=yes)
 if [[ -n $pass ]]; then
  command -v sshpass >/dev/null || return 1
  args=(-o BatchMode=no -o ConnectTimeout=7 -o StrictHostKeyChecking=yes -o NumberOfPasswordPrompts=1)
  reply=$(SSHPASS="$pass" sshpass -e ssh "${args[@]}" -- "$sshuser@$sshhost" "$cmd" 2>/dev/null) || return 1
 else
  reply=$(ssh "${args[@]}" -- "$sshuser@$sshhost" "$cmd" 2>/dev/null) || return 1
 fi
 UI_SSH_DATA=$reply
 return 0
}
ui_guest_ssh_by_mac() {
 local mac=${1,,} intf ip
 [[ -n ${UI_SSH_DATA:-} ]] || return 1
 intf=$(awk -v m="$mac" '$2==m{print $1;exit}' <<< "${UI_SSH_DATA,,}")
 [[ -n $intf ]] || return 1
 ip=$(awk -v iface="$intf" '$2==iface && $3=="inet" {print $4}' <<< "$UI_SSH_DATA" | head -1)
 [[ -n $ip ]] || return 1
 printf '%s' "$ip"
}
ui_guest_ssh_gateway() {
 local mac=${1,,} intf
 intf=$(awk -v m="$mac" '$2==m{print $1;exit}' <<< "${UI_SSH_DATA,,}")
 [[ -n $intf ]] || return 1
 awk -v iface="$intf" '$1=="default" && $2=="via" && $4=="dev" && $5==iface {print $3;exit}' <<< "$UI_SSH_DATA"
}
# Migration-specific dependencies are checked before the wizard asks for settings.
# Installing packages requires explicit consent; no silent package changes.
ui_migration_dependencies() {
 local -a missing=() cmds=(guestfish guestmount guestunmount virt-filesystems jq timeout tar script setsid setfacl getfacl getfattr setfattr)
 local c choice installlog rc=0
 for c in "${cmds[@]}"; do
  command -v "$c" >/dev/null 2>&1 || missing+=("$c")
 done
 ((${#missing[@]}==0)) && return 0
 ui_wizard_choice 'Vorprüfung: fehlende Werkzeuge' \
  "$(ui_t 'Es fehlen' 'Missing'): ${missing[*]}" \
  install 'Fehlende Pakete nach Zustimmung installieren' \
  cancel 'Abbrechen und zur VM zurückkehren' || return 1
 [[ $UI_PICK == install ]] || return 1
 # Debian package name, not individual executable names.
 local -a packages=()
 for c in "${missing[@]}"; do
  case $c in
   guestfish|guestmount|guestunmount|virt-filesystems)
    [[ " ${packages[*]} " == *' libguestfs-tools '* ]] || packages+=(libguestfs-tools);;
   jq|timeout|tar) [[ $c == timeout ]] && c=coreutils; packages+=("$c");;
   script|setsid) [[ " ${packages[*]} " == *' util-linux '* ]] || packages+=(util-linux);;
   setfacl|getfacl) [[ " ${packages[*]} " == *' acl '* ]] || packages+=(acl);;
   getfattr|setfattr) [[ " ${packages[*]} " == *" attr "* ]] || packages+=(attr);;
  esac
 done
 command -v apt-get >/dev/null || { ui_wizard_notice 'Installation nicht verfügbar' "$(ui_t 'apt-get fehlt. Bitte fehlende Pakete manuell installieren.' 'apt-get missing. Install the missing packages manually.')" || :; return 1; }
 ui_wizard_choice 'Paketinstallation bestätigen' \
  "apt-get install -- ${packages[*]} $(ui_t '(ändert Pakete auf dem Proxmox-Host)' '(modifies packages on the Proxmox host)')" \
  yes 'Ja, Paketinstallation starten' no 'Nein, abbrechen' || return 1
 [[ $UI_PICK == yes ]] || return 1
 install -d -m 0700 "$ROOT_DIR/logs" || return 1
 installlog=$(mktemp "$ROOT_DIR/logs/pve-vm2lxc-packages-XXXXXXXX.log") || return 1
 chmod 0600 "$installlog"
 # Fail closed: refuse installs that would remove installed packages (especially PVE).
 if ! apt-get -s install -- "${packages[@]}" >"$installlog" 2>&1; then
  ui_wizard_notice 'Paketprüfung fehlgeschlagen' "apt-Simulation fehlgeschlagen. Log: $installlog" || :
  return 1
 fi
 if grep -Eq '^Remv[[:space:]]' "$installlog"; then
  ui_wizard_notice 'Unsichere Paketänderung blockiert' "apt möchte installierte Pakete entfernen. Keine Installation ausgeführt. Log: $installlog" || :
  return 1
 fi
 # Keep the installer output inside the same TUI. The process runs synchronously.
 ui_wizard_frame 'Systemabhängigkeiten installieren' "Paketprotokoll: $installlog"
 ui_put 10 5 'apt-get installiert die bestätigten Pakete. Keine Quell-VM wird verändert.'
 stty sane; printf '\033[?25h'
 DEBIAN_FRONTEND=noninteractive apt-get install -y -- "${packages[@]}" >"$installlog" 2>&1 || rc=$?
 stty -echo -icanon min 1 time 0; printf '\033[?25l'
 if ((rc != 0)); then
  ui_wizard_frame 'Paketinstallation fehlgeschlagen' "Exit-Code $rc · $installlog"
  ui_put 11 5 "$(ui_shorten "$(tail -n 1 "$installlog")" "$(($(ui_width)-12))")"
  ui_wizard_notice 'Installation fehlgeschlagen' "Prüfe das Protokoll: $installlog" || :
  return 1
 fi
 for c in "${cmds[@]}"; do
  if ! command -v "$c" >/dev/null 2>&1; then
   ui_wizard_notice 'Installation unvollständig' "Fehlt weiterhin: $c · Log: $installlog" || :
   return 1
  fi
 done
 return 0
}
# Validate manually entered IPv4 without relying on optional external packages.
ui_validate_ipv4() {
 local addr=$1 part
 local -a octets
 [[ $addr =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || return 1
 IFS=. read -r -a octets <<< "$addr"
 ((${#octets[@]}==4)) || return 1
 for part in "${octets[@]}"; do
  [[ $part =~ ^[0-9]{1,3}$ ]] || return 1
  ((10#$part<=255)) || return 1
 done
}
ui_validate_ipv4_cidr() {
 local addr=$1 prefix
 [[ $addr == */* ]] || return 1
 prefix=${addr##*/}
 [[ $prefix =~ ^[0-9]{1,2}$ ]] || return 1
 ((10#$prefix<=32)) || return 1
 ui_validate_ipv4 "${addr%/*}"
}
ui_validate_dns_list() {
 local value=$1 addr
 [[ -z $value ]] && return 0
 read -r -a servers <<< "$value"
 ((${#servers[@]}<=3)) || return 1
 for addr in "${servers[@]}"; do ui_validate_ipv4 "$addr" || return 1; done
}
ui_guest_used_bytes() {
 local result
 command -v jq >/dev/null || return 1
 result=$(timeout 12 qm guest cmd "$UI_VM" get-fsinfo 2>/dev/null) || return 1
 jq -er '[.[] | select((.["used-bytes"] // -1) >= 0) | select(.type == "ext4" or .type == "xfs" or .type == "btrfs" or .type == "zfs" or .type == "f2fs") | .["used-bytes"]] | if length>0 then add else empty end' <<< "$result" 2>/dev/null
}
ui_guest_ipv6_qga() {
 local mac=$1
 ui_guest_net_by_mac "$mac" ipv6 | grep -vE '^(fe80:|::1/)' || :
}
ui_routing_snapshot() {
 # Diagnostic ONLY; applying arbitrary policy routes automatically would change network semantics.
 local dir=$1 vm=$2 dest="$dir/vm-$vm-routing-$(date -u +%Y%m%dT%H%M%SZ).json" raw_rule raw_route raw_rule6 raw_route6
 command -v jq >/dev/null || return 0
 raw_rule=$(timeout 12 qm guest exec "$vm" -- /usr/bin/ip -j rule show 2>/dev/null || :)
 raw_route=$(timeout 12 qm guest exec "$vm" -- /usr/bin/ip -j route show table all 2>/dev/null || :)
 raw_rule6=$(timeout 12 qm guest exec "$vm" -- /usr/bin/ip -j -6 rule show 2>/dev/null || :)
 raw_route6=$(timeout 12 qm guest exec "$vm" -- /usr/bin/ip -j -6 route show table all 2>/dev/null || :)
 if [[ -n $raw_rule || -n $raw_route ]]; then
  jq -n --argjson vm "$vm" --arg rules "$raw_rule" --arg routes "$raw_route" --arg rules6 "$raw_rule6" --arg routes6 "$raw_route6" \
  '{vmid:$vm, note:"Diagnostic only. Advanced routing is NOT applied automatically.",guest_agent_rule_output:$rules,guest_agent_route_output:$routes,guest_agent_ipv6_rules:$rules6,guest_agent_ipv6_routes:$routes6}' > "$dest" || :
  chmod 0600 "$dest" 2>/dev/null || :
 fi
}
ui_hardware_wizard() {
 local cfg=$1 cores ram swap cpulim cpuunits value
 hw_source_resources "$cfg"
 cores=$HW_SOURCE_CORES; ram=$HW_SOURCE_MEMORY; swap=0
 cpulim=$HW_SOURCE_CPULIMIT; cpuunits=$HW_SOURCE_CPUUNITS
 UI_HW_DEVICE_OPTIONS=()
 local line devkey devclass devvalue selection hostnode
 while IFS= read -r line; do
  [[ -n $line ]] || continue
  devkey=$(hw_device_key "$line"); devclass=$(hw_device_class "$line")
  if [[ $devclass == virtual-console ]]; then
   # serial0: socket / parallel0: socket is a QEMU console, not a host passthrough.
   continue
  fi
  if [[ $devclass == custom-qemu ]]; then
   ui_wizard_choice "$(ui_t 'QEMU-Sonderargumente' 'Custom QEMU arguments')" \
    "$line\n$(ui_t 'Nicht automatisch in LXC übersetzbar. Dienste könnten davon abhängen.' 'No automatic LXC translation. Services might depend on this.')" \
    skip "$(ui_t 'Bewusst ohne dieses QEMU-Argument fortfahren' 'Explicitly omit this QEMU argument')" \
    cancel "$(ui_t 'Migration abbrechen' 'Abort migration')" || return 1
   [[ $UI_PICK == skip ]] || return 1
   UI_HW_DEVICE_OPTIONS+=(--device-skip "$devkey")
   continue
  fi
  ui_wizard_choice "$(ui_t 'Gerätezuordnung' 'Device mapping'): $devkey" \
    "$line\n$(ui_t 'LXC nutzt Host-Gerätedateien statt QEMU-Passthrough. PCI selbst wird nicht virtualisiert.' 'LXC exposes host device nodes, not QEMU passthrough. PCI itself is not virtualized.')" \
    map "$(ui_t 'Host-Gerätedatei als LXC devN einbinden' 'Expose host device node as LXC devN')" \
    skip "$(ui_t 'Gerät bewusst auslassen (kann Dienste beeinträchtigen)' 'Explicitly omit device (may break services)')" \
    cancel "$(ui_t 'Migration abbrechen' 'Abort migration')" || return 1
  selection=$UI_PICK
  case $selection in
   map)
    ui_wizard_input "$(ui_t 'Host-Gerätepfad' 'Host device path') ($devkey)" \
      "$(ui_t 'Existierendes Zeichen-/Blockgerät, z.B. /dev/dri/renderD128 oder /dev/serial/by-id/...' 'Existing char/block device, e.g. /dev/dri/renderD128 or /dev/serial/by-id/...')" \
      '' || return 1
    hostnode=$UI_INPUT
    if ! hw_valid_node "$hostnode"; then
     ui_wizard_notice "$(ui_t 'Gerät nicht verfügbar' 'Device unavailable')" "$hostnode" || :
     return 1
    fi
    UI_HW_DEVICE_OPTIONS+=(--device-map "$devkey=$hostnode");;
   skip) UI_HW_DEVICE_OPTIONS+=(--device-skip "$devkey");;
   *) return 1;;
  esac
 done < <(hw_device_lines "$cfg")
 ui_wizard_choice "$(ui_t 'CPU und RAM' 'CPU and memory')" \
   "$(ui_t 'Quelle' 'Source'): $cores $(ui_t 'Kerne' 'cores'), $ram MiB RAM; CPU limit: ${cpulim:-default}, weight: ${cpuunits:-default}; balloon: ${HW_SOURCE_BALLOON:-off}" \
   keep "$(ui_t 'Übernehmen' 'Use detected resources')" \
   edit "$(ui_t 'Manuell ändern' 'Edit resources')" || return 1
 if [[ $UI_PICK == edit ]]; then
  ui_wizard_input "$(ui_t 'LXC CPU-Kerne' 'LXC CPU cores')" '1..1024' "$cores" || return 1; cores=$UI_INPUT
  ui_wizard_input "$(ui_t 'LXC RAM in MiB' 'LXC memory MiB')" 'Minimum 16 MiB' "$ram" || return 1; ram=$UI_INPUT
  ui_wizard_input "$(ui_t 'LXC Swap in MiB' 'LXC swap MiB')" "$(ui_t '0 = kein Swap; VM-Balloon ist nicht Swap' '0 = no swap; VM ballooning is not swap')" "$swap" || return 1; swap=$UI_INPUT
  ui_wizard_input "CPU-Limit" "$(ui_t 'Leer = Standard; sonst Zahl, z.B. 2.5' 'Empty = default; otherwise number e.g. 2.5')" "$cpulim" || return 1; cpulim=$UI_INPUT
  ui_wizard_input "CPU-Gewichtung" "$(ui_t 'Leer = Standard; sonst positive Zahl' 'Empty = default; otherwise positive integer')" "$cpuunits" || return 1; cpuunits=$UI_INPUT
 fi
 [[ $cores =~ ^[1-9][0-9]*$ ]] && ((cores<=1024)) && [[ $ram =~ ^[1-9][0-9]*$ ]] && ((ram>=16)) && [[ $swap =~ ^[0-9]+$ ]] || {
  ui_wizard_notice 'Ungültige Hardwarewerte' "$(ui_t 'Kerne, RAM oder Swap sind ungültig.' 'Invalid CPU cores, RAM or swap.')" || :; return 1;
 }
 [[ -z $cpulim || $cpulim =~ ^[0-9]+([.][0-9]+)?$ ]] || { ui_wizard_notice 'CPU-Limit ungültig' "$cpulim" || :; return 1; }
 [[ -z $cpuunits || $cpuunits =~ ^[1-9][0-9]*$ ]] || { ui_wizard_notice 'CPU-Gewichtung ungültig' "$cpuunits" || :; return 1; }
 UI_HW_OPTIONS=(--cores "$cores" --memory "$ram" --swap "$swap" "${UI_HW_DEVICE_OPTIONS[@]}")
 [[ -z $cpulim ]] || UI_HW_OPTIONS+=(--cpulimit "$cpulim")
 [[ -z $cpuunits ]] || UI_HW_OPTIONS+=(--cpuunits "$cpuunits")
}
ui_migration_wizard() {
 UI_STEP_ACTIVE=1 UI_STEP_REPLAY=0 UI_STEP_INDEX=0 UI_STEP_BACK=0 UI_STEP_RESTART=0
 UI_STEP_NAMES=() UI_STEP_VALUES=()
 UI_WIZARD_PROFILE_CACHE_KEY='' UI_WIZARD_PROFILE_CACHE_PATH=''
 while true; do
  UI_STEP_INDEX=0; UI_STEP_BACK=0; UI_STEP_RESTART=0; UI_CANCEL=0
  ui_migration_wizard_core || :
  if ((UI_STEP_RESTART)); then
   UI_STEP_NAMES=() UI_STEP_VALUES=() UI_STEP_REPLAY=0
   UI_WIZARD_PROFILE_CACHE_KEY='' UI_WIZARD_PROFILE_CACHE_PATH=''
   continue
  fi
  if ((UI_STEP_BACK)); then
   # The current prompt has already incremented UI_STEP_INDEX.
   if ((UI_STEP_INDEX<=1)); then
    UI_STEP_NAMES=() UI_STEP_VALUES=() UI_STEP_REPLAY=0
   else
    UI_STEP_REPLAY=$((UI_STEP_INDEX-2))
   fi
   continue
  fi
  break
 done
 UI_STEP_ACTIVE=0
 return 0
}
ui_migration_wizard_core() {
 local ctid storage size archive cfg raw n mac ip gw gwprobe answer mode existing_ip method iface displaymethod manual_dns_selected="" params=() result=0 ram name
 UI_CANCEL=0 UI_QGA_JSON='' UI_SSH_DATA='' UI_GUEST_METHOD_SOURCE='' UI_SSH_HOST='' UI_SSH_USER='' UI_SSH_PASS=''
 ui_migration_dependencies || return 0
 if [[ ${ENGINE_DEBUG:-0} == 1 ]]; then
  install -d -m 0700 "$ROOT_DIR/logs"
  UI_WIZARD_LOG="${ROOT_DIR}/logs/$(date -u +%Y%m%dT%H%M%SZ)-vm${UI_VM}-wizard.log"
  ( umask 077; : > "$UI_WIZARD_LOG" )
  printf '[%s] wizard start vm=%s\n' "$(date -Is)" "$UI_VM" >> "$UI_WIZARD_LOG"
 else UI_WIZARD_LOG=''; fi
 local -a nets=()
 local defaultid
 defaultid=$(ui_next_ctid) || { ui_wizard_notice 'ID-Erkennung fehlgeschlagen' "$(ui_t 'pvesh /cluster/nextid konnte keine freie ID liefern.' 'pvesh /cluster/nextid did not return a free ID.')" || :; return 0; }
 ui_wizard_input 'Ziel-CT-ID' "Freie Proxmox-ID wird automatisch vorgeschlagen." "$defaultid" || return 0
 ctid=$UI_INPUT
 UI_TARGET_CTID=$ctid
 [[ $ctid =~ ^[0-9]+$ ]] || { ui_wizard_notice 'Ungültige CT-ID' 'Bitte nur Zahlen verwenden.' || :; return 0; }
 if pct config "$ctid" >/dev/null 2>&1 || qm config "$ctid" >/dev/null 2>&1; then
  ui_wizard_notice 'CT-ID bereits vergeben' "ID $ctid ist bereits belegt." || :; return 0
 fi
 if ! ui_storage_options; then
  ui_wizard_notice 'Storage-Abfrage fehlgeschlagen' "${UI_STORAGE_ERROR:-Unbekannter Proxmox-Fehler}" || :
  return 0
 fi
 if ((${#UI_STORAGE_OPTIONS[@]}==0)); then
  ui_wizard_notice 'Keine LXC-Storages gefunden' "$(ui_t 'Prüfe: pvesm status --content rootdir. Storage muss aktiv sein und rootdir erlauben.' 'Check pvesm status --content rootdir; storage must be active and support rootdir.')" || :
  return 0
 fi
 ui_wizard_choice 'Ziel-Storage' 'Nur aktive rootdir-fähige Proxmox-Storages werden angeboten.' "${UI_STORAGE_OPTIONS[@]}" || return 0
 storage=$UI_PICK
 cfg=$(qm config "$UI_VM" 2>/dev/null || :)
 local original_size used_bytes min_gib min_note proposed_size
 original_size=$(grep -E '^(scsi|virtio|sata|ide)[0-9]+:' <<< "$cfg" | grep -v 'media=cdrom' | grep -oE 'size=[0-9]+G' | head -1 | cut -d= -f2 | tr -d G || :)
 [[ $original_size =~ ^[1-9][0-9]*$ ]] || original_size=32
 used_bytes=$(ui_guest_used_bytes || :)
 min_note="$(ui_t 'Belegte Daten unbekannt. Originalgröße empfohlen.' 'Used space unknown. Original capacity recommended.')"
 min_gib=0
 if [[ $used_bytes =~ ^[0-9]+$ && $used_bytes -gt 0 ]]; then
  # ceil(used bytes * 1.05 / GiB): 125GiB => 132GiB
  min_gib=$(( (used_bytes * 105 + 100 * 1073741824 - 1) / (100 * 1073741824) ))
  min_note="$(ui_t 'Ermittelte Belegung' 'Detected usage'): $(( (used_bytes + 1073741823)/1073741824 )) GiB · $(ui_t 'Minimum mit 5% Reserve' 'minimum with 5% headroom'): ${min_gib} GiB"
 fi
 ui_wizard_choice "$(ui_t 'Größe des Ziel-Rootfs' 'Destination rootfs size')" \
  "$(ui_t 'Virtuelle Originalgröße' 'Original virtual size'): ${original_size} GiB\n${min_note}\n$(ui_t 'Die Angabe ist keine Garantie: erst nach Import ist reale Zielbelegung sicher.' 'This is not a guarantee: actual footprint is known after importing.')" \
  original "$(ui_t 'Originalgröße beibehalten' 'Keep original capacity') (${original_size} GiB)" \
  custom "$(ui_t 'Manuelle Größe festlegen' 'Enter custom capacity')" || return 0
 if [[ $UI_PICK == original ]]; then size=$original_size
 else
  proposed_size=$original_size
  ((min_gib>0)) && proposed_size=$min_gib
  ui_wizard_input 'Größe des Ziel-Rootfs' "${min_note}" "$proposed_size" || return 0
  size=$UI_INPUT
 fi
 [[ $size =~ ^[1-9][0-9]*$ ]] || { ui_wizard_notice 'Ungültige Größe' 'Eine positive Ganzzahl in GiB erforderlich.' || :; return 0; }
 if ((min_gib>0 && size<min_gib)); then
  ui_wizard_notice 'Ziel zu klein' "${size} GiB < ${min_gib} GiB. $(ui_t 'Mindestens 5% Reserve erforderlich.' 'At least 5% headroom required.')" || :
  return 0
 fi
 ui_archive_options
 ui_wizard_choice 'Temporäres Archiv' 'Aktive direkt eingebundene Verzeichnisse; FTP/SFTP nur als eingebundener Pfad.' "${UI_ARCHIVE_OPTIONS[@]}" || return 0
 archive=$UI_PICK
 if [[ $archive == custom ]]; then
  ui_wizard_input 'Archivverzeichnis' 'Vorhandener absoluter Pfad; freie Kapazität beachten.' '/var/tmp' || return 0
  archive=$UI_INPUT
 fi
 [[ $archive == /* && -d $archive && -w $archive ]] || { ui_wizard_notice 'Archivpfad ungültig' "Verzeichnis $archive muss existieren und beschreibbar sein." || :; return 0; }
 # The expensive full ownership scan/restore is temporarily disabled.
 # Full original numeric ownership stays in the source TAR for a later strict restoration.
 # CPU/memory are explicitly mapped; USB/PCI passthrough requires review.
 if ! ui_hardware_wizard "$cfg"; then return 0; fi
 params+=("${UI_HW_OPTIONS[@]}")
 ui_wizard_frame 'Gastnetzwerk erkennen'  'QEMU Guest Agent wird zuerst verwendet. VM-IP nicht aus qm config raten.'
 ui_put 10 5 "$(ui_t 'Prüfe Netzwerkidentität über QEMU Guest Agent ...' 'Checking network identity through QEMU Guest Agent ...')"
 if ui_guest_network_qga; then
  answer='qga'
 else
  ui_wizard_choice 'Gast-Zugriff' 'Kein QEMU Guest Agent erreichbar. SSH-Zugang für Netzwerkanalyse anbieten.' \
   ssh 'SSH-Zugang konfigurieren' offline 'Ohne Anmeldung fortfahren (Netzwerke manuell festlegen)' || return 0
  answer=$UI_PICK
  if [[ $answer == ssh ]]; then
   local sshhost sshuser sshmode sshpass=''
   ui_wizard_input 'SSH-Adresse des Gastes' 'IP oder Hostname – nicht durch den Proxmox-Host vorgegeben.' '' || return 0; sshhost=$UI_INPUT
   ui_wizard_input 'SSH-Benutzer' 'Root oder normaler Benutzer mit sudo.' 'root' || return 0; sshuser=$UI_INPUT
   if [[ $sshuser != root ]]; then
    ui_wizard_choice 'Berechtigungen' 'Bei weiteren geschützten Abfragen sudo -n oder interaktive Freigabe erforderlich.' sudo 'Benutzer besitzt sudo-Rechte' normal 'Kein sudo verfügbar' || return 0
    sshmode=$UI_PICK
   else sshmode=root; fi
   ui_wizard_choice 'SSH-Authentifizierung' 'Host-Key-Prüfung bleibt eingeschaltet.' key 'SSH-Schlüssel oder SSH-Agent (bevorzugt)' password 'SSH-Passwort (benötigt sshpass)' || return 0
   if [[ $UI_PICK == password ]]; then
    ui_wizard_input 'SSH-Passwort' 'Wird nicht in Argumenten oder Logs gespeichert.' '' 1 || return 0; sshpass=$UI_INPUT
   fi
   ui_wizard_frame 'Gastnetzwerk abfragen' 'SSH-Verbindung und Netzwerkprüfung laufen ...'
   if ui_guest_ssh_probe "$sshhost" "$sshuser" "$sshmode" "$sshpass"; then answer=ssh; UI_SSH_HOST=$sshhost; UI_SSH_USER=$sshuser; UI_SSH_PASS=$sshpass
   else answer=offline; ui_center_message "$(ui_t 'SSH konnte nicht abgefragt werden; erkannte IPs bleiben unbekannt.' 'SSH query failed; guest IP addresses remain unknown.')"; sleep 2; fi
   sshpass=''
  fi
 fi
 while IFS= read -r raw; do
  [[ $raw =~ ^net([0-9]+):[[:space:]]* ]] || continue
  n=${BASH_REMATCH[1]}
  mac=$(sed -nE 's/.*(virtio|e1000|rtl8139|vmxnet3|ne2k_pci|i82551|i82557|i82559)=([0-9A-Fa-f:]{17}).*/\2/p' <<< "$raw")
  ip='' gw=''
  if [[ $answer == qga ]]; then ip=$(ui_guest_net_by_mac "$mac" ipv4 || :); gw=$(ui_guest_route_qga "$mac" || :); fi
  if [[ $answer == ssh ]]; then ip=$(ui_guest_ssh_by_mac "$mac" || :); gw=$(ui_guest_ssh_gateway "$mac" || :); fi
  method='UNKNOWN|not-queried'; iface=''
  if [[ $answer == qga ]]; then
   iface=$(ui_guest_netname_by_mac "$mac" || :)
   [[ -n $iface ]] && method=$(ui_guest_ipv4_method "$iface")
  elif [[ $answer == ssh ]]; then
   iface=$(awk -v m="${mac,,}" '$2==m {print $1;exit}' <<< "${UI_SSH_DATA,,}")
   UI_GUEST_METHOD_SOURCE=ssh
   [[ -n $iface ]] && method=$(ui_guest_ipv4_method "$iface")
   UI_GUEST_METHOD_SOURCE=''
  fi
  case $method in
   DHCP\|*) displaymethod="$(ui_t 'DHCP (Konfiguration erkannt)' 'DHCP (configuration verified)')";;
   STATIC\|*) displaymethod="$(ui_t 'Statisch (Konfiguration erkannt)' 'Static (configuration verified)')";;
   MIXED\|*) displaymethod="$(ui_t 'Gemischt – manuelle Entscheidung' 'Mixed – manual decision')";;
   *) displaymethod="$(ui_t 'Unbekannt – nicht verifiziert' 'Unknown – unverified')";;
  esac
  [[ -n $ip ]] || ip='NICHT ERMITTELT'
  # Always offer the three explicit modes. "Static" preserves verified
  # current guest IP/CIDR + default gateway, regardless of detected method.
  # Manual is a completely independent input path (no silent DHCP fallback).
  while true; do
   ui_wizard_choice "Netzwerk net$n" "$(ui_network_detail "$n" "$raw" "$mac" "${ip/NICHT ERMITTELT/}" "$gw" "$displaymethod")" \
    static "$(ui_t 'Statisch: erkannte VM-IP/CIDR übernehmen' 'Static: use detected VM IP/CIDR')" \
    dhcp "$(ui_t 'DHCP: Adresse automatisch beziehen' 'DHCP: obtain address automatically')" \
    manual "$(ui_t 'Manuell: IP/CIDR, Gateway und DNS eingeben' 'Manual: enter IP/CIDR, gateway and DNS')" || return 0
   if [[ $UI_PICK == static ]] && ! ui_validate_ipv4_cidr "$ip"; then
    ui_wizard_notice "$(ui_t 'Keine gültige IP erkannt' 'No valid IP detected')" "$(ui_t 'Bitte Manuell oder DHCP wählen.' 'Choose Manual or DHCP.')" || :
    continue
   fi
   break
  done
  local chosen=$UI_PICK chosen_ip='' chosen_gw='' chosen_dns=''
  case $chosen in
   dhcp)
    params+=("--ip-net$n" dhcp)
    ;;
   static)
    if ! ui_validate_ipv4_cidr "$ip"; then
     ui_wizard_notice "$(ui_t 'Keine gültige IP erkannt' 'No valid IP detected')" \
       "$(ui_t 'Statisch kann nur mit gültiger erkannter IP/CIDR übernommen werden. Wähle Manuell.' 'Static reuse requires a valid detected IP/CIDR. Select Manual.')" || :
     return 0
    fi
    chosen_ip=$ip
    chosen_gw=$gw
    if [[ -n $chosen_gw ]] && ! ui_validate_ipv4 "$chosen_gw"; then
      ui_wizard_notice 'Gateway' "$(ui_t 'Erkanntes Gateway ist ungültig. Verwende Manuell.' 'Detected gateway is invalid. Use Manual.')" || :
      return 0
    fi
    params+=("--ip-net$n" "$chosen_ip")
    [[ -z $chosen_gw ]] || params+=("--gw-net$n" "$chosen_gw")
    ;;
   manual)
    # Manually entered values must never inherit an old gateway implicitly.
    while true; do
     ui_wizard_input "$(ui_t "IPv4-Adresse net$n" "IPv4 address net$n")" \
       "$(ui_t 'IPv4 mit Präfix, z.B. 192.0.2.10/24' 'IPv4 with prefix, e.g. 192.0.2.10/24')" \
       '' || return 0
     chosen_ip=$UI_INPUT
     ui_validate_ipv4_cidr "$chosen_ip" && break
     ui_wizard_notice "$(ui_t 'Ungültige IP/CIDR' 'Invalid IP/CIDR')" \
       "$(ui_t 'Erwartet wird eine IPv4-Adresse mit Präfix 0–32.' 'Enter an IPv4 address with prefix 0–32.')" || :
    done
    while true; do
     ui_wizard_input "$(ui_t "Gateway net$n" "Gateway net$n")" \
       "$(ui_t 'IPv4-Standardgateway; leer lassen falls keines erforderlich.' 'IPv4 default gateway; leave empty if not required.')" \
       '' || return 0
     chosen_gw=$UI_INPUT
     [[ -z $chosen_gw ]] && break
     ui_validate_ipv4 "$chosen_gw" && break
     ui_wizard_notice "$(ui_t 'Ungültiges Gateway' 'Invalid gateway')" \
       "$(ui_t 'IPv4-Adresse ohne Präfix erforderlich.' 'Enter an IPv4 address without prefix.')" || :
    done
    # DNS is configured at CT level by Proxmox, not per network adapter.
    # Only ask once; avoid silently overwriting values from another NIC.
    if [[ -z ${manual_dns_selected:-} ]]; then
     while true; do
      ui_wizard_input "$(ui_t 'DNS-Server (LXC)' 'DNS servers (LXC)')" \
        "$(ui_t 'Optional: IPv4-Server durch Leerzeichen trennen; leer = Proxmox-Standard.' 'Optional: space-separated IPv4 servers; empty = Proxmox default.')" '' || return 0
      chosen_dns=$UI_INPUT
      ui_validate_dns_list "$chosen_dns" && break
      ui_wizard_notice 'DNS' "$(ui_t 'Nur gültige IPv4-Adressen, durch Leerzeichen getrennt.' 'Only valid space-separated IPv4 addresses.')" || :
     done
     manual_dns_selected=1
     [[ -z $chosen_dns ]] || params+=(--nameserver "$chosen_dns")
    fi
    params+=("--ip-net$n" "$chosen_ip")
    [[ -z $chosen_gw ]] || params+=("--gw-net$n" "$chosen_gw")
    ;;
  esac
  local ip6_detected='' ipv6mode='' chosen_ip6='' chosen_gw6=''
  if [[ $answer == qga ]]; then ip6_detected=$(ui_guest_ipv6_qga "$mac" || :); fi
  ui_wizard_choice "$(ui_t "IPv6 für net$n" "IPv6 for net$n")" \
    "$(ui_t 'Erkannte IPv6' 'Detected IPv6'): ${ip6_detected:-$(ui_t 'Keine globale Adresse erkannt' 'No global address detected')}" \
    none "$(ui_t 'Keine automatische IPv6-Konfiguration (manual)' 'No automatic IPv6 configuration (manual)')" \
    auto "$(ui_t 'SLAAC / automatisch' 'SLAAC / automatic')" \
    dhcp "DHCPv6" \
    static "$(ui_t 'Erkannte IPv6 statisch übernehmen' 'Use detected IPv6 as static')" \
    manual "$(ui_t 'IPv6 manuell eingeben' 'Enter IPv6 manually')" || return 0
  ipv6mode=$UI_PICK
  case $ipv6mode in
   static)
    [[ $ip6_detected == */* && $ip6_detected == *:* ]] || { ui_wizard_notice "$(ui_t 'IPv6 nicht bekannt' 'IPv6 unknown')" "$(ui_t 'Keine eindeutige globale IPv6/CIDR gefunden. Manuell wählen.' 'No valid global IPv6/CIDR found. Choose manual.')" || :; return 0; }
    chosen_ip6=$ip6_detected;;
   manual)
    ui_wizard_input 'IPv6/CIDR' "$(ui_t 'Globale IPv6-Adresse mit Prefix, z.B. 2001:db8::5/64' 'Global IPv6 address with prefix, e.g. 2001:db8::5/64')" '' || return 0
    chosen_ip6=$UI_INPUT
    [[ $chosen_ip6 == *:*/* ]] || { ui_wizard_notice "$(ui_t 'IPv6 ungültig' 'Invalid IPv6')" "$(ui_t 'Adresse/CIDR erforderlich' 'Address/CIDR required')" || :; return 0; }
    ui_wizard_input "$(ui_t 'IPv6 Gateway' 'IPv6 gateway')" "$(ui_t 'Optional: IPv6 Gateway (leer falls keines)' 'Optional: IPv6 gateway (empty if none)')" '' || return 0
    chosen_gw6=$UI_INPUT;;
   none) chosen_ip6=manual;;
   *) chosen_ip6=$ipv6mode;;
  esac
  params+=("--ip6-net$n" "$chosen_ip6")
  [[ -z $chosen_gw6 ]] || params+=("--gw6-net$n" "$chosen_gw6")
  nets+=("net$n: $ip · $displaymethod · Gateway: ${gw:-keines erkannt} · IPv6: $chosen_ip6")
 done <<< "$cfg"
 ui_wizard_choice 'Aktion wählen' "VM $UI_VM → CT $ctid · $storage · ${size}GiB · Archiv: $archive" \
  plan 'Nur Prüfungen ausführen (Quelle bleibt unverändert)' \
  convert 'Offline-Konvertierung jetzt starten (VM ggf. herunterfahren)' || return 0
 mode=$UI_PICK
 if [[ -n ${UI_WIZARD_LOG:-} ]]; then
  printf '[%s] choices vm=%s ct=%s storage=%s rootfs_gib=%s archive=%s action=%s guest_access=%s\n' \
   "$(date -Is)" "$UI_VM" "$ctid" "$storage" "$size" "$archive" "$mode" "$answer" >> "$UI_WIZARD_LOG"
  printf '[%s] nic_choices: %s\n' "$(date -Is)" "${params[*]}" >> "$UI_WIZARD_LOG"
 fi
 if [[ $mode == convert ]]; then
  ui_wizard_choice 'VM-Shutdown' 'Konvertierung benötigt eine gestoppte VM. Original bleibt erhalten.' \
   yes 'Kontrolliertes Herunterfahren ausdrücklich erlauben' \
   no 'Nur konvertieren, falls VM bereits gestoppt ist' || return 0
  [[ $UI_PICK == yes ]] && params+=(--shutdown)
 fi
 local profile_path='' delete_intent=false hardware_json='' save_error=''
 if [[ $mode == convert ]]; then
  ui_wizard_choice "$(ui_t 'Quell-VM nach Migration' 'Source VM after migration')" \
    "$(ui_t 'Die VM wird nie automatisch nach dem Import gelöscht. Eine Löschung ist nur nach erfolgreichem LXC-Test separat möglich.' 'Source VM is never deleted on import. Removal is separate, only after testing the LXC.')" \
    keep "$(ui_t 'Quell-VM behalten (empfohlen)' 'Keep source VM (recommended)')" \
    later "$(ui_t 'Später nach Verifizierung Löschung anbieten' 'Offer deletion later after verification')" || return 0
  if [[ $UI_PICK == later ]]; then delete_intent=true; fi
 fi
 ui_wizard_checkpoint 'source-choice-complete'
 # Profiles are convenience data, not a prerequisite for executing the selection.
 # Never query the running/stopped guest again before showing the final screen.
 # The former ui_routing_snapshot made up to four synchronous guest-agent calls
 # here and could delay or interrupt the critical path.
 hardware_json=$(hw_inventory_json "$cfg" 2>/dev/null) || hardware_json='{}'
 if ! jq -e . >/dev/null 2>&1 <<< "$hardware_json"; then hardware_json='{}'; fi
 local profile_cache_key
 profile_cache_key=$(printf '%s\0' "$UI_VM" "$ctid" "$storage" "$size" "$archive" "$mode" "$delete_intent" "${params[@]}" | sha256sum | cut -d' ' -f1)
 if [[ $profile_cache_key == "${UI_WIZARD_PROFILE_CACHE_KEY:-}" && -f ${UI_WIZARD_PROFILE_CACHE_PATH:-/nonexistent} ]]; then
  profile_path=$UI_WIZARD_PROFILE_CACHE_PATH
  ui_wizard_checkpoint 'profile-reused'
 elif profile_path=$(PVE_VM2LXC_HW_JSON="$hardware_json" PVE_VM2LXC_DELETE_INTENT="$delete_intent" \
   profile_save "$UI_VM" "$ctid" "$storage" "$size" "$archive" "$mode" \
   "$( if [[ " ${params[*]} " == *' --shutdown '* ]]; then printf true; else printf false; fi )" "${params[@]}" 2>/dev/null); then
  UI_WIZARD_PROFILE_CACHE_KEY=$profile_cache_key
  UI_WIZARD_PROFILE_CACHE_PATH=$profile_path
  ui_wizard_checkpoint 'profile-saved'
 else
  profile_path=''
  save_error="$(ui_t 'Profil konnte nicht gespeichert werden; die direkte Ausführung ist trotzdem möglich.' 'Profile could not be saved; direct execution is still available.')"
  ui_wizard_checkpoint 'profile-save-failed'
 fi
 ui_wizard_frame 'Zusammenfassung' "VM $UI_VM → CT $ctid · $storage · ${size}GiB · $mode"
 ui_put 10 5 "$(ui_t 'Archiv' 'Archive'): $archive"
 ui_put 12 5 "$(ui_t 'Netzwerk' 'Network'): ${#nets[@]} $(ui_t 'Schnittstellen; MAC und Bridge werden übernommen' 'interfaces; MAC and bridge are preserved')"
 if [[ -n $profile_path ]]; then
  ui_put 14 5 "${UI_AMBER}$(ui_t 'Profil gespeichert' 'Profile saved'): $(basename -- "$profile_path")${UI_RESET}"
 else
  ui_put 14 5 "${UI_AMBER}$save_error${UI_RESET}"
 fi
 ui_put 16 5 "${UI_AMBER}$(ui_t 'Ausführung erst nach Bestätigung; Q bricht ab.' 'Execution requires confirmation; Q cancels.')${UI_RESET}"
 ui_wizard_checkpoint 'summary-shown'
 if ! ui_wizard_choice 'Ausführung bestätigen' 'Der Import kann eine VM herunterfahren. Prüfe Backup und freien Speicher.' \
   go 'Jetzt Migration ausführen' cancel 'Abbrechen und zurück zur VM'; then
  ui_wizard_checkpoint 'summary-cancelled'
  return 0
 fi
 if [[ $UI_PICK != go ]]; then
  ui_wizard_checkpoint 'execution-cancelled'
  return 0
 fi
 ui_wizard_checkpoint 'engine-launch-requested'
 # Start is independent of saving or loading a profile.
 if ! ui_engine_monitor "$mode" "$ctid" "$storage" "$size" "$archive" "${params[@]}"; then
  ui_wizard_checkpoint 'engine-monitor-error'
  ui_wizard_notice 'Migrationsstart fehlgeschlagen' \
   "$(ui_t 'Die Engine konnte nicht gestartet werden. Prüfe logs/wizard-flow-VMID.log.' 'Engine did not start. Check logs/wizard-flow-VMID.log.')" || :
 else
  ui_wizard_checkpoint 'engine-monitor-returned'
 fi

 return 0
}

# Live engine monitor: real TAR bytes, phase messages and synchronous y/n prompts.
# q cancels the engine process group. The source VM is NEVER restarted automatically.
ui_format_bytes() {
 local n=${1:-0}
 [[ $n =~ ^[0-9]+$ ]] || n=0
 if command -v numfmt >/dev/null 2>&1; then
  numfmt --to=iec-i --suffix=B "$n" 2>/dev/null || printf '%s B' "$n"
 else printf '%s B' "$n"; fi
}
ui_engine_monitor() {
 local mode=$1 ctid=$2 storage=$3 size=$4 archive=$5
 shift 5
 local -a params=("$@")
 local work runlog req resp reqfd respfd pid rc=0 confirm='' iter='' iterall='' answer='' archive_file='' estimate=0 bytes=0 percentage=-1 barwidth=38 bar='' raw='' latest='' line='' row current_ts prev_ts=0 prev_bytes=0 rate=0 eta=0 speed='' remaining='' 
 install -d -m 0700 "$ROOT_DIR/logs" || return 1
 work=$(mktemp -d "$ROOT_DIR/logs/.control-XXXXXXXX") || return 1
 chmod 0700 "$work"
 req="$work/requests"; resp="$work/replies"; runlog="$work/migration.log"
 mkfifo -m 0600 "$req" "$resp" || { rm -rf -- "$work"; return 1; }
 : > "$runlog"; chmod 0600 "$runlog"
 # Keep both FIFO ends open in the UI, so a crash of the child cannot hang opening them.
 exec {reqfd}<>"$req"
 exec {respfd}<>"$resp"
 # Separate process group: Q can stop the converter and its active tar/guestmount children.
 if ! command -v setsid >/dev/null 2>&1; then
  ui_wizard_notice 'Fehlende Abhängigkeit' 'setsid (util-linux) ist für sichere Abbruchbehandlung erforderlich.' || :
  exec {reqfd}>&-; exec {respfd}>&-; rm -rf -- "$work"
  return 1
 fi
 ENGINE_LOG_DIR="$ROOT_DIR/logs" ENGINE_CONFIRM_REQ="$req" ENGINE_CONFIRM_RESP="$resp" ENGINE_LANG="$UI_LANG" ENGINE_DEBUG="${ENGINE_DEBUG:-0}" \
  setsid bash -c 'source "$1"; shift; engine_main "$@"' pve-vm2lxc "$ROOT_DIR/lib/engine.sh" \
  "$mode" --vmid "$UI_VM" --ctid "$ctid" --storage "$storage" --size "$size" --archive-dir "$archive" "${params[@]}" > "$runlog" 2>&1 &
 pid=$!
 local monitor_initialized=0 monitor_prev='' task_type='' task_vmid='' task_since='' task_marker='' task_tick=0 task_log="$work/pve-task.log" task_node='' task_summary='' task_available=0 shown_log='' 
 : > "$task_log"
 if [[ -f "$ROOT_DIR/lib/task-monitor.sh" ]]; then
  source "$ROOT_DIR/lib/task-monitor.sh"
  if tm_available; then task_available=1; task_node=$(hostname -s); fi
 fi
 printf '\033[?25l'
 while true; do
  # Check for a pending confirmation first; the engine cannot advance until answered.
  if IFS= read -r -t 0.1 line <&$reqfd; then
   if [[ $line == ROOTPASSWORD\|* ]]; then
    local secret1='' secret2='' secret_hash='' pw_attempt valid=0
    ui_wizard_frame "$(ui_t 'LXC-root-Passwort' 'LXC root password')" "$(ui_t 'Neues Passwort für die Proxmox-Konsole festlegen (wird nicht protokolliert).' 'Set a new password for the Proxmox console (not logged).')"
    printf '\033[?25h'
    for ((pw_attempt=1;pw_attempt<=3;pw_attempt++)); do
     printf '\033[15;6H\033[2K%s' "$(ui_t 'Neues Passwort (min. 8 Zeichen): ' 'New password (min. 8 characters): ')"
     IFS= read -rs secret1 </dev/tty || break
     printf '\033[16;6H\033[2K%s' "$(ui_t 'Passwort wiederholen: ' 'Repeat password: ')"
     IFS= read -rs secret2 </dev/tty || break
     if (( ${#secret1} >= 8 )) && [[ $secret1 == "$secret2" ]]; then
      secret_hash=$(printf '%s\n' "$secret1" | openssl passwd -6 -stdin 2>/dev/null) || secret_hash=''
      valid=1
      break
     fi
     secret1='' secret2=''
     ui_put 18 5 "${UI_AMBER}$(ui_t 'Zu kurz oder unterschiedlich – bitte erneut eingeben.' 'Too short or mismatch – retry.')${UI_RESET}"
    done
    secret1='' secret2=''
    printf '%s\n' "$secret_hash" >&$respfd
    secret_hash=''
    printf '\033[?25l'
    monitor_initialized=0
    continue
   fi
   if [[ $line == CONFIRM\|* ]]; then
    IFS='|' read -r _ confirm iter iterall <<< "$line"
    while true; do
     ui_wizard_frame "$(ui_t 'Bestätigung erforderlich' 'Confirmation required')" "$(ui_t 'Nur y = Ja oder n = Nein. q = Abbruch.' 'Only y = Yes or n = No. q = Cancel.')"
     ui_put 10 5 "${UI_WHITE}$(ui_shorten "$confirm" "$(($(ui_width)-14))")${UI_RESET}"
     [[ $iterall == 2 ]] && ui_put 12 5 "${UI_AMBER}DEBUG: $iter/$iterall${UI_RESET}"
     ui_put 15 5 "${UI_BLUE}Y$(ui_t ' Ja' ' Yes')   N$(ui_t ' Nein' ' No')   Q $(ui_t 'Abbruch' 'Cancel')   Strg+L $(ui_t 'Sprache' 'Language')${UI_RESET}"
     ui_readkey || { answer=n; break; }
     case $UI_KEY in y|Y) answer=y; break;; n|N|q|Q|escape) answer=n; break;; language) ui_lang_toggle;; esac
    done
    printf '%s\n' "$answer" >&$respfd
    monitor_initialized=0
    continue
   fi
  fi
  # Locate the active Proxmox worker and fetch the same numbered task log
  # used by the Proxmox web UI. All queries are read-only and optional.
  local incoming_marker
  incoming_marker=$(sed -n 's/^\[INFO\] \[TASK\] //p' "$runlog" | tail -n 1)
  if [[ -n $incoming_marker && $incoming_marker != "$task_marker" ]]; then
   task_marker=$incoming_marker
   task_type=$(sed -n 's/.*type=\([^ ]*\).*/\1/p' <<< "$incoming_marker")
   task_vmid=$(sed -n 's/.*vmid=\([0-9]*\).*/\1/p' <<< "$incoming_marker")
   task_since=$(sed -n 's/.*since=\([0-9]*\).*/\1/p' <<< "$incoming_marker")
   TM_UPID=''; TM_LAST_N=0; task_tick=0; : > "$task_log"
  fi
  if ((task_available)) && [[ -n $task_type && -n $task_vmid && -n $task_since ]]; then
   # Poll once per 3 seconds; pvesh is not part of the actual import.
   current_ts=$(date +%s)
   if ((current_ts-task_tick>=3)); then
    task_tick=$current_ts
    if [[ -z ${TM_UPID:-} ]]; then
     tm_find "$task_node" "$task_vmid" "$task_type" "$task_since" || :
    fi
    if [[ -n ${TM_UPID:-} ]]; then tm_poll "$task_log" || :; fi
   fi
  fi
  task_summary=''
  if [[ -n ${TM_UPID:-} ]]; then
   task_summary="${task_type} · ${TM_STATUS:-running}"
   [[ -n ${TM_EXITSTATUS:-} ]] && task_summary+=" (${TM_EXITSTATUS})"
  elif [[ -n $task_type ]]; then
   task_summary="${task_type} · $(ui_t 'Worker-Protokoll wird gesucht' 'Looking for worker task log')"
  fi
  # Monitor content is updated in-place; never clear and redraw the whole screen
  # on every polling tick. Repaint the frame only on entry or language change.
  archive_file=$(sed -n 's/^\[INFO\] \[PROGRESS\] archive=//p' "$runlog" | tail -n 1)
  estimate=$(sed -n 's/^\[INFO\] \[PROGRESS\] capacity_bytes=//p' "$runlog" | tail -n 1)
  [[ $estimate =~ ^[0-9]+$ ]] || estimate=0
  bytes=0; percentage=-1
  if [[ -n $archive_file && -f $archive_file ]]; then
   bytes=$(stat -c '%s' -- "$archive_file" 2>/dev/null || echo 0)
   [[ $bytes =~ ^[0-9]+$ ]] || bytes=0
   if ((estimate>0)); then
    percentage=$((bytes * 100 / estimate))
    ((percentage>100)) && percentage=100
   fi
  fi
  current_ts=$(date +%s)
  if ((prev_ts>0 && current_ts>prev_ts && bytes>=prev_bytes)); then
   rate=$(((bytes-prev_bytes)/(current_ts-prev_ts)))
  fi
  if ((current_ts>prev_ts)); then prev_ts=$current_ts; prev_bytes=$bytes; fi
  speed=$(ui_format_bytes "$rate")/s
  # TARGET_SIZE is NOT estimated payload, so do not derive fake ETA from it.
  remaining='—'
  latest=$(grep -E '^\[(INFO|WARNUNG|ERROR)\]' "$runlog" | grep -v '\[PROGRESS\]' | tail -n 1 || :)
  if [[ ${monitor_initialized:-0} == 0 ]]; then
   ui_wizard_frame "$(ui_t 'Migration läuft' 'Migration running')" "VM $UI_VM → CT $ctid · $(ui_t 'Live-Überwachung' 'Live monitoring')"
   monitor_initialized=1
   monitor_prev=''
  fi
  # Redraw only changed rows; terminal cursor is hidden while monitoring.
  local status_text progress_text bar_text foot_text recent_text
  status_text="${UI_BLUE}$(ui_t 'Status' 'Status'):${UI_RESET} $(ui_shorten "${latest:-$(ui_t 'Vorbereitung läuft ...' 'Preparing ...')}" "$(($(ui_width)-16))")"
  progress_text="${UI_BLUE}$(ui_t 'Archivdaten geschrieben' 'Archive data written'):${UI_RESET} $(ui_format_bytes "$bytes")  ·  $speed  ·  ETA: $remaining"
  if ((percentage>=0)); then
   barwidth=$(($(ui_width)-33)); ((barwidth>60)) && barwidth=60; ((barwidth<10)) && barwidth=10
   local full=$((barwidth*percentage/100))
   bar=$(printf '%*s' "$full" '' | tr ' ' '#')
   bar+=$(printf '%*s' "$((barwidth-full))" '' | tr ' ' '-')
   bar_text="${UI_GREEN}[$bar]${UI_RESET} ${percentage}% $(ui_t 'des gewählten Rootfs-Budgets (KEIN Kopierfortschritt)' 'of selected rootfs capacity (NOT copy completion)')"
  else
   bar_text="${UI_MUTED}$(ui_t 'Dateisystemprüfung / Vorbereitung ...' 'Filesystem scan / preparation ...')${UI_RESET}"
  fi
  foot_text="${UI_AMBER}$(ui_t 'Q: kontrollierten Abbruch anfordern · Strg+L: Sprache' 'Q: request controlled cancellation · Ctrl+L: language')${UI_RESET}"
  # During Proxmox workers prefer their actual task logs; otherwise show
  # raw engine output including the lines which do not have [INFO] prefixes.
  if [[ -s $task_log ]]; then
   shown_log=$task_log
  else
   shown_log=$runlog
  fi
  recent_text=$(tail -n 8 "$shown_log" | tm_safe_text)
  if grep -Eqi 'cannot change ownership|invalid argument|task error|failed|no space left' <<< "$recent_text"; then
   task_summary+="  $(ui_t '· FEHLER im Protokoll' '· ERROR in log')"
  fi
  local snapshot
  snapshot=$(printf '%s\n' "$status_text" "$progress_text" "$bar_text" "$foot_text" "$task_summary" "$recent_text")
  if [[ $snapshot != "${monitor_prev:-}" ]]; then
   ui_monitor_line 10 "$status_text"
   ui_monitor_line 12 "$progress_text"
   ui_monitor_line 14 "$bar_text"
   ui_monitor_line 16 "${UI_BLUE}$(ui_t 'Proxmox Task' 'Proxmox task'):${UI_RESET} ${task_summary:-$(ui_t 'Warte auf Worker' 'Awaiting worker')}"
   ui_monitor_line 18 "${UI_BLUE}$(ui_t 'Live-Taskprotokoll / Engine-Ausgabe' 'Live task log / engine output')}:${UI_RESET}"
   row=20
   while ((row<29 && row<$(ui_height)-5)); do
    ui_monitor_line "$row" ''
    ((row+=1))
   done
   row=20
   while IFS= read -r raw; do
    ((row<29 && row<$(ui_height)-5)) || break
    if [[ $raw == *'Cannot change ownership'* || $raw == *'Invalid argument'* || $raw == *'ERROR'* || $raw == *'failed'* ]]; then
      ui_monitor_line "$row" "${UI_AMBER}$(ui_shorten "$raw" "$(($(ui_width)-12))")${UI_RESET}"
    else
      ui_monitor_line "$row" "$(ui_shorten "$raw" "$(($(ui_width)-12))")"
    fi
    ((row+=1))
   done <<< "$recent_text"
   ui_monitor_line "$(($(ui_height)-4))" "$foot_text"
   monitor_prev=$snapshot
  fi
  if ! kill -0 "$pid" 2>/dev/null; then break; fi
  # Non-blocking keyboard poll, no need to press Enter.
  local key=''
  if IFS= read -rsn1 -t 0.25 key </dev/tty; then
   case $key in
    l|L) ui_lang_toggle; monitor_initialized=0;;
    q|Q)
     ui_wizard_frame "$(ui_t 'Migration abbrechen?' 'Cancel migration?')" "$(ui_t 'VM bleibt ggf. gestoppt; Teilarchive bleiben bestehen.' 'VM may remain stopped; partial archives will be kept.')"
     ui_put 10 5 "$(ui_t 'y = Abbrechen · n = Fortsetzen' 'y = Cancel · n = Continue')"
     ui_readkey || :
     if [[ $UI_KEY == y || $UI_KEY == Y ]]; then
      # Child and its descendants are terminated only when possible; no automatic rollback.
      kill -TERM -- "-$pid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null || :
      ui_wizard_frame "$(ui_t 'Abbruch angefordert' 'Cancellation requested')" "$(ui_t 'Prüfe angehaltene Prozesse und Mounts.' 'Check remaining processes and mounts.')"
      break
     fi
     ;;
   esac
  fi
 done
 wait "$pid" || rc=$?
 printf '\033[?25h'
 exec {reqfd}>&-
 exec {respfd}>&-
 # Save the monitor log next to engine logs for troubleshooting after TUI exit.
 local savedlog="${ROOT_DIR}/logs/$(date -u +%Y%m%dT%H%M%SZ)-vm${UI_VM}-ct${ctid}-monitor.log"
 if [[ -d ${ROOT_DIR}/logs ]]; then
  cp -- "$runlog" "$savedlog" 2>/dev/null || savedlog="$runlog"
  [[ $savedlog != "$runlog" ]] && chmod 0600 "$savedlog"
 else savedlog="$runlog"; fi
 if [[ -s $task_log && -d ${ROOT_DIR}/logs ]]; then
   install -m 0600 "$task_log" "${savedlog%.log}-proxmox-task.log" || :
 fi
 ui_wizard_frame "$(ui_t 'Migration beendet' 'Migration finished') · Exit $rc" "$(ui_t 'Protokoll' 'Log'): $savedlog"
 ui_put 10 5 "$(ui_t 'Beende den Assistenten mit Enter, zurück mit Q.' 'Press Enter to return, Q to cancel.')"
 ui_readkey || :
 rm -rf -- "$work"
 return 0
}
