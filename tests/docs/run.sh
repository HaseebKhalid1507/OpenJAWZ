#!/usr/bin/env bash
# ci: fast
# docs: doc-drift guard (Reader/Architect asked for it 3 rounds). Grep invariants that are TRUE in this tree today;
#   any future edit that reintroduces a stale claim fails CI. Scope is deliberately what is CLEAN post round-5 doc
#   fixes — it does NOT assert the heartbeat/README-claim lines (owned elsewhere). Fast tier, no container.
set -uo pipefail
cd "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)" || exit 1
fail=0; ok() { echo "  ok   $*"; }; bad() { echo "  FAIL $*"; fail=1; }

# 1. docs/ never tells anyone to install paru — boot writes a repo Include=, it installs no AUR helper (Architect REPEAT ×3)
if grep -rniI 'paru' docs/ >/dev/null 2>&1; then bad "docs/ mentions paru:"; grep -rniI 'paru' docs/; else ok "docs/ never mentions paru"; fi

# 2. docs/ never CLAIMS socket-activation — the daemon is Type=simple, resident. A negation ("Not socket-activated") is fine.
sock="$(grep -rniIE 'socket-activat' docs/ | grep -viE 'not socket-activat' || true)"
[ -z "$sock" ] && ok "docs/ makes no socket-activated claim (negations excepted)" || { bad "docs/ claims socket-activation:"; echo "$sock"; }

# 3. every `--type X` in crew/playbooks uses a valid comms choice (argparse: finding|question|answer|alert).
#    round-4 Reader: a playbook example used `--type completion`, which argparse rejects.
choices="$(sed -nE 's/.*add_argument\("--type", choices=\[([^]]*)\].*/\1/p' crew/tools/comms | tr -d '" ' )"
[ -n "$choices" ] && ok "comms --type choices resolved from argparse: $choices" || bad "could not read comms --type choices"
valid_re="^(${choices//,/|})$"
badtype=0
while IFS= read -r line; do
  file="${line%%:*}"; rest="${line#*:}"
  # pull the token right after --type
  t="$(sed -nE 's/.*--type[= ]+([A-Za-z0-9_-]+).*/\1/p' <<<"$rest")"
  [ -z "$t" ] && continue
  [[ "$t" =~ $valid_re ]] || { badtype=1; echo "    invalid --type '$t' in $file"; }
done < <(grep -rniIE -- '--type[= ]' crew/ playbooks/ 2>/dev/null)
[ "$badtype" = 0 ] && ok "no invalid comms --type in crew/ or playbooks/ (no --type completion)" || bad "an invalid --type value is used in a doc/playbook"

# 4. docs version prose matches VERSION (Reader rc1-drift). Scope: the docs that state the release version in a header.
ver="$(cat VERSION)"
for f in docs/status.md docs/gauntlet/summary.md; do
  [ -f "$f" ] || continue
  head -1 "$f" | grep -qF "$ver" && ok "$f header states $ver" || bad "$f header does not state VERSION ($ver): $(head -1 "$f")"
done
# and no doc states a DIFFERENT full x.y.z-rcN that would contradict VERSION (a stray older rc)
drift="$(grep -rhoIE '0\.1\.0rc[0-9]+' docs/ | sort -u | grep -vxF "$ver" || true)"
[ -z "$drift" ] && ok "no doc states a conflicting 0.1.0rcN version" || { bad "conflicting rc version in docs/:"; echo "$drift"; }

[ "$fail" = 0 ] && echo "docs: ok"
exit "$fail"
