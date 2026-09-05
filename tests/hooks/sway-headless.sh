#!/usr/bin/env bash
# ci: container
# Headless sway + mako in the install-smoke container, then the desktop bridge against a real SWAYSOCK
# and the notify bridge against a real Notify call. Run as the unprivileged tester inside the container
# after `pacman -S sway mako foot inotify-tools socat jq libnotify dbus`. Exit 0/1/77.
set -uo pipefail
cd "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)" || exit 1
for t in sway swaymsg mako dbus-monitor notify-send jq; do command -v $t >/dev/null || { echo "sway-headless: SKIP — $t missing"; exit 77; }; done
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
[ -d "$XDG_RUNTIME_DIR" ] || { echo "sway-headless: SKIP — no XDG_RUNTIME_DIR"; exit 77; }
if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
  eval "$(dbus-launch --sh-syntax)"; export DBUS_SESSION_BUS_ADDRESS
fi
export WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1 WLR_RENDERER=pixman
sway -c /dev/null >/tmp/sway.log 2>&1 &
spid=$!
for _ in $(seq 1 40); do s=$(ls "$XDG_RUNTIME_DIR"/sway-ipc.* 2>/dev/null | head -1); [ -S "$s" ] && break; sleep 0.25; done
[ -S "${s:-}" ] || { echo "sway-headless: FAIL — sway did not start: $(tail -3 /tmp/sway.log)"; exit 1; }
wd=; for w in "$XDG_RUNTIME_DIR"/wayland-[0-9]*; do [ -S "$w" ] && { wd=$(basename "$w"); break; }; done
export SWAYSOCK=$s WAYLAND_DISPLAY=$wd
mako >/dev/null 2>&1 & mpid=$!
trap 'kill $spid $mpid 2>/dev/null' EXIT
rc=0
# desktop bridge: a workspace switch must produce one "workspace:" line (dry)
OPENJAWZ_HOOK_DRY=1 timeout 6 bash hooks/desktop/desktop-events >/tmp/desk.out 2>&1 &
sleep 1; swaymsg workspace 2 >/dev/null; sleep 1.5
grep -q 'workspace' /tmp/desk.out || { echo "sway-headless: FAIL — desktop bridge saw no workspace event: $(cat /tmp/desk.out)"; rc=1; }
# notify bridge: a Notify call must produce one "notification:" line (dry)
OPENJAWZ_HOOK_DRY=1 timeout 6 bash hooks/notify/notify-events >/tmp/notify.out 2>&1 &
sleep 1; notify-send -a testapp "hello" "world"; sleep 1.5
grep -q 'app=testapp' /tmp/notify.out || { echo "sway-headless: FAIL — notify bridge saw no Notify: $(cat /tmp/notify.out)"; rc=1; }
[ $rc = 0 ] && echo "sway-headless: PASS"
exit $rc
