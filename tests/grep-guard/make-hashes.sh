#!/usr/bin/env bash
# Regenerate forbidden.hmac from a PRIVATE word list + a PRIVATE key. Neither is ever committed.
#   OPENJAWZ_GUARD_KEY=<hex>  OPENJAWZ_PRIVATE_WORDS=<file>  tests/grep-guard/make-hashes.sh
# Digests are HMAC-SHA256(key, lowercase word): without the key the list is not a dictionary oracle.
set -euo pipefail
: "${OPENJAWZ_GUARD_KEY:?set OPENJAWZ_GUARD_KEY (hex; never committed)}"
src="${OPENJAWZ_PRIVATE_WORDS:?set OPENJAWZ_PRIVATE_WORDS (private word list; never committed)}"
here="$(cd "$(dirname "$0")" && pwd)"
grep -v '^\s*#' "$src" | grep -oE '[A-Za-z0-9]{3,}' | tr 'A-Z' 'a-z' | sort -u \
  | while read -r w; do printf '%s' "$w" | openssl dgst -sha256 -mac HMAC -macopt "hexkey:$OPENJAWZ_GUARD_KEY" | awk '{print $NF}'; done | sort -u > "$here/forbidden.hmac"
echo "forbidden.hmac: $(wc -l < "$here/forbidden.hmac") digests"
