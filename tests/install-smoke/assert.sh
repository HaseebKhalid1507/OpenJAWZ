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
# A1: local mode never touched /etc
[ "$(grep -c openjawz /etc/pacman.conf)" = 0 ] && ok "A1 /etc/pacman.conf untouched" || bad "A1 openjawz in /etc/pacman.conf"
[ ! -e /etc/pacman.d/openjawz.conf ] && ok "A1 no /etc/pacman.d/openjawz.conf" || bad "A1 /etc/pacman.d/openjawz.conf written in local mode"
[ -f ~/.config/openjawz/local-repo ] && ok "A1 local-repo marker" || bad "A1 no local-repo marker"
# A12: migrate-notify enabled with the ambient unit; closing line spelling is covered by grep in driver
if [ "$P" = desktop ]; then systemctl --user is-enabled openjawz-migrate-notify.service >/dev/null 2>&1 && ok "A12 migrate-notify enabled" || bad "A12 migrate-notify not enabled"; fi
# A5: doctor always prints, even with the daemon down or the crew missing
systemctl --user stop synaps-daemon.service
openjawz doctor --brief >/tmp/doc1.log 2>&1; grep -q '^doctor:' /tmp/doc1.log && ok "A5 doctor --brief prints with the daemon down" || { bad "A5 doctor silent with the daemon down:"; tail -3 /tmp/doc1.log; }
mv ~/.synaps-cli/agents ~/.synaps-cli/agents.bak 2>/dev/null; mkdir -p ~/.synaps-cli/agents
openjawz doctor >/tmp/doc2.log 2>&1; grep -qi crew /tmp/doc2.log && ok "A5 doctor mentions crew when agents are missing" || bad "A5 doctor silent on missing crew"
rm -rf ~/.synaps-cli/agents; mv ~/.synaps-cli/agents.bak ~/.synaps-cli/agents 2>/dev/null
openjawz doctor >/tmp/doc3.log 2>&1; grep -q 'unsigned local' /tmp/doc3.log && ok "A5 doctor shows the unsigned-local row" || bad "A5 doctor lacks the unsigned-local row"
systemctl --user start synaps-daemon.service; sleep 2
# A2/A3/A4: update in local mode, under script(1), then ambient is back
[ -d /repo2 ] || { sudo mkdir -p /repo2 && sudo chown "$(id -u)" /repo2; }
if [ -n "$(ls /repo2/*.pkg.tar.zst 2>/dev/null)" ]; then
  openjawz update --yes 2>/tmp/upd-nolocal.err; r=$?
  [ "$r" = 2 ] && grep -q 'update --local' /tmp/upd-nolocal.err && ok "A2 update without --local → rc 2 + hint" || bad "A2 update without --local rc=$r: $(tail -1 /tmp/upd-nolocal.err)"
  script -qec "openjawz update --local /repo2 --yes --no-snapshot; echo rc=\$?" /dev/null > /tmp/upd.log 2>&1
  grep -q 'rc=0' /tmp/upd.log && ok "A2/A3 update --local under script(1) rc 0" || { bad "A2/A3 update --local failed"; tail -5 /tmp/upd.log; }
  [ "$(grep -c openjawz /etc/pacman.conf)" = 0 ] && ok "A2 update wrote nothing to /etc" || bad "A2 update touched /etc/pacman.conf"
  [ "$(stat -c %a ~/.local/state/openjawz/update.log 2>/dev/null)" = 600 ] && ok "A3 update.log mode 600" || bad "A3 update.log mode $(stat -c %a ~/.local/state/openjawz/update.log 2>/dev/null)"
  if [ "$P" = desktop ]; then sleep 3; openjawz ambient status 2>/dev/null | grep -q live && ok "A4 ambient live after update" || bad "A4 ambient not live after update"; fi
else echo "  warn no /repo2 — A2/A3/A4 update leg skipped"; fi
echo
openjawz doctor
exit "$fail"
