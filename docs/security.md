# Security — what OpenJAWZ does and does not do

| surface | v0.1 behaviour | enforced by |
|---|---|---|
| bootstrap | two files (`boot` + `boot.sha256`), verified with `sha256sum -c` before `sh boot`; refuses to run as root; `sudo`/`doas` only for `pacman` and the repo line; prompts go through `/dev/tty` or `OPENJAWZ_YES=1` | `boot`, `tests/pkg` (sha256 current, ≤ 4 KB) |
| packages | `[openjawz]` repo with `SigLevel = Required DatabaseOptional` (package signatures required; database signing is v0.1.1); the only unsigned mode is `--local DIR` and `doctor` flags it yellow | `openjawz-keyring`, `openjawz doctor` |
| daemon socket | Unix socket under `~/.synaps-cli/run/`, one per user, in your home (not `/tmp`); no TCP in v0.1 (deck = SSH-forwarded socket) | runtime; `docs/spectrum.md` |
| secrets | none in this tree (patterns in `tests/grep-guard/secrets.txt`, path globs in `paths.txt`); `~/.synaps-cli/config` is scanned by `doctor` — only `provider.*` keys are expected | `tests/grep-guard` on every push |
| brain | secret-shaped content refused at extract time (`brain/secret-patterns.txt`); consolidate runs a scrub pass; `.r8` files are 0600 under `~/.config/axel/` and never leave the machine | `brain/memory-policy.md`, `openjawz brain consolidate` |
| hooks | bridges run as your user under `background.slice`; each is one `synaps send --session ambient` — never `--broadcast`; notification-out via `notify-send` only | `hooks/README.md` (the event contract) |
| units | user units only; nothing system-wide except the pacman hook that *prints* "run `openjawz migrate`" | PKGBUILD |
| uninstall | `openjawz uninstall` removes packages, units, the repo line and plugin symlinks; the brain and state survive unless `--purge` | `tests/uninstall-clean` |

Report issues at the repository issue tracker. There is no bug bounty.
