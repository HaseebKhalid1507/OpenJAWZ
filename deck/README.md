# deck/

The client-only profile. **v0.1.0 ships the profile and this file — nothing else.** There is no
`openjawz deck` verb, no `docs/deck.md`, no aarch64 build notes yet (slipped to v0.1.1, `docs/status.md`).

What the profile does (`daemon/profiles/deck.env`, picked by default on aarch64):

- `OPENJAWZ_DAEMON=remote` + `SYNAPS_DAEMON_AUTOSPAWN=0` — `openjawz install` skips the daemon unit and
  `synaps` never spawns one locally.
- `OPENJAWZ_HOOKS=` — no bridges; the deck has nothing to watch.

What you do by hand until the runtime grows `--tcp` + a broker token (PR listed in `docs/architecture.md`):

```sh
# on the deck — forward the desktop's daemon socket to a local path, keep it up
ssh -N -L "$HOME/.synaps-cli/run/daemon.sock:.synaps-cli/run/daemon.sock" desktop &
synaps attach --create            # the ~2 MB client, talking to the desktop's daemon
```

The forwarded socket is only as safe as the SSH session; there is no second credential. The path is
the runtime's (`~/.synaps-cli/run/daemon.sock` on both ends; `synaps daemon status` prints it). A stale
local socket file blocks the forward — remove it first. Liveness over a forwarded socket is the
"remote-ready" runtime PR; until then `synaps daemon status` on the deck may call a reachable daemon stale.
