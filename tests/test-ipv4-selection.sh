#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "$0")/.." && pwd)
# Source the UI without running it; test the same validation used by the wizard.
source "$ROOT/lib/tui.sh"
for valid in 10.77.0.112/24 135.125.128.236/32 0.0.0.0/0; do
  ui_validate_ipv4_cidr "$valid" || { echo "FAIL valid: $valid" >&2; exit 1; }
done
for invalid in 10.77.0.112 10.77.0.999/24 1.2.3.4/33 1.2.3.4/-1 dhcp 'a.b.c.d/24'; do
  if ui_validate_ipv4_cidr "$invalid"; then echo "FAIL invalid: $invalid" >&2; exit 1; fi
done
ui_validate_dns_list ''
ui_validate_dns_list '1.1.1.1 9.9.9.9'
if ui_validate_dns_list '1.1.1.999'; then exit 1; fi
echo 'PASS IPv4/CIDR and DNS validation'
