#!/usr/bin/env bash
# ci: fast
# grep-guard: nothing personal, no secrets, no data files, the comparable distro never named.
set -uo pipefail
cd "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)" || exit 1
here=tests/grep-guard; fail=0
v() { [ "${OPENJAWZ_TEST_VERBOSE:-0}" = 1 ] && echo "$@" >&2; return 0; }
mapfile -t tracked < <(git ls-files -co --exclude-standard)
allow="$(sed -E 's/[[:space:]]+#[^#]*$//' "$here/allow.txt" | grep -v '^$')"

# 1. forbidden words (case-insensitive, word-boundaried), minus the allowlist
hits="$(grep -EIin -f "$here/forbidden.txt" -- "${tracked[@]}" 2>/dev/null | grep -viE "$allow")"
[ -n "$hits" ] && { echo "FAIL forbidden:"; echo "$hits"; fail=1; }

# 2. secret patterns (case-sensitive), the lists themselves excluded
hits="$(grep -EIn -f "$here/secrets.txt" -- "${tracked[@]}" 2>/dev/null | grep -v "^$here/")"
[ -n "$hits" ] && { echo "FAIL secret-shaped:"; echo "$hits"; fail=1; }

# 3. data files that must never be tracked
while read -r g; do
  [ -z "$g" ] && continue
  m="$(git ls-files -- "$g" ":(glob)**/$g" 2>/dev/null)"
  [ -n "$m" ] && { echo "FAIL tracked data file ($g):"; echo "$m"; fail=1; }
done < "$here/paths.txt"

# 4. the comparable distro is never named (pattern assembled so this file does not name it either)
distro="$(printf 'REDACTED')"
hits="$(grep -EIil "$distro" -- "${tracked[@]}" 2>/dev/null)"
[ -n "$hits" ] && { echo "FAIL names the comparable distro:"; echo "$hits"; fail=1; }

# 5. the product is OpenJAWZ; the agent name is the user's
hits="$(grep -Pn '(?<![Oo][Pp][Ee][Nn])JAWZ|\bJawz\b' -- "${tracked[@]}" 2>/dev/null | grep -v "^$here/")"
[ -n "$hits" ] && { echo "FAIL bare JAWZ/Jawz:"; echo "$hits"; fail=1; }

# 6. structural: shipped agent/ops/brain/plugin content has no ~/ paths except ~/.synaps-cli/ and $OPENJAWZ_HOME
shipped=(); for p in "${tracked[@]}"; do case "$p" in crew/*|ops/*|brain/*|plugins/*) shipped+=("$p");; esac; done
if [ "${#shipped[@]}" -gt 0 ]; then
  # shellcheck disable=SC2088
  hits="$(grep -En '~/' -- "${shipped[@]}" 2>/dev/null | grep -vE '~/\.synaps-cli/|\$OPENJAWZ_HOME')"
  [ -n "$hits" ] && { echo "FAIL ~/ path in shipped content:"; echo "$hits"; fail=1; }
fi

[ "$fail" = 0 ] && v "grep-guard: clean (${#tracked[@]} files)"
exit "$fail"
