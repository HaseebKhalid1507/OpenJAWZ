#!/usr/bin/env bash
# ci: fast
# heartbeat: the heartbeat plugin must NEVER broadcast — under a shared daemon a broadcast beat wakes every session
#   (and every parked one). round-2 shipped `--broadcast`; round-3 removed it and made the beat address `--session`
#   (Architect round-4: "--broadcast is gone ✓"). This test asserts (1) the string --broadcast appears nowhere in
#   the plugin, and (2) behaviourally exercises fire_beat: an empty session id fires NO send at all, and a real id
#   fires exactly one `synaps send --session <id>` with no --broadcast anywhere in the argv.
set -uo pipefail
cd "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)" || exit 1
fail=0; ok() { echo "  ok   $*"; }; bad() { echo "  FAIL $*"; fail=1; }
hb=plugins/heartbeat/main.py
[ -f "$hb" ] || { echo "FAIL $hb missing"; exit 1; }

# 1. static: not a single --broadcast token in the plugin tree
if grep -rn -- '--broadcast' plugins/heartbeat/ >/dev/null 2>&1; then
  bad "--broadcast present:"; grep -rn -- '--broadcast' plugins/heartbeat/
else ok "no --broadcast anywhere in plugins/heartbeat/"; fi

command -v python3 >/dev/null || { echo "heartbeat: python3 missing"; exit 77; }

# 2. behavioural: import fire_beat, stub subprocess.run, assert the addressed-only contract
py="$(python3 - "$PWD/$hb" <<'PY'
import importlib.util, sys, types
path = sys.argv[1]
spec = importlib.util.spec_from_file_location("heartbeat_main", path)
m = importlib.util.module_from_spec(spec)
calls = []
# stub subprocess.run so no real synaps is invoked; capture every argv
import subprocess
def fake_run(argv, *a, **k):
    calls.append(list(argv))
    class R: returncode = 0; stdout = b""; stderr = b""
    return R()
subprocess.run = fake_run
spec.loader.exec_module(m)
m.subprocess.run = fake_run  # in case the module rebound the name

# (a) no session id -> no send call at all
calls.clear()
m.fire_beat("")
assert calls == [], f"empty id fired a send: {calls}"
m.fire_beat(None)
assert calls == [], f"None id fired a send: {calls}"
print("EMPTY_OK")

# (b) real id -> exactly one send, --session addressed, never --broadcast
calls.clear()
m.fire_beat("abcd1234-session")
assert len(calls) == 1, f"expected 1 send, got {len(calls)}: {calls}"
argv = calls[0]
assert "send" in argv, f"not a send: {argv}"
assert "--broadcast" not in argv, f"broadcast in argv: {argv}"
assert "--session" in argv and argv[argv.index('--session')+1] == "abcd1234-session", f"not session-addressed: {argv}"
print("ADDRESSED_OK")
PY
)" || { echo "$py"; bad "behavioural check raised"; }
grep -q EMPTY_OK <<<"$py" && ok "empty/None session id fires NO send (no captured id -> no beat)" || bad "empty id fired a beat"
grep -q ADDRESSED_OK <<<"$py" && ok "real id fires exactly one --session-addressed send, no --broadcast" || bad "beat not addressed-only"

[ "$fail" = 0 ] && echo "heartbeat: ok"
exit "$fail"
