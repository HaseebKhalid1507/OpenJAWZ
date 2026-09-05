#!/usr/bin/env bash
# ci: fast
# templates: every {{PLACEHOLDER}} in ops/templates, ops/subagent-preamble.md, ops/sacred-files.md, brain/*.default,
# crew/roles is a key of identity.env.template (+ XDG_CONFIG_HOME); `openjawz onboard --yes --render-only` leaves no `{{`.
set -uo pipefail
cd "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)" || exit 1
v() { [ "${OPENJAWZ_TEST_VERBOSE:-0}" = 1 ] && echo "$@" >&2; return 0; }
fail=0
keys="$(grep -oE '^[A-Z_]+=' ops/templates/identity.env.template | tr -d '=' | sort -u | tr '\n' ' ') XDG_CONFIG_HOME"
files=(ops/templates/* ops/subagent-preamble.md ops/sacred-files.md brain/sources.toml.default brain/axel.default crew/roles/*.md)
for f in "${files[@]}"; do
  for k in $(grep -oE '\{\{[A-Z_][A-Z0-9_]*\}\}' "$f" | tr -d '{}' | sort -u); do
    # shellcheck disable=SC2076
    [[ " $keys " =~ " $k " ]] || { echo "FAIL $f uses {{$k}} which is not an identity.env key"; fail=1; }
  done
done

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
if HOME="$tmp" XDG_CONFIG_HOME="$tmp/.config" OPENJAWZ_HOME="$tmp/oj" OPENJAWZ_STATE="$tmp/state" \
   OPENJAWZ_TEMPLATES="$PWD/ops/templates" OPENJAWZ_PREAMBLE="$PWD/ops/subagent-preamble.md" \
   bin/openjawz-onboard --yes --render-only >/dev/null 2>&1; then
  left="$(grep -rn '{{' "$tmp/oj" "$tmp/.synaps-cli" "$tmp/.config" 2>/dev/null)"
  [ -n "$left" ] && { echo "FAIL unrendered placeholders:"; echo "$left"; fail=1; }
  [ "$(stat -c %a "$tmp/.config/openjawz/identity.env")" = 600 ] || { echo "FAIL identity.env is not 0600"; fail=1; }
  for f in oj/SOUL.md oj/OP.md oj/AGENTS.md .synaps-cli/system.md .synaps-cli/subagent-preamble.md .synaps-cli/config; do
    [ -s "$tmp/$f" ] || { echo "FAIL missing $f"; fail=1; }
  done
  grep -q '^identity = ' "$tmp/.synaps-cli/config" || { echo "FAIL config has no identity= line"; fail=1; }
  [ "$(wc -l < "$tmp/.synaps-cli/subagent-preamble.md")" -le 8 ] || { echo "FAIL preamble longer than 8 lines"; fail=1; }
else
  echo "FAIL openjawz onboard --yes --render-only exited non-zero"; fail=1
fi
[ "$fail" = 0 ] && v "templates: clean"
exit "$fail"
