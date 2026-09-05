#!/usr/bin/env bash
# ci: fast
# lint: shellcheck -S warning on every shell file, bash -n, sh -n on POSIX scripts, py_compile on python.
set -uo pipefail
cd "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)" || exit 1
fail=0; n=0
v() { [ "${OPENJAWZ_TEST_VERBOSE:-0}" = 1 ] && echo "$@" >&2; return 0; }
command -v shellcheck >/dev/null || { echo "lint: shellcheck missing (pacman -S shellcheck)"; exit 77; }

bash_files=(); sh_files=(); py_files=()
while IFS= read -r f; do
  [ -f "$f" ] || continue
  head1="$(head -c 200 "$f" | head -1)"
  case "$f" in
    *.sh|*/PKGBUILD|*.install) bash_files+=("$f"); continue ;;
    *.py) py_files+=("$f"); continue ;;
  esac
  case "$head1" in
    '#!/bin/sh'*|'#!/usr/bin/env sh'*) sh_files+=("$f") ;;
    '#!'*bash*) bash_files+=("$f") ;;
    '#!'*python*) py_files+=("$f") ;;
  esac
done < <(git ls-files)

for f in "${bash_files[@]}"; do
  n=$((n+1))
  case "$f" in
    */PKGBUILD|*.install) shellcheck -S warning -s bash -e SC2034,SC2154,SC2148,SC2164 "$f" || fail=1 ;;
    *) bash -n "$f" || fail=1; shellcheck -S warning -x "$f" || fail=1 ;;
  esac
done
for f in "${sh_files[@]}"; do
  n=$((n+1)); sh -n "$f" || fail=1; shellcheck -S warning -s sh "$f" || fail=1
done
for f in "${py_files[@]}"; do
  n=$((n+1)); python3 -m py_compile "$f" || fail=1
done
v "lint: $n files, fail=$fail"
exit "$fail"
