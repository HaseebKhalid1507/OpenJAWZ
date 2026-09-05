# profiles/

One env file per profile, copied by `openjawz install --profile P` to `~/.config/openjawz/profile.env` and read by `synaps-daemon.service` (`EnvironmentFile=`) and every hook. Auto-detected when `--profile` is omitted: lid switch → laptop, aarch64 → deck, no `/dev/dri` → vm, else desktop.

| key | desktop | laptop | deck | vm |
|---|---|---|---|---|
| `OPENJAWZ_IDLE_EXIT` (s; 0 = daemon stays resident) | 0 | 0 | — | 1800 |
| `OPENJAWZ_LINGER` (loginctl enable-linger) | — | 1 | — | 1 |
| `SYNAPS_DAEMON_PARK_GRACE_SECS` | 60 | 60 | — | default |
| `OPENJAWZ_HOOKS` (units `openjawz hooks enable` turns on) | desktop,fs,notify,chronos,system | same | none | chronos |
| `OPENJAWZ_DAEMON=remote` (client-only; no local daemon) | — | — | yes | — |
| `SYNAPS_DAEMON_AUTOSPAWN` (0 = no autospawn on attach) | — | — | 0 | 0 |

Why no idle-exit on desktop/laptop: an idle-exit drops the ambient session's registration, and every hook then falls into the inbox trap until something re-attaches. The daemon stays resident (≈ 10 MB); sessions park.
