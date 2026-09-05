# plugins/

Synaps plugins shipped by OpenJAWZ → `/usr/share/openjawz/plugins/<name>`, symlinked into `~/.synaps-cli/plugins/` by
`openjawz install`. Manifests use PATH commands and relative `args` — no absolute paths, no per-home copies.

| plugin | state | what |
|---|---|---|
| `axel` | enabled | the brain extension (`command: axel`, from `axel-bin`); `shared` — one process for every session |
| `synaps-tasks` | enabled | native task tools (add/done/list/due/today/next/focus/pin/goals/status/block); `DATA_DIR` from `$OPENJAWZ_DATA` — the same `tasks.json` as `openjawz tasks` |
| `weather-lens` | enabled | current conditions by place name, open-meteo, stdlib, no key; also `ops/boot.d/10-weather` |
| `heartbeat` | **disabled** | keeps a prompt cache warm: beat at 284 s < the 300 s TTL, max 12 beats. Costs tokens — enable only if you pay per cache miss (`disabled_plugins` in config) |
| `chronos` | enabled | lives in `hooks/chronos/plugin` (owned by the hooks package) |

Upstream, declared not vendored: `web-tools`, `tmux-tools` — see `ops/plugins.list`.
