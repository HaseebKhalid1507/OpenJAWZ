# The spectrum

One binary, one brain, one config difference per profile (`daemon/profiles/`).

| profile | daemon | client | sessions | notes |
|---|---|---|---|---|
| desktop | local, resident | local, hotkey | park 60 s after the last client detaches | all five hooks, bar widget |
| laptop | local, resident | local, hotkey | same 60 s park; suspend is just a `sleep:` event to the ambient session | same hooks; `loginctl enable-linger` so the daemon outlives the last login |
| deck | **remote** (desktop / VPS) | local, 2 MB | live where the RAM is | v0.1.0rc1: profile only — you forward the socket over SSH by hand (`deck/README.md`). `--tcp` + broker token and an `openjawz deck` verb are not shipped |
| vm | the daemon *is* the VM's agent; idle-exits after 1800 s with no clients and no sessions | remote | park; the daemon re-spawns on next attach | headless; `chronos` hook only; linger on |

The cyberdeck doesn't need to run the agent. It needs to run 2 megabytes.
