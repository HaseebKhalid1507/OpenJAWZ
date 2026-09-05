#!/usr/bin/env python3
"""
chronos extension — injects the current time into context before every user
message, so the model always knows *when* it is.

Subscribes to `before_message` and returns an `inject` action carrying a clean,
parseable timestamp plus a natural period-of-day tag. The model sees the time
before it responds — no more "I don't have access to the current date."

Speaks JSON-RPC 2.0 over stdio with LSP-style Content-Length framing.
"""

import json
import sys
from datetime import datetime


def read_message():
    """Read a Content-Length framed JSON-RPC message from stdin."""
    header = sys.stdin.buffer.readline().decode("utf-8")
    if not header or not header.startswith("Content-Length:"):
        return None
    length = int(header.split(":")[1].strip())
    sys.stdin.buffer.readline()  # blank \r\n separator
    body = sys.stdin.buffer.read(length)
    return json.loads(body)


def write_message(msg):
    """Write a Content-Length framed JSON-RPC message to stdout."""
    body = json.dumps(msg).encode("utf-8")
    sys.stdout.buffer.write(f"Content-Length: {len(body)}\r\n\r\n".encode("utf-8"))
    sys.stdout.buffer.write(body)
    sys.stdout.buffer.flush()


def period_of_day(hour: int) -> str:
    """Natural-language tag for the hour, so the model has casual temporal sense."""
    if hour < 5:
        return "late night"
    if hour < 12:
        return "morning"
    if hour < 17:
        return "afternoon"
    if hour < 21:
        return "evening"
    return "night"


def time_line() -> str:
    """Build the injection string from the local, timezone-aware clock."""
    now = datetime.now().astimezone()
    stamp = now.strftime("%Y-%m-%d %H:%M")          # 2026-06-15 23:47
    tz = now.strftime("%Z") or now.strftime("%z")    # EDT (or +0000 fallback)
    weekday = now.strftime("%A")                     # Monday
    tod = period_of_day(now.hour)                    # night
    return f"[\U0001f550 Current time: {stamp} {tz} \u2014 {weekday} {tod}]"


def handle_hook(params):
    """Handle a hook.handle call."""
    if params.get("kind") == "before_message":
        return {"action": "inject", "content": time_line()}
    return {"action": "continue"}


def main():
    sys.stderr.write("[chronos] clock online\n")
    sys.stderr.flush()

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
                write_message({"jsonrpc": "2.0", "result": None, "id": rid})
                sys.stderr.write("[chronos] clock off\n")
                sys.stderr.flush()
                break
            else:
                result = {"action": "continue"}

            write_message({"jsonrpc": "2.0", "result": result, "id": rid})

        except Exception as e:
            sys.stderr.write(f"[chronos] error: {e}\n")
            sys.stderr.flush()
            break


if __name__ == "__main__":
    main()
