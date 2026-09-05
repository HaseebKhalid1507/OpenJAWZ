#!/usr/bin/env bash
# ci: fast
# tools: every ops/tools/* and crew/tools/* — --help exits 0, NO_COLOR output has no ESC, header convention present;
# the C verbs in bin/ answer --help too. Runs against a scratch OPENJAWZ_HOME.
set -uo pipefail
cd "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)" || exit 1
v() { [ "${OPENJAWZ_TEST_VERBOSE:-0}" = 1 ] && echo "$@" >&2; return 0; }
fail=0; n=0
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp" XDG_CONFIG_HOME="$tmp/.config" OPENJAWZ_HOME="$tmp/oj" OPENJAWZ_DATA="$tmp/oj/data" OPENJAWZ_STATE="$tmp/state"
export OPENJAWZ_TOOLS="$PWD/ops/tools" OPENJAWZ_NO_TRACK=1 NO_COLOR=1
for t in ops/tools/* crew/tools/* bin/openjawz-onboard bin/openjawz-boot bin/openjawz-shutdown bin/openjawz-checkpoint bin/openjawz-crew bin/openjawz-brain; do
  [ -f "$t" ] && [ -x "$t" ] || continue
  n=$((n+1))
  out="$("$t" --help 2>&1)"; rc=$?
  [ "$rc" = 0 ] || { echo "FAIL $t --help exit $rc"; fail=1; }
  printf '%s' "$out" | grep -q $'\e' && { echo "FAIL $t emits ESC with NO_COLOR=1"; fail=1; }
  head -5 "$t" | grep -qE '^# openjawz-[a-z-]+: ' || { echo "FAIL $t missing '# openjawz-<verb>: ' header"; fail=1; }
  head -5 "$t" | grep -qE '^# owner: openjawz-' || { echo "FAIL $t missing '# owner:' header"; fail=1; }
done
# round trip: onboard → tasks → sessions → checkpoint → shutdown refuses → shutdown passes → boot
OPENJAWZ_TEMPLATES="$PWD/ops/templates" OPENJAWZ_PREAMBLE="$PWD/ops/subagent-preamble.md" bin/openjawz-onboard --yes --render-only >/dev/null 2>&1 || { echo "FAIL onboard"; fail=1; }
ops/tools/tasks add "t1" >/dev/null 2>&1 && ops/tools/tasks list 2>/dev/null | grep t1 >/dev/null || { echo "FAIL tasks add/list"; fail=1; }
ops/tools/sessions add --number 1 --date 2026-01-01 --summary s1 >/dev/null 2>&1 && [ "$(ops/tools/sessions next)" = S2 ] || { echo "FAIL sessions add/next"; fail=1; }
bin/openjawz-checkpoint "mid" >/dev/null 2>&1 && grep -q mid "$OPENJAWZ_HOME/context/active/checkpoint.md" || { echo "FAIL checkpoint"; fail=1; }
bin/openjawz-shutdown --dry-run >/dev/null 2>&1 && { echo "FAIL shutdown did not refuse without a brief"; fail=1; }
printf '# Session Brief\n## Summary\nround trip\n' > "$OPENJAWZ_HOME/context/active/session-brief.md"
printf '# Handoff\nnext\n' > "$OPENJAWZ_HOME/context/active/handoff.md"
mkdir -p "$OPENJAWZ_HOME/notes/journal"; echo "# j" > "$OPENJAWZ_HOME/notes/journal/$(date -I).md"
bin/openjawz-shutdown >/dev/null 2>&1; rc=$?; [ "$rc" = 0 ] || { echo "FAIL shutdown exit $rc after brief+handoff+journal"; fail=1; }
grep -q "completed" "$OPENJAWZ_HOME/context/active/checkpoint.md" || { echo "FAIL shutdown did not clear checkpoint"; fail=1; }
bin/openjawz-boot --quiet --no-world 2>&1 | grep "round trip" >/dev/null || { echo "FAIL boot does not show the session"; fail=1; }
bin/openjawz-crew install >/dev/null 2>&1 && [ "$(ls "$tmp/.synaps-cli/agents" | wc -l)" = 14 ] || { echo "FAIL crew install != 14 roles"; fail=1; }
v "tools: $n executables, round trip ok, fail=$fail"
exit "$fail"
