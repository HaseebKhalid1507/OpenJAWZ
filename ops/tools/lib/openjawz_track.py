"""
openjawz_track — import at the top of any Python tool:

    import openjawz_track
    openjawz_track.init()

On exit it logs tool name, duration, exit code and caller to `toolstats` — fire-and-forget,
backgrounded, never blocks, never raises. Local SQLite only; no network. No surveillance state,
just basic metrics. Opt out with OPENJAWZ_NO_TRACK=1.
"""
import atexit
import os
import shutil
import subprocess
import sys
import time

_start_time = None
_tool_name = None


def _toolstats_bin():
    d = os.environ.get("OPENJAWZ_TOOLS", "/usr/lib/openjawz/tools")
    for cand in (os.path.join(d, "openjawz-toolstats"), os.path.join(d, "toolstats"),
                 os.path.join(os.path.dirname(os.path.dirname(os.path.realpath(__file__))), "toolstats")):
        if os.access(cand, os.X_OK):
            return cand
    return shutil.which("openjawz-toolstats")


def init(name=None):
    """Initialize tracking. Call once at script start."""
    global _start_time, _tool_name
    if os.environ.get("OPENJAWZ_NO_TRACK") == "1":
        return
    _start_time = time.time()
    _tool_name = name or os.path.basename(sys.argv[0]).removeprefix("openjawz-")
    if _tool_name == "toolstats":
        return
    atexit.register(_on_exit)


def _on_exit():
    try:
        duration_ms = int((time.time() - _start_time) * 1000) if _start_time else 0
        caller = os.environ.get("OPENJAWZ_AGENT", "user")
        exit_code = 1 if hasattr(sys, "last_value") else 0
        toolstats = _toolstats_bin()
        if not toolstats:
            return
        subprocess.Popen(
            [toolstats, "log", _tool_name, "--duration", str(duration_ms),
             "--exit-code", str(exit_code), "--caller", caller],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    except Exception:
        pass
