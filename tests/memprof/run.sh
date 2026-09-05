#!/usr/bin/env bash
# ci: fast
# memprof: in CI prove the ported scripts parse (gates.sh --dry); on the bench box run the real gates
# with OPENJAWZ_MEMPROF=1. Exit 0/1/77.
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
if [ "${OPENJAWZ_MEMPROF:-0}" = 1 ]; then exec bash "$HERE/gates.sh"; fi
exec bash "$HERE/gates.sh" --dry
