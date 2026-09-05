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

## Implementation notes

**Delivery lives in one function.** Every bridge sources `lib/bridge.sh` and calls
`bridge::event <content-type> <severity> key=val …` (or `bridge::emit` with a ready line).
`bridge::emit` is the only place in this tree that runs `synaps send`:
`--session ${OPENJAWZ_AMBIENT:-ambient}` by **name** (the runtime names sessions at create since
`integration@07007af7`; `openjawz ambient ensure` creates with `--name ambient`), `--source <bridge>`,
`--content-type`, `--severity`, the text. Never `--broadcast`, never an unqualified send. The id in
`~/.local/state/openjawz/ambient.id` is a cache for the bar and `ambient status`, not the delivery key.

On an "inbox" answer (the session is gone — cold start) the bridge runs `openjawz ambient ensure` once
and retries once; after that it drops and counts. Coalescing (identical consecutive line within
`OPENJAWZ_HOOK_COALESCE_MS`, 300), a per-bridge rate cap (`OPENJAWZ_HOOK_RATE`, 60/min) and the
`hooks.paused` flag are all enforced inside `bridge::emit`, so no bridge can forget them.

**Layout.** `lib/bridge.sh` · `bin/openjawz-{ambient,hooks,notify}` (verbs, found by the router) ·
`<name>/<name>-events` (the bridge; `desktop/` also has `hypr-events` and `sway-events`) ·
`systemd/openjawz-hook-<name>.service` + `openjawz-hooks.target` + `openjawz-chronos.{timer,service}` ·
`fs/watch.list.default` · `chronos/plugin/` (the time-injection extension, symlinked into
`~/.synaps-cli/plugins/chronos` by the installer).

**Testing a bridge without a daemon:** `openjawz hooks test <name>` (sets `OPENJAWZ_HOOK_DRY=1`,
prints `source ct sev text` lines). Every bridge also honours `OPENJAWZ_HOOK_REPLAY=<file>` to parse a
recorded stream instead of the live socket — that is how `tests/hooks` runs without a compositor.

Per-hook detail, idle RSS as measured, and how to disable each one: `docs/hooks.md`.
