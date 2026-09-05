#!/usr/bin/env bash
# ops/lib/source-lib.sh — find lib/openjawz.sh (installed or in-tree), else the compat shim.
# Usage (from any ops/crew/brain verb):  . "$(dirname "$(readlink -f "$0")")/../ops/lib/source-lib.sh"
_oj_here=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
for _oj_lib in "${OPENJAWZ_LIB:-/usr/lib/openjawz}/openjawz.sh" "$_oj_here/../../lib/openjawz.sh"; do
  if [ -r "$_oj_lib" ]; then
    # shellcheck source=/dev/null
    . "$_oj_lib"; break
  fi
done
if ! declare -F oj::paths >/dev/null 2>&1; then
  # shellcheck source=compat.sh
  . "$_oj_here/compat.sh"
fi
unset _oj_here _oj_lib
oj::paths
