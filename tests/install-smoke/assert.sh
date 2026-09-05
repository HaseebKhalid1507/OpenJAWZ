#!/usr/bin/env bash
# assert.sh: runs INSIDE the container as tester after boot --local. $1 = profile
set -uo pipefail
P="${1:-desktop}"; fail=0
ok() { echo "  ok   $*"; }
bad() { echo "  FAIL $*"; fail=1; }
XDG_RUNTIME_DIR=/run/user/$(id -u); export XDG_RUNTIME_DIR
systemctl --user is-active synaps-daemon.service >/dev/null && ok "synaps-daemon.service active" || bad "synaps-daemon.service not active"
[ -S ~/.synaps-cli/run/daemon.sock ] && ok "daemon.sock" || bad "no daemon.sock"
[ -f ~/.synaps-cli/run/daemon.json ] && ok "daemon.json" || bad "no daemon.json"
openjawz doctor --json | jq -e '.red|length==0' >/dev/null && ok "doctor: no red" || { bad "doctor has red rows"; openjawz doctor; }
out="$(printf '' | timeout 30 synaps attach --create 2>&1)"
echo "$out" | grep -q '\[attached ' && ok "attach --create → [attached" || bad "attach failed: $(echo "$out" | tail -2)"
sid="$(echo "$out" | sed -n 's/.*\[attached \([^ ]*\).*/\1/p' | head -1)"
if [ -n "$sid" ]; then
  timeout 15 synaps send --session "$sid" --source test --content-type tick --severity low -- "smoke: canary" >/dev/null 2>&1 || true
  [ -f ~/.synaps-cli/run/daemon.json ] && ok "daemon.json survives a send (bug-1 canary)" || bad "daemon.json deleted by send (bug-1)"
  timeout 15 synaps status --memory --json --pid "$(cat ~/.synaps-cli/run/daemon.pid)" >/dev/null 2>&1 || true
  [ -f ~/.synaps-cli/run/daemon.json ] && ok "daemon.json survives status --memory" || bad "daemon.json deleted by status --memory"
fi
synaps daemon sessions --json | jq -e 'length>=1' >/dev/null && ok "daemon sessions ≥ 1" || bad "no sessions"
if [ "$P" = desktop ] && openjawz help ambient >/dev/null 2>&1; then
  openjawz ambient id >/dev/null 2>&1 && ok "ambient id" || bad "no ambient id"
fi
if openjawz help hooks >/dev/null 2>&1 && [ "$P" = desktop ]; then
  n="$(systemctl --user list-units 'openjawz-hook-*' --all --no-legend 2>/dev/null | grep -c 'condition failed' || true)"
  [ "$n" -ge 3 ] && ok "$n Wayland hooks condition-skipped" || echo "  warn hooks condition-failed count = $n"
fi
[ "$(openjawz migrate --pending)" = none ] && ok "migrate --pending → none" || bad "pending migrations"
[ "$(systemctl --user show -p MainPID --value synaps-daemon.service)" = "$(cat ~/.synaps-cli/run/daemon.pid)" ] && ok "daemon pid == MainPID" || bad "daemon pid != MainPID"
echo
openjawz doctor
exit "$fail"
