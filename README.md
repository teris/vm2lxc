# PVE VM2LXC — 1.0.0

An interactive Bash-based Linux VM → LXC migration assistant for **Proxmox VE**.

> **Release scope:** Version 1.0.0 is the first packaged GitHub release, **not a guarantee of lossless or universal migrations**. Test on disposable Linux guests, keep verified backups, and validate applications, files, network and security after converting. No migration has been executed in this CI/container environment against a real Proxmox host.

## Deutsch

### Start ohne Installation

```bash
unzip pve-vm2lxc-v1.0.0.zip
cd pve-vm2lxc-v1.0.0
bash bin/pve-vm2lxc --version
bash bin/pve-vm2lxc
```

Der vollständige `bin/`- und `lib/`-Ordner sowie `VERSION` müssen zusammen bleiben. Im Root-Verzeichnis des aktuellen Checkouts werden automatisch die Unterverzeichnisse **`logs/`** und **`profiles/`** angelegt. Alle Protokolle (einschließlich temporärer TUI-Protokolle und Proxmox-Task-Ausgaben) verbleiben dort. Diese Verzeichnisse sind in `.gitignore` ausgeschlossen. **Nicht mit Git veröffentlichen.**

### Optionale Installation

```bash
sudo bash install.sh
pve-vm2lxc
```

Installiert nach `/opt/pve-vm2lxc/`, verknüpft `/usr/local/bin/pve-vm2lxc`; Logs und Profile werden in `/opt/pve-vm2lxc/logs/` und `/opt/pve-vm2lxc/profiles/` gespeichert. Hostweite Schreibrechte werden nicht für normale Benutzer eingeräumt; Proxmox-Migrationen benötigen Root-Rechte.

### Tastatursteuerung

| Taste | Aktion |
| --- | --- |
| `↑` / `↓`, `Enter` | Auswählen / nächsten Schritt bestätigen |
| **`Strg+R`** | **Genau einen Schritt zurück** (im Assistenten auch zwischen Eingabefeldern) |
| **`Esc`** | **Assistent neu starten**; im Hauptmenü zur Startseite |
| **`Alt+R`** | Aktuelle Listenansicht neu von Proxmox laden |
| **`Strg+L`** | Deutsch / Englisch umschalten |
| **`Strg+D`** | Nur in der Profilübersicht: ausgewähltes Profil nach Rückfrage löschen |
| `Q` | Assistent verlassen bzw. bei laufender Migration kontrollierten Abbruch anfordern |

**PuTTY:** Bei Alt-Kombinationen muss PuTTY `Alt` als Escape-Prefix senden. Eine Aktualisierung erfolgt bewusst nicht bei jedem Tastendruck. Während einer **laufenden Migration** ist `Esc` kein sicherer Abbruch; `Q` benutzt die dafür vorgesehene Bestätigung. Der Schrittverlauf wird nur vor dem Engine-Start verwaltet. Frühere Eingaben können erneut angezeigt werden; Passwörter werden nie im Verlauf gespeichert.

### Profile

Im Hauptmenü »Gespeicherte Migrationsprofile« öffnen und `Strg+D` auf dem gewünschten Eintrag drücken. Alternativ:

```bash
bash bin/pve-vm2lxc profiles list
bash bin/pve-vm2lxc profiles show DATEINAME.json
bash bin/pve-vm2lxc profiles run DATEINAME.json
bash bin/pve-vm2lxc profiles delete DATEINAME.json
```

Löschen entfernt **nur** die ausgewählte Profil-JSON, niemals VM, CT oder deren Disks. Profile enthalten keine Passwörter.

### Voraussetzungen / Grenzen

- Proxmox VE Host mit `qm`, `pct`, `pvesm`, `pvesh`, Bash, `util-linux`, `tar`, `jq`, `libguestfs-tools`; für weitere Fälle `acl`/`attr` und OpenSSL. Fehlende Abhängigkeiten werden geprüft; automatische Installation nur nach Zustimmung.
- Konvertiert Linux-Dateisysteme offline nach geplantem VM-Shutdown. **Keine Unterstützung für Windows-, macOS- oder BSD-Gäste**.
- Linux-Container teilen sich den Kernel des Hosts: QEMU-PCI/USB-Passthrough, eigene Kernelmodule und bestimmte Boot-Eigenschaften sind nicht unverändert übertragbar.
- Mehrere Gast-Dateisysteme werden im aktuellen Schnellimport zusammengeführt; separate Mountpoints, komplexe ACLs/Xattrs und beliebige numerische UID/GID-Besitzer werden derzeit **nicht vollständig verlustfrei** übernommen. Die Ziel-Dateien werden im Schnellimport vereinfacht root zugeordnet. Vor Inbetriebnahme Dateibesitzer und Dienste prüfen.
- Der LXC erhält nach dem Import eine kontrollierte Netzwerk-Konfiguration und optional Nesting nach systemd-Erkennung. Source VM wird **nie automatisch gelöscht**, und die alte VM darf bei identischen MAC/IP nicht parallel mit dem neuen CT laufen.
- Das neue Container-Root-Passwort wird verdeckt abgefragt und im gestoppten Container eingerichtet; es wird nicht in Profilen oder Logs gespeichert.
- Vor produktiver Migration: Quell-VM sichern, genügend Platz prüfen, Testlauf durchführen und den LXC ausdrücklich verifizieren.

### Fehlerdiagnose

```bash
ls -lah ./logs
bash bin/pve-vm2lxc --debug
```

`--debug` verdoppelt bestimmte Bestätigungen und schreibt Diagnoseprotokolle; es ist **kein** Dry-Run. Für reine Prüfungen den Modus »Nur Prüfungen ausführen« wählen. Der Quell-VM-Datenträger wird für den Offline-Import schreibgeschützt eingebunden; die Konvertierung kann die Quell-VM jedoch kontrolliert herunterfahren.

## English

### Run without installation

```bash
bash bin/pve-vm2lxc --version
bash bin/pve-vm2lxc
```

Keep `bin/`, `lib/` and `VERSION` together. Logs and profiles are written under the current project checkout's `logs/` and `profiles/` directories regardless of the working directory. An optional `sudo bash install.sh` installs to `/opt/pve-vm2lxc`.

### Shortcuts

`Ctrl+R` = previous wizard step; `Esc` = restart wizard; `Alt+R` = refresh list; `Ctrl+L` = toggle language; `Ctrl+D` = delete selected saved profile after confirmation; `Q` = quit/request safe cancellation. Passwords are never retained in wizard history.

### Limitations and security

Use on Proxmox VE, as root, with the dependencies listed in the German section. The source VM is preserved by default. The converter cannot guarantee identical kernel or device behavior, cannot yet preserve all non-root owners/ACLs/mountpoints in the fast-import path, and cannot infer complex routing automatically. Test migrated services and file permissions before deployment. Do not publish `logs/` or `profiles/` (both ignored by Git). No end-to-end Proxmox conversion was run as part of this release build.

## Development / GitHub

- MIT license: [LICENSE](LICENSE)
- Change history: [CHANGELOG.md](CHANGELOG.md)
- Contribution guide: [CONTRIBUTING.md](CONTRIBUTING.md)
- GitHub Actions runs syntax and isolated mock tests; integration tests **require a disposable Proxmox VE host**.
- Open issues with **redacted** logs and the Proxmox version; never publish IP addresses, keys, tokens, passwords or raw guest archives.

```bash
for script in tests/test-*.sh; do bash "$script" || exit 1; done
```
