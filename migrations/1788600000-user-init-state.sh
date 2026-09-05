#!/usr/bin/env bash
# openjawz-migration: create the per-user state tree (proves the runner; changes nothing else)
# scope: user
set -euo pipefail
. "${OPENJAWZ_LIB:-/usr/lib/openjawz}/openjawz.sh"
oj::paths
mkdir -p "$OPENJAWZ_STATE/migrations" "$OPENJAWZ_STATE/backups" "$OPENJAWZ_HOME" "$OPENJAWZ_DATA" "$OPENJAWZ_CONFIG"
