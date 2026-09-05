#!/usr/bin/env bash
# openjawz-migration: <one line: what this changes and why>
# scope: user            (user | system — must match the filename)
set -euo pipefail
. /usr/lib/openjawz/openjawz.sh
oj::paths

# Guard first: if the change is already in place, exit 0 without touching anything.
# [ -e "$OPENJAWZ_STATE/example" ] && exit 0

# Then the change, idempotently.
# mkdir -p "$OPENJAWZ_STATE/example"
