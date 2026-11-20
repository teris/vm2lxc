#!/bin/sh
# Read-only IPv4 configuration method detector executed INSIDE a Linux guest.
# Output: DHCP|source, STATIC|source, MIXED|source, or UNKNOWN|reason.
# It does not infer configuration method from a currently assigned address or lease.
set -u
iface=${1:-}
case "$iface" in ''|*[!a-zA-Z0-9_.:@-]*) printf 'UNKNOWN|invalid-interface\n'; exit 0;; esac
emit() { printf '%s|%s\n' "$1" "$2"; exit 0; }
# NetworkManager: query the active profile, never an arbitrary saved profile.
if command -v nmcli >/dev/null 2>&1; then
  connection=$(LC_ALL=C nmcli -g GENERAL.CONNECTION device show "$iface" 2>/dev/null | head -n 1)
  if [ -n "$connection" ] && [ "$connection" != '--' ]; then
    method=$(LC_ALL=C nmcli -g ipv4.method connection show "$connection" 2>/dev/null | head -n 1)
    static_addresses=$(LC_ALL=C nmcli -g ipv4.addresses connection show "$connection" 2>/dev/null | head -n 1)
    case "$method" in auto) if [ -n "$static_addresses" ] && [ "$static_addresses" != "--" ]; then emit MIXED NetworkManager; else emit DHCP NetworkManager; fi;; manual) emit STATIC NetworkManager;; disabled|ignore|shared|link-local) emit UNKNOWN "NetworkManager:$method";; esac
  fi
fi
# systemd-networkd: inspect the .network file actually selected for this interface.
if command -v networkctl >/dev/null 2>&1; then
  file=$(LC_ALL=C networkctl status "$iface" --no-pager 2>/dev/null | sed -n 's/^[[:space:]]*Network File:[[:space:]]*//p' | head -n 1)
  if [ -f "$file" ]; then
    vals=$(awk '
      /^\[/ { inside=($0=="[Network]"); next }
      inside && /^[[:space:]]*(DHCP|Address)[[:space:]]*=/ {gsub(/[[:space:]]/,"",$0); print $0}
    ' "$file")
    dhcp=$(printf '%s\n' "$vals" | sed -n 's/^DHCP=//p' | tail -n 1)
    has_address=0
    printf '%s\n' "$vals" | grep -q '^Address=' && has_address=1
    case "$dhcp" in yes|ipv4|true) if [ "$has_address" -eq 1 ]; then emit MIXED systemd-networkd; else emit DHCP systemd-networkd; fi;;
      no|ipv6|false|'') if [ "$has_address" -eq 1 ]; then emit STATIC systemd-networkd; fi;; esac
  fi
fi
# ifupdown and Alpine networking: explicit 'iface NAME inet dhcp/static' declarations.
# /etc/network/interfaces.d contains both included snippets and common direct configuration.
if [ -f /etc/network/interfaces ] || [ -d /etc/network/interfaces.d ]; then
  method=$(
    { [ ! -f /etc/network/interfaces ] || cat /etc/network/interfaces;
      if [ -d /etc/network/interfaces.d ]; then
        find /etc/network/interfaces.d -maxdepth 1 -type f -exec cat {} \; 2>/dev/null
      fi; } | awk -v n="$iface" '$1=="iface" && $2==n && $3=="inet" {print $4}' | sort -u
  )
  case "$method" in dhcp) emit DHCP ifupdown;; static) emit STATIC ifupdown;; esac
fi
# Traditional SUSE/RHEL interface configuration. NetworkManager takes precedence above.
for file in "/etc/sysconfig/network/ifcfg-$iface" "/etc/sysconfig/network-scripts/ifcfg-$iface"; do
  [ -f "$file" ] || continue
  method=$(sed -nE 's/^[[:space:]]*BOOTPROTO=["\x27]?([^"\x27[:space:]]+).*/\1/p' "$file" | head -n 1)
  case "$method" in dhcp|bootp) emit DHCP sysconfig;; static|none) emit STATIC sysconfig;; esac
done
# Netplan is commonly rendered into NetworkManager or systemd-networkd configs above.
# Raw YAML cannot be safely regex-parsed when match rules and multiple interfaces exist.
emit UNKNOWN 'no-unambiguous-config'
