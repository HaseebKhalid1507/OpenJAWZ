# Architecture

Seven layers, bottom up. Each maps to one directory.

1. **Base** — an Arch-based Linux. Not ours. We install a package onto it.
2. **Runtime** — [Synaps](https://github.com/HaseebKhalid1507/SynapsCLI): the engine, the daemon, the session model (attach / detach / park / reload), the extension host, the thin client. Pinned as `synaps-bin`.
3. **Daemon as a service** — `daemon/`: a `Type=simple` user unit (`synaps-daemon.service`), resident from login. Not socket-activated — the runtime binds its own socket and does not read `LISTEN_FDS` (`daemon/README.md`); the runtime auto-spawns it on first attach if it is down. `--idle-exit N` exists in the runtime today and the vm profile uses it (1800 s); desktop/laptop set 0 because an idle-exit drops the ambient session's registration. One per user.
4. **Sidecars** — memory (`axel`), scheduling (`chronos`), web tools, bridges: extensions of *the* daemon, started once, shared by every session. Memory is `shared: true` — one brain file (two axel processes: MCP server + extension; `docs/brain.md`).
5. **Hooks** — `hooks/`: everything is `synaps send` into an **ambient session** that is parked by default and wakes on events. Five bridges ship (`docs/hooks.md`): desktop IPC (focus, workspace, monitors, screencast), filesystem (inotify on `watch.list` roots), notifications (in), the clock (hourly `openjawz-chronos.timer`), system (NetworkManager state, sleep/resume; USB opt-in). No idle detection, no peers.
6. **UI** — `ui/`: a global hotkey that opens a terminal running the TUI attached to the daemon (`synaps --attach --new`); a bar widget that reads `synaps daemon sessions --json` and `synaps status --memory`; `openjawz notify` for toasts out (the agent→notifier tap is a runtime PR, below).
7. **Crew, ops, brain, identity** — `crew/ ops/ brain/`: the agents, the discipline (boot briefing, checkpoint, handoff, shutdown, sacred files), the memory policy, and the SOUL / OP / AGENTS **templates** the installer fills. The identity is the user's, never ours.

## Install and update

```
sh boot                  ~6.5 KB, sha256-verified download (not curl|bash): verify Arch,
                         add the [openjawz] repo Include to /etc/pacman.conf, pacman -S openjawz-meta
                         (a trap removes the repo line if anything below fails)
  → openjawz-meta        PKGBUILD: synaps-bin + daemon + sidecars + hooks + crew + ops + brain + ui
  → openjawz install     staged, logged, idempotent: config → unit → plugins → crew → brain →
                         onboard → hooks → ambient → ui → migrate → doctor
  → openjawz update      lock → brain backup → snapshot → pacman -Syu openjawz-meta →
                         migrate → daemon reload → ambient → doctor
```

The script is what a stranger types. The package is the truth. `migrations/` exists from the first commit so it never has to be retrofitted.

## What stays out

- The runtime. No Rust in this repo.
- Any specific person's identity. Templates only.
- The bootloader, the display manager, the kernel. We install *onto* a desktop.

## What the runtime still owes us

v0.1 ships against the Synaps prerelease with three fixes landing (`daemon.json` survives `send`/`status --memory`;
sessions named at create; `--continue` attaches to the live actor). The rest are PRs to file, and each one removes a
workaround in this tree:

| PR (title as filed) | what it removes here |
|---|---|
| `feat(daemon): systemd socket activation — adopt LISTEN_FDS fd 3, sd_notify(READY=1), keep flock + daemon.json` | `Type=simple` resident daemon → `.socket` unit (then `--idle-exit`, which already exists, becomes safe on desktop/laptop too) |
| `feat(daemon): --tcp ADDR --token-file F (check_bind_policy, ct_eq)` | the deck's SSH-forwarded socket |
| `feat(daemon): remote-ready liveness — SYNAPS_DAEMON_REMOTE=1 trusts a connectable socket, skips reap_stale/autospawn` | the deck's socket hold |
| `feat(daemon): notification tap — Subscribe{notifications} control frame` | the bar/notifier attaching to sessions |
| `feat(daemon): daemon sessions --json gains keep_warm, streaming, last_activity` | the bar's `busy` probe |
| `feat(cli): synaps hook <event> --data JSON --expects-response` | text-only `synaps send` from bridges |
| `feat(extensions): system plugin root /usr/share/synaps/plugins + SYNAPS_PLUGIN_PATH` | `openjawz install` symlinking plugins into every `$HOME` |
| `fix(events): honour events.auto_turn=false in SessionActor` | — (documented opt-out does nothing in daemon mode) |
| `fix(status): --memory in daemon mode counts the daemon tree once` | the bar's `--pid` workaround |
| `feat(daemon): restore Parked sessions on cold start (--restore)` | `openjawz-ambient.service` |
| `docs: PROTOCOL_VERSION 2; --idle-exit help text; un-globalise --attach flags` | — |

`synaps daemon sessions --json` already exists; the bar is written against it. Current state of each: `docs/status.md`.
