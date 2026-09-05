#!/usr/bin/env python3
"""
heartbeat — keeps SynapsCLI's Anthropic prompt cache warm during idle gaps.

The Anthropic prompt cache has a 5-minute TTL. Step away mid-session, the cache
expires, and your next message eats a full cache *write* (1.25x the whole prefix
— the expensive part). This extension fires a tiny keepalive turn before the TTL
runs out: the session re-sends its cached prefix (a cheap 0.1x cache *read*) and
the TTL resets. You never pay the re-write.

Mechanism: a long-running process extension. `on_session_start` learns the
session id; `on_message_complete` resets the idle clock; a background thread fires
`synaps send --session <id>` when idle crosses the threshold. The injected
message asks the model to reply with a single token, so output cost is ~nil.

Safety rails:
  - Bounded: stops after `max_beats` (you're clearly gone — let the cache die).
  - Self-aware: doesn't count its own beats as user activity (so the cap works).
  - Paced: one beat per `beat_interval_sec`, never a flood.
  - Real activity (a genuine user message) resets the beat counter.

Config: ~/.synaps-cli/plugins/heartbeat/config  (key = value)
  enabled            = true
  idle_threshold_sec = 240    # idle before the first beat (under the 5m TTL)
  beat_interval_sec  = 240    # spacing between beats
  max_beats          = 12     # then give up (~48 min of keepalive)
  check_interval_sec = 20     # background poll cadence

JSON-RPC 2.0 over stdio, LSP-style Content-Length framing.
"""

import json
import os
import shutil
import subprocess
import sys
import threading
import time


# ── config ──────────────────────────────────────────────────────────────────
def load_config():
    cfg = {
        "enabled": True,
        "idle_threshold_sec": 240,
        "beat_interval_sec": 240,
        "max_beats": 12,
        "check_interval_sec": 20,
    }
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "config")
    try:
        with open(path) as f:
            for line in f:
                line = line.split("#", 1)[0].strip()
                if not line or "=" not in line:
                    continue
                k, v = (x.strip() for x in line.split("=", 1))
                if k == "enabled":
                    cfg[k] = v.lower() in ("true", "1", "yes", "on")
                elif k in cfg:
                    try:
                        cfg[k] = int(v)
                    except ValueError:
                        pass
    except FileNotFoundError:
        pass
    return cfg


CFG = load_config()
SYNAPS_BIN = shutil.which("synaps") or "/usr/bin/synaps"
BEAT_MSG = "[heartbeat] cache keepalive — take no action, reply with only: ack"

# ── shared state (guarded by LOCK) ──────────────────────────────────────────
LOCK = threading.Lock()
STATE = {
    "session_id": None,
    "last_activity": time.monotonic(),
    "last_beat": 0.0,
    "beats": 0,
    "awaiting_self": 0,  # count of our own injected beats not yet seen
    "stop": False,
}


def log(msg):
    sys.stderr.write(f"[heartbeat] {msg}\n")
    sys.stderr.flush()


# ── the beat ────────────────────────────────────────────────────────────────
def fire_beat(session_id):
    # Under a shared daemon a beat must be addressed: broadcasting would wake every
    # session (and every parked one). No captured id → no beat, say so once.
    if not session_id:
        log("beat skipped: no session id captured yet (on_session_start not seen)")
        return
    target = ["--session", session_id]
    try:
        subprocess.run(
            [SYNAPS_BIN, "send", BEAT_MSG, "--source", "heartbeat",
             "--severity", "low", *target],
            capture_output=True, timeout=15,
        )
        log(f"beat → session {session_id[:8]}")
    except Exception as e:  # never let a beat failure kill the loop
        log(f"beat failed: {e}")


def heartbeat_loop():
    while True:
        time.sleep(CFG["check_interval_sec"])
        with LOCK:
            if STATE["stop"]:
                return
            now = time.monotonic()
            idle = now - STATE["last_activity"]
            since_beat = now - STATE["last_beat"]
            # fire_beat skips (and logs) when no session id has been captured
            # if we never caught the id, so a boot race can't make us blind.
            due = (
                idle >= CFG["idle_threshold_sec"]
                and STATE["beats"] < CFG["max_beats"]
                and since_beat >= CFG["beat_interval_sec"]
            )
            if due:
                STATE["last_beat"] = now
                STATE["beats"] += 1
                STATE["awaiting_self"] += 1
                target = STATE["session_id"]  # may be None → beat skipped
                fire = True
            else:
                fire = False
        if fire:
            fire_beat(target)  # outside the lock — subprocess is slow


# ── JSON-RPC stdio ──────────────────────────────────────────────────────────
def read_message():
    header = sys.stdin.buffer.readline().decode("utf-8")
    if not header or not header.startswith("Content-Length:"):
        return None
    length = int(header.split(":")[1].strip())
    sys.stdin.buffer.readline()
    return json.loads(sys.stdin.buffer.read(length))


def write_message(msg):
    body = json.dumps(msg).encode("utf-8")
    sys.stdout.buffer.write(f"Content-Length: {len(body)}\r\n\r\n".encode("utf-8"))
    sys.stdout.buffer.write(body)
    sys.stdout.buffer.flush()


def handle_hook(params):
    kind = params.get("kind")
    # Defensive: capture the session id from ANY hook that carries it
    # (on_session_start, on_compaction, on_session_end all do). Don't rely on
    # catching on_session_start at the exact boot instant.
    sid = params.get("session_id")
    if sid:
        with LOCK:
            if STATE["session_id"] != sid:
                STATE["session_id"] = sid
                log(f"armed → session {sid[:8]}")
    if kind == "on_session_start":
        with LOCK:
            STATE["last_activity"] = time.monotonic()
            STATE["beats"] = 0
    elif kind == "on_message_complete":
        # activity signal — a turn just finished. We use on_message_complete
        # (NOT before_message) on purpose: before_message participates in the
        # injection merge, and a "continue" there clobbers other extensions'
        # injects (e.g. chronos). on_message_complete is notification-only.
        with LOCK:
            if STATE["awaiting_self"] > 0:
                STATE["awaiting_self"] -= 1  # consume one of our own beats
            else:
                STATE["last_activity"] = time.monotonic()
                STATE["beats"] = 0  # genuine activity — re-arm the budget
    elif kind == "on_session_end":
        with LOCK:
            STATE["stop"] = True
    return {"action": "continue"}


def main():
    if not CFG["enabled"]:
        log("disabled via config — idling")
    else:
        threading.Thread(target=heartbeat_loop, daemon=True).start()
        log(f"online · threshold={CFG['idle_threshold_sec']}s · max={CFG['max_beats']}")

    while True:
        try:
            req = read_message()
            if req is None:
                break
            method = req.get("method", "")
            rid = req.get("id", 0)
            if method == "initialize":
                result = {"protocol_version": 1, "capabilities": {}}
            elif method == "hook.handle":
                result = handle_hook(req.get("params", {}))
            elif method == "shutdown":
                with LOCK:
                    STATE["stop"] = True
                write_message({"jsonrpc": "2.0", "result": None, "id": rid})
                log("offline")
                break
            else:
                result = {"action": "continue"}
            write_message({"jsonrpc": "2.0", "result": result, "id": rid})
        except Exception as e:
            log(f"error: {e}")
            break


if __name__ == "__main__":
    main()
