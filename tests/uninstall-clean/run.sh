#!/usr/bin/env bash
# ci: container
# uninstall-clean: in the smoke container, `openjawz uninstall --yes --keep-brain` leaves no package, unit, repo line or plugin symlink; brain kept.
set -uo pipefail
cd "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)" || exit 1
name="${OPENJAWZ_SMOKE_NAME:-oj-smoke}"
command -v docker >/dev/null || { echo "uninstall-clean: docker missing"; exit 77; }
if ! docker inspect "$name" >/dev/null 2>&1; then
  KEEP=1 tests/install-smoke/run.sh desktop || { echo "uninstall-clean: smoke failed first"; exit 1; }
fi
u() { docker exec "$name" runuser -u tester -- env HOME=/home/tester XDG_RUNTIME_DIR=/run/user/1000 "$@"; }
fail=0; ok() { echo "  ok   $*"; }; bad() { echo "  FAIL $*"; fail=1; }
u bash -c 'mkdir -p ~/.config/axel && touch ~/.config/axel/axel.r8 ~/.local/share/openjawz/keep-me'
u openjawz uninstall --yes --keep-brain || bad "uninstall exited non-zero"
[ -z "$(docker exec "$name" pacman -Qq | grep '^openjawz' || true)" ] && ok "no openjawz packages" || bad "packages left: $(docker exec "$name" pacman -Qq | grep openjawz | tr '\n' ' ')"
docker exec "$name" pacman -Q synaps-bin >/dev/null 2>&1 && ok "synaps-bin kept (no --all)" || bad "synaps-bin removed without --all"
[ -z "$(u systemctl --user list-unit-files 'openjawz-*' 'synaps-*' --no-legend 2>/dev/null)" ] && ok "no units" || bad "units left"
docker exec "$name" test ! -e /etc/pacman.d/openjawz.conf && ok "openjawz.conf gone" || bad "openjawz.conf left"
docker exec "$name" grep -q 'openjawz.conf' /etc/pacman.conf && bad "Include left in pacman.conf" || ok "Include removed"
[ -z "$(u bash -c 'ls ~/.synaps-cli/plugins/ 2>/dev/null')" ] && ok "plugin symlinks gone" || bad "plugin symlinks left"
u test -f /home/tester/.config/axel/axel.r8 && ok "brain (~/.config/axel) kept" || bad "brain removed"
u test -f /home/tester/.local/share/openjawz/keep-me && ok "state kept with --keep-brain" || bad "state removed"
# --purge variant
u openjawz uninstall --yes --purge >/dev/null 2>&1 || true
u test ! -e /home/tester/.local/share/openjawz && ok "--purge removed state" || bad "--purge left state"
[ "${KEEP:-0}" = 1 ] || docker rm -f "$name" >/dev/null 2>&1
echo "uninstall-clean: fail=$fail"; exit "$fail"
