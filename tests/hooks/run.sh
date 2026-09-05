#!/usr/bin/env bash
# ci: container
# hooks: the delivery leg — temp daemon → `openjawz ambient ensure` → fs bridge → inotify event →
#        the daemon logs the event from source "fs" and the ambient session is live/unparked.
# Runs against whatever `synaps` is on PATH (SYNAPS_BIN overrides) in a private SYNAPS_BASE_DIR +
# SYNAPS_RUNTIME_DIR under $TMPDIR — never touches the user's daemon. No model call is needed: the
# assertion is "event delivered + session woke", not the model's reply. The toast leg is exercised by
# calling `openjawz notify` directly when a session bus exists (skipped otherwise, printed).
# Exit 0 pass / 1 fail / 77 skip. OPENJAWZ_TEST_VERBOSE=1 for the trace.
set -uo pipefail
cd "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)" || exit 1
v() { [ "${OPENJAWZ_TEST_VERBOSE:-0}" = 1 ] && echo "  $*" >&2; return 0; }
fail() { echo "hooks: FAIL — $*" >&2; cleanup; exit 1; }
skip() { echo "hooks: SKIP — $*" >&2; exit 77; }

SYNAPS=${SYNAPS_BIN:-$(command -v synaps || true)}
[ -x "$SYNAPS" ] || skip "synaps not on PATH (SYNAPS_BIN=…)"
for t in jq inotifywait; do command -v $t >/dev/null || skip "$t missing"; done
"$SYNAPS" attach --help 2>/dev/null | grep -q -- '--name' || skip "runtime lacks 'attach --name' (needs integration@07007af7+)"

T=$(mktemp -d "${TMPDIR:-/tmp}/oj-hooks.XXXXXX")
export SYNAPS_BASE_DIR=$T/base SYNAPS_RUNTIME_DIR=$T/run XDG_STATE_HOME=$T/state XDG_RUNTIME_DIR=$T/rt
export OPENJAWZ_RUN=$T/rt/openjawz OPENJAWZ_WATCH_LIST=$T/watch.list SYNAPS_DAEMON_AUTOSPAWN=0
export SYNAPS_DAEMON_PARK_GRACE_SECS=3 OPENJAWZ_HOOK_COALESCE_MS=0
mkdir -p "$SYNAPS_BASE_DIR" "$SYNAPS_RUNTIME_DIR" "$XDG_STATE_HOME" "$XDG_RUNTIME_DIR" "$T/w/proj"
printf 'progressive_tool_disclosure = true\n' > "$SYNAPS_BASE_DIR/config"
printf '%s:3\n' "$T/w" > "$OPENJAWZ_WATCH_LIST"
LOG=$T/daemon.log
dpid=; bpid=
cleanup() {
  [ -n "$bpid" ] && { kill "$bpid" 2>/dev/null; pkill -P "$bpid" 2>/dev/null; }
  [ -n "$dpid" ] && { "$SYNAPS" daemon stop >/dev/null 2>&1 || kill "$dpid" 2>/dev/null; }
  sleep 0.5; [ "${OPENJAWZ_TEST_KEEP:-0}" = 1 ] || rm -rf "$T"
}
trap cleanup EXIT

# 1. a private daemon
( cd "$T" && exec "$SYNAPS" daemon --foreground ) >"$LOG" 2>&1 &
dpid=$!
for _ in $(seq 1 40); do "$SYNAPS" daemon status >/dev/null 2>&1 && break; sleep 0.25; done
"$SYNAPS" daemon status >/dev/null 2>&1 || fail "daemon did not start: $(tail -3 "$LOG")"
v "daemon up (pid $dpid)"

# 2. the ambient session, by name
bash hooks/bin/openjawz-ambient ensure >/dev/null 2>&1 || fail "openjawz ambient ensure"
id=$(bash hooks/bin/openjawz-ambient id) || fail "ambient id"
"$SYNAPS" daemon sessions --json | jq -e --arg id "$id" '.[]|select(.id==$id and .name=="ambient")' >/dev/null \
  || fail "session $id is not named ambient"
v "ambient $id"
[ -e "$SYNAPS_RUNTIME_DIR/daemon.json" ] || fail "daemon.json missing after attach (registry bug)"

# 3. the fs bridge, live
bash hooks/fs/fs-events >"$T/bridge.log" 2>&1 &
bpid=$!
sleep 1.5
grep -q 'watching' "$T/bridge.log" || fail "fs bridge did not arm: $(cat "$T/bridge.log")"

# 4. one inotify event → one send
echo hello > "$T/w/proj/hello.txt"
slog=$(ls "$SYNAPS_BASE_DIR"/synaps.log* 2>/dev/null | head -1)
ok=0
for _ in $(seq 1 60); do
  if [ -n "$slog" ] && grep -q 'socket: event .* from fs' "$slog" 2>/dev/null; then ok=1; break; fi
  sleep 0.5
done
[ "$ok" = 1 ] || fail "no 'event … from fs' in the daemon log within 30 s; bridge: $(tail -3 "$T/bridge.log")"
v "delivered: $(grep -m1 'from fs' "$slog" | sed 's/.*socket: //')"
[ -e "$SYNAPS_RUNTIME_DIR/daemon.json" ] || fail "daemon.json vanished after send (registry bug 1)"

# 5. the session is live (woke or never parked)
lc=$("$SYNAPS" daemon sessions --json | jq -r --arg id "$id" '.[]|select(.id==$id)|.lifecycle')
case $lc in live|parking) ;; *) fail "ambient lifecycle is '$lc' after the event" ;; esac
v "ambient lifecycle: $lc"

# 6. toast leg — direct, when a bus exists
if [ -S "${DBUS_SESSION_BUS_ADDRESS#unix:path=}" ] 2>/dev/null || [ -S "/run/user/$(id -u)/bus" ]; then
  XDG_RUNTIME_DIR=/run/user/$(id -u) bash hooks/bin/openjawz-notify --no-action "OpenJAWZ" "hooks test" >/dev/null 2>&1 \
    && v "toast sent" || v "toast: notify-send failed (no notification daemon?) — not fatal"
else
  v "toast leg skipped (no session bus)"
fi

echo "hooks: PASS (event delivered, ambient $lc)"
exit 0
