# hooks/

Bridges that turn OS events into one `oj::send` each, into the ambient session. Five ship in v0.1: `desktop/` (Hyprland or sway IPC), `fs/` (inotify), `notify/` (in + out), `chronos/` (the clock), `system/` (network + sleep, one system-bus monitor). `ambient-session.md` is the always-on session's prompt.

## The event contract

```
one OS event → one `oj::send` → one <event> the ambient session sees:
  source        ∈ desktop | fs | notify | chronos | system | ui | test
  content-type  ∈ focus | workspace | monitor | screencast | fs | notification | tick | network | sleep | resume | usb | message
  severity      ∈ low (default) | medium (fs create in a project root, network up/down) | high (sleep imminent)
                  — never critical from a hook
  text          one line, ≤ 512 bytes, human-readable, key=value pairs after a colon:
                  "focus: class=foot title=nvim ~/x"
```

- `oj::send SOURCE CONTENT_TYPE SEVERITY TEXT` (from `lib/openjawz.sh`) is the only way a bridge talks to the runtime — the **one** `synaps send` in the hooks/bridge pipeline (the heartbeat plugin sends its own session-addressed keepalive; it is not a bridge). It targets the session **by name** (`--session ambient`); `~/.local/state/openjawz/ambient.id` is a cache used as the fallback target and by the bar. Never `--broadcast`, never an unqualified `send`. It returns 1 (and logs) when the runtime answered "inbox" / "No session" / "no daemon" — the session was not reachable — so `bridge::emit` can re-ensure and retry.
- **The hook pipeline is a governed ingress.** Every line passes `bridge::secret_shaped` before coalescing: `brain/secret-patterns.txt` + `hooks/redact.list` + built-in OTP shapes (`\b[0-9]{6,8}\b`, "verification code", …) → the whole text becomes `[redacted: secret-shaped] (<ct> from <bridge>)`. `notify` drops apps in `notify.deny` and forwards **titles only** unless `hooks.notify.body = on`; `desktop` sends `title=<class window>` for classes in `title.redact`. Details + kill-switches: `docs/hooks.md`.
- Bridges coalesce identical `(source, content-type, text)` within 300 ms.
- Bridges never send while `$OPENJAWZ_RUN/hooks.paused` exists — the kill-switch (`openjawz hooks pause 10m`) the ambient prompt itself may set. `openjawz ambient send` is a human, not a hook: it bypasses the pause.
- Every bridge exits 0 when its precondition is absent (no compositor, no bus). `ConditionEnvironment=` on the unit is the first line of defence; the script is the second.

Memory per bridge: the table in `docs/hooks.md`.

<!-- hooks: implementation notes below this line -->

## Implementation notes

**Delivery lives in one function.** Every bridge sources `lib/bridge.sh` and calls
`bridge::event <content-type> <severity> key=val …` (or `bridge::emit` with a ready line).
`bridge::emit` redacts, coalesces, rate-limits, honours the pause flag, then calls `oj::send` — it does
**not** run `synaps send` itself; `oj::send` in `lib/openjawz.sh` is the single call site (by name,
`--session ${OPENJAWZ_AMBIENT:-ambient}`; the runtime names sessions at create since `integration@07007af7`;
`openjawz ambient ensure` creates with `--name ambient`). Never `--broadcast`, never an unqualified send.

If the daemon is dead, `bridge::emit` runs `openjawz ambient ensure` **before** sending (so `send` never
auto-spawns an unmanaged daemon — the vm/deck profiles set `SYNAPS_DAEMON_AUTOSPAWN=0`). On an "inbox"
answer (the session is gone — cold start, daemon restart) it re-ensures and retries once; the re-ensure is
rate-limited to one per 60 s whatever its outcome, so a failing ensure cannot stick forever. Coalescing
(identical consecutive line within `OPENJAWZ_HOOK_COALESCE_MS`, 300), a per-bridge rate cap
(`OPENJAWZ_HOOK_RATE`, 60/min), the content filter and the `hooks.paused` flag are all enforced inside
`bridge::emit`, so no bridge can forget them.

**Layout.** `lib/bridge.sh` · `bin/openjawz-{ambient,hooks,notify}` (verbs, found by the router) ·
`<name>/<name>-events` (the bridge; `desktop/` also has `hypr-events` and `sway-events`) ·
`systemd/openjawz-hook-<name>.service` + `openjawz-hooks.target` + `openjawz-chronos.{timer,service}` ·
`fs/watch.list.default` · `redact.list` · `notify/notify.deny` · `desktop/title.redact` · `chronos/plugin/` (the time-injection extension, symlinked into
`~/.synaps-cli/plugins/chronos` by the installer).

**Testing a bridge without a daemon:** `openjawz hooks test <name>` (sets `OPENJAWZ_HOOK_DRY=1`,
prints `source ct sev text` lines). Every bridge also honours `OPENJAWZ_HOOK_REPLAY=<file>` to parse a
recorded stream instead of the live socket — that is how `tests/hooks` runs without a compositor.

Per-hook detail, idle RSS as measured, and how to disable each one: `docs/hooks.md`.
