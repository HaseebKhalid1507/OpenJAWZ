# Security — what OpenJAWZ does and does not do

| surface | v0.1 behaviour | enforced by |
|---|---|---|
| bootstrap | two files (`boot` + `boot.sha256`), verified with `sha256sum -c` before `sh boot`; refuses to run as root; `sudo`/`doas` only for `pacman` and the repo line; prompts go through `/dev/tty` or `OPENJAWZ_YES=1` | `boot`, `tests/pkg` (sha256 current, ≤ 4 KB) |
| packages | `[openjawz]` repo with `SigLevel = Required DatabaseOptional` (package signatures required; database signing is v0.1.1); the only unsigned mode is `--local DIR` and `doctor` flags it yellow | `openjawz-keyring`, `openjawz doctor` |
| daemon socket | Unix socket under `~/.synaps-cli/run/`, one per user, in your home (not `/tmp`); no TCP in v0.1 (deck = SSH-forwarded socket) | runtime; `docs/spectrum.md` |
| secrets | none in this tree (patterns in `tests/grep-guard/secrets.txt`, path globs in `paths.txt`); `~/.synaps-cli/config` is scanned by `doctor` — only `provider.*` keys are expected | `tests/grep-guard` on every push |
| brain | secret **scan** at consolidate (`openjawz brain scan`: python sqlite3 + `REGEXP`, every pattern in `brain/secret-patterns.txt`; hits deleted via `axel forget` or a plain `DELETE`, logged to `~/.local/state/openjawz/brain-scrub.log` 0600); extract-time refusal is an axel PR; `.r8` files and backups are 0600 under a 0700 `~/.config/axel/` and never leave the machine | `brain/memory-policy.md`, `tests/brain` |
| hooks | bridges run as your user under `background.slice`; each is one `synaps send --session ambient` — never `--broadcast`; notification-out via `notify-send` only | `hooks/README.md` (the event contract) |
| units | user units only; nothing system-wide except the pacman hook that *prints* "run `openjawz migrate`" | PKGBUILD |
| uninstall | `openjawz uninstall` removes packages, units, the repo line and plugin symlinks; the brain and state survive unless `--purge` | `tests/uninstall-clean` |

Report issues at the repository issue tracker. There is no bug bounty.
