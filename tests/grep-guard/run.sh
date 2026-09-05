#!/usr/bin/env bash
# ci: fast
# grep-guard: nothing personal, no secrets, no data files, the comparable distro never named.
set -uo pipefail
cd "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)" || exit 1
here=tests/grep-guard; fail=0
v() { [ "${OPENJAWZ_TEST_VERBOSE:-0}" = 1 ] && echo "$@" >&2; return 0; }
mapfile -t tracked < <(git ls-files -co --exclude-standard)
allow="$(sed -E 's/[[:space:]]+#[^#]*$//' "$here/allow.txt" | grep -v '^$')"

# 1. forbidden words — the private list is NOT in this repo and the digests are HMAC-SHA256 under a key that is
#    NOT in this repo (CI secret OPENJAWZ_GUARD_KEY; maintainers set it locally). Without the key this step is
#    SKIPPED with a warning — the generic shape patterns (1b) and every other step still run.
if [ -n "${OPENJAWZ_GUARD_KEY:-}" ]; then
  tokens="$(grep -ohEI '[A-Za-z0-9]{3,}' -- "${tracked[@]}" 2>/dev/null | tr 'A-Z' 'a-z' | sort -u)"
  hits="$(while read -r t; do h="$(printf '%s' "$t" | openssl dgst -sha256 -mac HMAC -macopt "hexkey:$OPENJAWZ_GUARD_KEY" | awk '{print $NF}')"; grep -qx "$h" "$here/forbidden.hmac" && echo "$t"; done <<< "$tokens" | grep -v '^$' || true)"
  if [ -n "$hits" ]; then
    shown="$(while read -r t; do [ -n "$t" ] && grep -EIinw "$t" -- "${tracked[@]}" 2>/dev/null | grep -viE "$allow"; done <<< "$hits" | head -20)"
    if [ -n "$shown" ]; then echo "FAIL forbidden token(s) present (private list):"; echo "$shown"; fail=1; fi
  fi
  # commit messages too (the guard used to scan files only)
  msgs="$(git log --format=%B 2>/dev/null | grep -ohE '[A-Za-z0-9]{3,}' | tr 'A-Z' 'a-z' | sort -u)"
  mh="$(while read -r t; do h="$(printf '%s' "$t" | openssl dgst -sha256 -mac HMAC -macopt "hexkey:$OPENJAWZ_GUARD_KEY" | awk '{print $NF}')"; grep -qx "$h" "$here/forbidden.hmac" && echo "$t"; done <<< "$msgs" | grep -v '^$' || true)"
  [ -n "$mh" ] && { echo "FAIL forbidden token(s) in commit messages:"; echo "$mh"; fail=1; }
else
  echo "warn: OPENJAWZ_GUARD_KEY unset — private-word check skipped (shape patterns still enforced)" >&2
fi
# 1b. generic private-shaped patterns (paths, RFC1918, internal hostnames, emails) — reveal nothing themselves
hits="$(grep -EIn -f "$here/patterns.txt" -- "${tracked[@]}" 2>/dev/null | grep -v "^$here/" | grep -viE "$allow")"
[ -n "$hits" ] && { echo "FAIL private-shaped:"; echo "$hits"; fail=1; }

# 2. secret patterns (case-sensitive), the lists themselves excluded
hits="$(grep -EIn -f "$here/secrets.txt" -- "${tracked[@]}" 2>/dev/null | grep -v "^$here/")"
[ -n "$hits" ] && { echo "FAIL secret-shaped:"; echo "$hits"; fail=1; }

# 3. data files that must never be tracked
while read -r g; do
  [ -z "$g" ] && continue
  m="$(git ls-files -- "$g" ":(glob)**/$g" 2>/dev/null)"
  [ -n "$m" ] && { echo "FAIL tracked data file ($g):"; echo "$m"; fail=1; }
done < "$here/paths.txt"

# 4. the comparable distro is never named — its name is in the hashed list (step 1); nothing here spells it.

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
