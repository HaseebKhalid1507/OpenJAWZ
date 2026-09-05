# daemon/

`synaps-daemon.service` — a plain systemd **user** unit (`Type=simple`, `ExecStart` → `openjawz-daemon-exec` → `synaps daemon --foreground`). Plus `config.default` (flat `key = value`, seeded into `~/.synaps-cli/config`), `mcp.json.default` (the `axel` MCP server, `shared: true`; `openjawz brain init` merges it into `~/.synaps-cli/mcp.json` — the extension in `plugins/axel` is the second axel process on the same `.r8`, see `docs/brain.md`), `profiles/` (desktop / laptop / deck / vm env files) and `environment.d/10-openjawz.conf` (PATH for the tools).

## Why not socket activation

The runtime binds its own socket and does not read `LISTEN_FDS`; a `.socket` unit would race that bind. So there is **no `synaps-daemon.socket`** in v0.1. The daemon stays resident; *sessions* park to ~2 MB when nobody is watching. Socket activation + idle-exit land with the runtime PR listed in `docs/architecture.md`.

## The unit, and why each line

- `Type=simple` + `--foreground` — what `--detach` would exec anyway; never `--detach` under systemd.
- `RestartPreventExitStatus=3` — exit 3 is the runtime's *refusal* (config problem, lock held); restarting would loop.
- `StartLimitIntervalSec=0` — a crash-looping service must never be locked out; the fix is `openjawz doctor`, not `reset-failed`.
- `RuntimeDirectory=openjawz` + `RuntimeDirectoryPreserve=yes` — `$XDG_RUNTIME_DIR/openjawz` (locks, hook flags) survives a restart.
- `EnvironmentFile=-%E/openjawz/profile.env` then `-%E/openjawz/env` — profile first, then your own overrides / API keys (0600, re-read on every start).
- `TimeoutStopSec=90` — the daemon saves every session on SIGTERM; give it the budget.
- The socket, lock and `daemon.json` live where the runtime puts them: `~/.synaps-cli/run/`. We do not move them.

`openjawz-daemon-exec` exists because `ExecStart=` cannot do conditional flags: it appends `--idle-exit N` only when the profile sets `OPENJAWZ_IDLE_EXIT` to something other than 0. `openjawz-migrate-notify.service` is the login-time toast for pending migrations.
