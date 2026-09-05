# hooks/

Bridges that turn OS events into one `oj::send` each, into the ambient session. Five ship in v0.1: `desktop/` (Hyprland or sway IPC), `fs/` (inotify), `notify/` (in + out), `chronos/` (the clock), `system/` (network + sleep, one system-bus monitor). `ambient-session.md` is the always-on session's prompt.

## The event contract

```
one OS event → one `oj::send` → one <event> the ambient session sees:
  source        ∈ desktop | fs | notify | chronos | system | ui | test
  content-type  ∈ focus | workspace | monitor | screencast | fs | notification | tick | network | sleep | resume
  severity      ∈ low (default) | medium (fs create in a project root, network up/down) | high (sleep imminent)
                  — never critical from a hook
  text          one line, ≤ 512 bytes, human-readable, key=value pairs after a colon:
                  "focus: class=foot title=nvim ~/x"
```

- `oj::send SOURCE CONTENT_TYPE SEVERITY TEXT` (from `lib/openjawz.sh`) is the only way a bridge talks to the runtime. It always targets `--session <ambient id>` from `~/.local/state/openjawz/ambient.id`; never `--broadcast`, never an unqualified `send`. It returns 1 (and logs) when the runtime answered "inbox" — the session was not reachable.
- Bridges coalesce identical `(source, content-type, text)` within 300 ms.
- Bridges never send while `$OPENJAWZ_RUN/hooks.paused` exists — the kill-switch (`openjawz hooks pause 10m`) the ambient prompt itself may set.
- Every bridge exits 0 when its precondition is absent (no compositor, no bus). `ConditionEnvironment=` on the unit is the first line of defence; the script is the second.

Cost ledger (idle RSS, measured on the research box): desktop 4.8 MB (socat) · fs 4.4 MB · notify 2.5 MB · system 2.6 MB · chronos 0 (timer) · + ~4 MB bash per bridge. Budget for the desktop profile: ≤ 25 MB total (`docs/memory-budget.md`).

<!-- hooks: implementation notes below this line -->
