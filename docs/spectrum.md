# The spectrum

One binary, one brain, one config difference per profile (`daemon/profiles/`).

| profile | daemon | client | sessions | notes |
|---|---|---|---|---|
| desktop | local | local, hotkey | park after grace | desktop hooks, bar widget |
| laptop | local | local | park on lid-close | `keep_warm` off by default |
| deck | **remote** (desktop / VPS over Tailscale) | local, 2 MB | live where the RAM is | aarch64 client; `--tcp` + broker token |
| vm | the daemon *is* the VM's agent | browser / remote | — | headless hosts |

The cyberdeck doesn't need to run the agent. It needs to run 2 megabytes.
