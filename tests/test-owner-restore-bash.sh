#!/usr/bin/env bash
set -Eeuo pipefail
ROOT=$(cd -- "$(dirname -- "$0")/.." && pwd)
source "$ROOT/lib/owner-restore.sh"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/src/data" "$T/dst/data" "$T/bin"
printf 'data\n' > "$T/src/data/a file.txt"
cp "$T/src/data/a file.txt" "$T/dst/data/a file.txt"
# Tests do not require installing host ACL packages. Real execution requires both.
cat > "$T/bin/getfacl" <<'EOF'
#!/bin/sh
printf 'user::rw-\ngroup::r--\nother::r--\n'
EOF
cat > "$T/bin/setfacl" <<'EOF'
#!/bin/sh
exit 0
EOF
cat > "$T/bin/getfattr" <<'EOF'
#!/bin/sh
exit 0
EOF
cat > "$T/bin/setfattr" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "$T/bin"/*
export PATH="$T/bin:$PATH"
if [[ $(id -u) == 0 ]]; then
 chown 1000:1001 "$T/src/data/a file.txt"
 owner_restore scan "$T/src" "$T/dst" 0 0
 owner_restore apply "$T/src" "$T/dst" 0 0
 owner_restore verify "$T/src" "$T/dst" 0 0
 [[ $(stat -c '%u:%g' "$T/dst/data/a file.txt") == 1000:1001 ]]
 chown 2119470584:2042662593 "$T/src/data/a file.txt"
 if owner_restore scan "$T/src" "$T/dst" 0 0 2>/dev/null; then echo 'High-ID scan unexpectedly passed' >&2; exit 1; fi
 printf '{"uids":{"2119470584":1002},"gids":{"2042662593":1003}}\n' > "$T/map.json"
 owner_restore scan "$T/src" "$T/dst" 0 0 "$T/map.json"
 owner_restore apply "$T/src" "$T/dst" 0 0 "$T/map.json"
 owner_restore verify "$T/src" "$T/dst" 0 0 "$T/map.json"
 [[ $(stat -c '%u:%g' "$T/dst/data/a file.txt") == 1002:1003 ]]
fi
printf 'PASS bash owner mapping without Python\n'
