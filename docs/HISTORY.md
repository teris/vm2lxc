# v0.5.9 – Funktionen und Grenzen

## Migrationsprofile

Der TUI-Assistent speichert vor der Ausführung ein JSON-Profil im Projektordner `profiles/` (bei Installation: `/opt/pve-vm2lxc/profiles/`). Beispiel: `vm-102-ct-117-20261119T201100Z.json`.

Nach dem Installieren:

```bash
pve-vm2lxc profiles list
pve-vm2lxc profiles show vm-102-ct-117-20261119T201100Z.json
pve-vm2lxc profiles run vm-102-ct-117-20261119T201100Z.json
```

Zusätzlich ist im Hauptmenü "Gespeicherte Profile" verfügbar. Profile enthalten keine SSH-Passwörter; sie sind mit 0600 geschützt. Sie enthalten allerdings möglicherweise interne IP-Adressen, Pfade und andere Infrastrukturdetails. Das Projektverzeichnis und exportierte Profile müssen sicher verwaltet werden. Ein gespeicherter Migrationsplan ist **keine Garantie**, dass ein späterer Lauf erfolgreich ist. Storage, Gastzustand und Ziel-ID werden neu geprüft.

## Löschung der Quell-VM

Keine automatische Löschung bei `convert` oder `activate` – auch nach erfolgreichem Import nicht. Nach eigenständiger Prüfung von Container, Anwendungen, Netzwerken und Backups kann optional folgender **separater und destruktiver** Befehl ausgeführt werden:

```bash
pve-vm2lxc finalize --vmid 102 --ctid 117
```

Die Quell-VM muss gestoppt, der Ziel-LXC gestartet und als zur VM gehörend markiert sein. Die Löschung erfordert ein `y/n` und eine erneute Eingabe der VM-ID. Das Tool kann die Integrität individueller Anwendungen nicht automatisch garantieren. `qm destroy` kann Quell-VM-Volumes löschen.

## Volumengröße

Der Wizard verwendet die aus `qm config` ermittelte Originalkapazität und – falls verfügbar – die `used-bytes` von `qm guest cmd VMID get-fsinfo`. Alle erkannten regulären Dateisysteme gehen in die Schätzung ein. Als Mindestwert dient `ceil(Belegung * 1.05 / GiB)`. Bei 125 GiB Belegung sind das **132 GiB**. Ohne verlässliche Belegungsinformationen wird die Originalgröße empfohlen und keine Mindestgröße behauptet. Die 5% sind ein Minimalpuffer, keine Erfolgsgarantie. Während der späteren Archivierung können Datenbedarf, Sparse-Dateien, zusätzliche Mounts und Inodes abweichen. Für produktiven Betrieb ist häufig ein größerer Puffer sinnvoll.

## IPv6 und erweitertes Routing

IPv6-Optionen sind pro NIC im TUI verfügbar: `auto` (SLAAC), `dhcp`, erkannte globale IPv6/CIDR oder manuelle IPv6/CIDR mit optionalem `gw6`. Die Engine setzt `ip6` und `gw6` in der Proxmox-LXC-NIC-Konfiguration. Dies entspricht dem Proxmox-pct-Schema.

Policy-Routing, mehrere Routingtabellen und komplexe Regeln werden **nicht automatisch angewandt**: Der Wizard versucht beim laufenden QEMU-Gast eine read-only Snapshotabfrage von `ip -j rule show` und `ip -j route show table all` in JSON-Protokolle. Diese Snapshots sind diagnostisch; bei fehlendem Gastagenten können sie unvollständig sein. Unterschiedliche Distributionen verwenden dafür verschiedene persistente Netzwerk-Konfigurationen und ein generischer Rewrite wäre gefährlich. Vor einem produktiven Aktivieren muss bei komplexen Routing-Regeln die Übernahme manuell geprüft werden. Keine Behauptung vollständiger Policy-Routing-Migration.

## Unveränderte Einschränkungen

Der Import legt weiterhin **ein zusammengeführtes Rootfs** an, statt getrennte Proxmox-Volumes für jedes Gastsystem-Dateisystem. Nur Linux-Gäste, keine Garantie für Docker, Kernelmodule, PCI- oder USB-Passthrough. Kein End-to-End-Test auf einem echten Proxmox-System in dieser Entwicklungsumgebung. Die Quell-VM bleibt erhalten.

## Profiloption zur späteren Löschung

Im Migrationswizard wird gefragt, ob die VM behalten werden soll (Standard) oder ob nach erfolgreich nachgewiesener Funktion des LXC eine separate Löschung angeboten werden soll. Diese Absicht wird im JSON als `delete_after_verification` gespeichert. Sie löst **keine Löschung** aus. Erst der ausdrückliche `finalize`-Befehl nach Aktivierung und unabhängiger Prüfung kann die VM löschen.

### v0.6.11 – systemd/Nesting & Root-Konsole

- Offline-Gastsystem wird anhand `/etc/os-release` und init-Dateien erkannt. Bei Debian und Arch kann die systemd-Version aus der Paket-Datenbank gelesen werden; andere Distributionen werden nicht geraten. Bei unbekannter Version ist die Nesting-Wahl manuell.
- Für systemd-Version >241 bietet der Assistent Nesting an (Proxmox selbst warnt ab dieser Grenze). Eine Ablehnung bleibt zulässig; Standard ohne Notwendigkeit ist kein Nesting. `--nesting auto|on|off` für CLI und Profile.
- Nach dem Import fragt die Konsole **zwingend** zweimal ein neues Passwort für LXC `root` ab. Mindestens 8 Zeichen; das Passwort wird im gestoppten Container als SHA-512 crypt in `/etc/shadow` gesetzt. OpenSSL (`openssl passwd -6`) wird dafür benötigt. Bei Fehlern bleibt das Ziel gestoppt.
- Das Passwort wird **nicht** in Logs, JSON-Profilen oder Proxmox-Argumenten gespeichert. Es ist für die Login-Konsole relevant; `pct enter` von Proxmox als Host-root authentifiziert weiterhin nicht per Gast-Passwort.
- Nicht alle Gäste unterstützen SHA-512 crypt. Bei nicht unterstützter Authentifizierung ist eine manuelle, distro-spezifische Passwortkorrektur erforderlich. Auf Systemen ohne `/etc/shadow` stoppt der Import mit einer nachvollziehbaren Fehlermeldung.
- Kein Python nötig. Die bisherige v0.6.9-Einschränkung auf vereinfachte Dateieigentümer bleibt bestehen.


### v0.6.11: Direct wizard completion

After selecting the source-VM retention policy, the wizard no longer makes any QEMU guest-agent calls before the final confirmation. A failed JSON profile save is shown as a warning but does not prevent direct conversion. Each stage is logged without credentials to `/var/log/pve-vm2lxc/wizard-flow-<VMID>.log`.
