#!/usr/bin/env bash
# Regenerate forbidden.sha256 from a PRIVATE word list that lives OUTSIDE the repo.
# Usage: OPENJAWZ_PRIVATE_WORDS=~/.config/openjawz/forbidden-words.txt tests/grep-guard/make-hashes.sh
# The private file: one word or phrase per line (case-insensitive; phrases are split into words >= 3 chars).
set -euo pipefail
src="${OPENJAWZ_PRIVATE_WORDS:?set OPENJAWZ_PRIVATE_WORDS to the private word list (never committed)}"
here="$(cd "$(dirname "$0")" && pwd)"
grep -v '^\s*#' "$src" | grep -oE '[A-Za-z0-9]{3,}' | tr 'A-Z' 'a-z' | sort -u \
  | while read -r w; do printf '%s' "$w" | sha256sum | cut -c1-64; done | sort -u > "$here/forbidden.sha256"
echo "forbidden.sha256: $(wc -l < "$here/forbidden.sha256") hashed tokens (source stays private)"
