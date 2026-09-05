# Hooks — the OS talking to the agent

A hook is a small `systemd --user` unit that turns one class of OS events into one-line
events for the **ambient session** — the always-on session that is parked (~2 MB) until
something wakes it. Nothing polls. Nothing runs a model unless an event arrives.

```
OS event ──bridge──▶ synaps send --session ambient ──▶ <event …>fs: op=create path=~/Projects/x/a.md</event>
                                                           │
                                                   ambient session wakes (≈ 50 ms), one turn, parks again
```

Every bridge sources `hooks/lib/bridge.sh` and delivers through **one** function
(`bridge::emit`): that is where the content filter, coalescing (300 ms), the per-bridge rate cap
(60/min) and the pause flag live; the actual `synaps send` is `oj::send` in `lib/openjawz.sh` — the
only one in the tree. The contract (source, content-type, severity, text) is in `hooks/README.md`.

## The hook pipeline is a governed ingress

Hooks are the highest-volume path into the model — every notification body, every window title —
so the memory policy (`brain/memory-policy.md`) governs them **before** the runtime sees a line.
`desktop` and `notify` are **on by default** in the desktop and laptop profiles; this is what keeps
that acceptable:

| layer | where | default | what it does | override |
|---|---|---|---|---|
| secret filter | `bridge::emit` (every bridge, every line) | on | text matching `brain/secret-patterns.txt` (= the grep-guard list), `hooks/redact.list`, or the built-in OTP shapes (`\b[0-9]{6,8}\b`, `123 456`, "verification/security/one-time code", "OTP", "passcode") is replaced whole by `[redacted: secret-shaped] (<ct> from <bridge>)` and counted in the journal | `OPENJAWZ_HOOK_REDACT_LIST=<file>` adds patterns; `OPENJAWZ_HOOK_REDACT=0` turns it off (don't) |
| app deny list | `notify` | `hooks/notify/notify.deny` (KDE Connect, Signal, 1Password, Bitwarden, KeePassXC, GNOME Keyring, Authy, Ente, Aegis, Proton Pass) | the whole notification is dropped, never emitted | `hooks.notify.deny = <file>` in `~/.synaps-cli/config`, or `OPENJAWZ_NOTIFY_DENY=<file>` |
| body forwarding | `notify` | **off** — `notification: app= summary=` only | the body is forwarded (160 chars) only when opted in | `hooks.notify.body = on` in `~/.synaps-cli/config`, or `OPENJAWZ_NOTIFY_BODY=1` |
| title redaction | `desktop` | `hooks/desktop/title.redact` (Firefox, Chromium, Chrome, Brave, LibreWolf, Zen, Vivaldi, Edge, Signal) | for those classes the bridge sends `title=<class window>` — a bank tab is "firefox window" | `OPENJAWZ_TITLE_REDACT=<file>` |
| length cap | `bridge::emit` | 512 bytes | truncation, after the filter | `OPENJAWZ_HOOK_MAX_BYTES` |
| kill-switches | `openjawz hooks pause 10m` · `openjawz hooks disable notify desktop` · `OPENJAWZ_HOOKS=chronos,system` in `profile.env` | | | |

List files: one entry per line, `#` comments, case-insensitive, globs allowed (`org.kde.kdeconnect*`).
Package-installed copies live in `/usr/share/openjawz/hooks/`; point the overrides at your own copy
rather than editing those. The filter is deliberately coarse: a line with a six-digit number in it
is worth less than the OTP it might be.

## Commands

| command | does |
|---|---|
| `openjawz hooks enable [name…]` | enable + start the units (default set from `$OPENJAWZ_HOOKS` in `~/.config/openjawz/profile.env`) |
| `openjawz hooks disable [name…]` | stop + disable; no names = everything incl. the target |
| `openjawz hooks status` | one line per hook: active / not installed / condition failed / disabled / failed, plus the pause state |
| `openjawz hooks test <name>` | run the bridge in the foreground, print instead of send |
| `openjawz hooks pause 10m` / `resume` | the kill-switch: bridges keep running, events are dropped (`$XDG_RUNTIME_DIR/openjawz/hooks.paused`) |
| `openjawz ambient ensure\|id\|status` | the session the hooks talk to; `ensure` is idempotent — the unit, `update` and the bridges all call it |
| `openjawz ambient send "text"` | a human line into the ambient session (source `ui`); bypasses `hooks pause` |
| `openjawz waybar-status` | the bar module's JSON line, for a manual look (`ui/bar/waybar-status`) |
| `openjawz notify "summary" "body"` | the other direction: a toast with an **Attach** button → `openjawz summon` |
| `systemctl --user stop openjawz-hooks.target` | the systemd way to silence all of them at once |

Kill one for good: `openjawz hooks disable fs`. Kill all: `openjawz hooks disable`.

## The hooks

Idle RSS measured on the build box (x86_64, bash 5.3, gawk), each bridge running for real against a
private daemon, summed over the bridge's process tree. **RSS** double-counts shared pages (every
`bash` maps the same libc); **PSS** is what the bridge actually adds to the machine. The budget in
`docs/memory-budget.md` is stated in PSS.

| hook | what it watches | what it sends (`content-type: text`) | processes | idle RSS | idle PSS |
|---|---|---|---|---:|---:|
| `desktop` | Hyprland `.socket2.sock` via `socat`; sway via `swaymsg -t subscribe -m` | `focus: class= title=` · `workspace: id= name=` · `monitor: added=/removed=/focused=` · `screencast: active= owner=` | bash + socat | 10.6 MB | **1.8 MB** |
| `fs` | `inotifywait` on the roots in `~/.config/openjawz/watch.list` (default `~/Projects:3`, `~/Downloads:1`), excludes `.git node_modules target .cache __pycache__ venv dist build` | `fs: op=create\|close_write\|moved_to\|delete path=~/…` (create/moved_to = medium) | bash + inotifywait | 11.8 MB (2 586 dirs) | **3.2 MB** |
| `notify` | `dbus-monitor --session` on `org.freedesktop.Notifications.Notify` — any notification daemon | `notification: app= summary=` (+ `body=` only with `hooks.notify.body = on`; `notify.deny` apps dropped; our own toasts skipped) | bash ×2 + dbus-monitor + awk | 18.7 MB | **2.4 MB** |
| `system` | one `dbus-monitor --system`: NetworkManager `StateChanged` + login1 `PrepareForSleep`; `OPENJAWZ_HOOK_USB=1` adds `udevadm monitor` | `network: state=online connection=…` · `network: state=disconnected` · `sleep: state=suspending` (high) · `resume: state=resumed` · `usb: action= model= serial=` | bash ×2 + dbus-monitor + awk | 18.7 MB | **2.2 MB** |
| `chronos` | `openjawz-chronos.timer`, hourly; plus the time-injection plugin (every message knows the time) | `tick: time=HH:00 date= dow= tz=` | none between ticks | 0 | **0** |
| **total** | | | | 60 MB | **≈ 9.6 MB** |

`nmcli monitor` (13 MB, five threads) is not used anywhere. Nothing watches `$HOME`.

### `desktop`
Needs `WAYLAND_DISPLAY` in the user manager (`ConditionEnvironment=`), starts with
`graphical-session.target`. On Hyprland the instance signature is taken from the environment or, if
the unit started before the compositor exported it, from the newest directory in
`$XDG_RUNTIME_DIR/hypr`. Titles may contain commas; the split is on the first one only.
`screencast: active=1` is the ambient session's cue to stay quiet. Window classes in `title.redact`
(browsers) never have their title forwarded.

### `fs`
`watch.list`: one root per line, `:depth` optional (default 3). The bridge expands roots to an
explicit directory list, so the kernel cost is bounded (~1 KB per directory) and a huge tree cannot
take seconds to arm. If `fs.inotify.max_user_watches` is smaller than the list, the bridge exits 78
and the unit does **not** restart (`RestartPreventExitStatus=78`); the journal carries the line:

    sudo sysctl -w fs.inotify.max_user_watches=<max(524288, 2×current)>   # persist in /etc/sysctl.d/40-openjawz.conf

together with how many watches the bridge wants and how many inotify instances the box already has
open, so "trim watch.list" is a decision, not a guess.

Editor noise (`*.swp`, `*~`, `4913`, `.#*`, `*.part`, `*.crdownload`) is dropped in the bridge.

### `notify` (in) and `openjawz notify` (out)
In: works with mako, dunst, swaync, anything on the bus — the bridge watches the bus, not the daemon.
Apps in `notify.deny` are dropped whole; bodies are forwarded only with `hooks.notify.body = on`.
Out: `notify-send -a OpenJAWZ -A attach=Attach`; the wait for the action runs detached so the caller
returns immediately. `-r ID -p` pass through for progress toasts. Exit 2 (skip) without libnotify, a running notification daemon (an activatable stub would hang notify-send),
or a session bus.

### `system`
No Wayland needed — `WantedBy=default.target`, so a laptop lid-close on a TTY still parks the
sessions through `sleep: state=suspending`. After `resume` the active wifi/ethernet connection is
read once with `nmcli -t … --active` (a one-shot, not a monitor).

### `chronos`
A timer, not a process. `Persistent=false`: a missed hour is not replayed on wake.

## The ambient session

`openjawz ambient ensure` (run by `openjawz-ambient.service` after the daemon, and by the installer):

1. daemon reachable, else `systemctl --user start synaps-daemon.service` (≤ 10 s);
2. a session named `ambient` live or parked → cache its id, done;
3. a saved journal named `ambient` → `synaps attach --continue ambient --name ambient`;
4. else `synaps attach --create --name ambient -s /usr/share/openjawz/hooks/ambient-session.md`
   plus one boot line, so a journal exists and the session **can park**.

Bridges resolve the session by **name** (`--session ambient`); the runtime names sessions at
create. `~/.local/state/openjawz/ambient.id` is a cache for the bar and the fallback target. On an
"inbox" answer (cold start, session gone) a bridge re-runs `ensure` and retries once (at most one
`ensure` per 60 s per bridge). If the daemon is dead the bridge runs `ensure` *before* sending, so
`synaps send` never auto-spawns an unmanaged daemon (the vm and deck profiles also set
`SYNAPS_DAEMON_AUTOSPAWN=0`).

**After a crash.** `openjawz-ambient.service` is `BindsTo=`/`PartOf=synaps-daemon.service` and the
daemon unit `Upholds=openjawz-ambient.service`: a `kill -9` on the daemon → systemd restarts it (1 s)
→ the ambient unit is stopped with it and started again → `ensure` re-creates the session, with no
bridge event needed. `TimeoutStartSec=130` covers ensure's worst case (10 s daemon + 40 s `--continue`
+ 60 s `--create`). `openjawz update` ends with the same `openjawz ambient ensure`.

## The bar

`ui/bar/waybar-status` prints one JSON line; `class` is one of:

| class | meaning | how it is decided |
|---|---|---|
| `off` | daemon not running | unit inactive, or `synaps daemon status` ≠ 0 — a stale socket file after a crash is `off`, never `idle` |
| `empty` | daemon up, zero sessions | `live + parked == 0` |
| `parked` | only parked sessions | |
| `idle` | a live session, nobody typing, no turn in flight | |
| `attached` | a terminal owns a live session's input | a human is there — this is not "work" |
| `busy` | a turn is in flight | only when the runtime exposes `turn_active` (Synaps PR); never inferred from an attach |

`pending` is added when migrations wait. `openjawz waybar-status` runs it by hand.

The prompt (`hooks/ambient-session.md`) is operations only: read the event, decide, mostly stay
silent, toast only when it matters, never start long work, pause a noisy source itself.

## Cost — read this

**Every event that wakes the ambient session is a model turn.** An `fs` storm (a `git checkout`
across a big tree, a build writing thousands of files) is many events. Three governors:

- the bridge: coalescing + `OPENJAWZ_HOOK_RATE` (60/min per bridge; tune in `profile.env`);
- the runtime: `events.auto_turn_cap` (default 5) — after N auto-turns in a burst the session waits
  for a human message; set it deliberately in `~/.synaps-cli/config`;
- you: `openjawz hooks disable fs` or `openjawz hooks pause 1h`. The ambient prompt may do the
  same on its own.

If the bill matters more than the reflexes, run with `OPENJAWZ_HOOKS=chronos,system` (the vm profile
default is `chronos` only).

## Troubleshooting

- `openjawz hooks status` says *not installed*: the units are not in the user manager
  (`systemctl --user daemon-reload` after installing `openjawz-hooks`). It says *condition failed* for
  `desktop`/`notify` only after a start was attempted: the user manager has no `WAYLAND_DISPLAY`. Hand-rolled Hyprland: add the `exec-once = systemctl --user import-environment …
  && systemctl --user start hyprland-session.target` line (printed by `hooks enable`, also in
  `ui/hotkey/hyprland.conf`), or run the compositor under `uwsm`.
- Events go to `~/.synaps-cli/inbox/`: the ambient session is gone — `openjawz ambient ensure`.
- `journalctl --user -u 'openjawz-hook-*'` shows each bridge's log; `~/.local/state/openjawz/openjawz.log`
  has the same lines with timestamps.
- `openjawz hooks test desktop` prints what the bridge would send, without sending.
