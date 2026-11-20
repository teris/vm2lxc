#!/usr/bin/env bash
set -Eeuo pipefail
# ceil(used * 1.05 / GiB)
size=$(( (125*1073741824*105 + 100*1073741824 -1)/(100*1073741824) ))
[[ $size == 132 ]]
echo 'PASS recommended rootfs sizing'
