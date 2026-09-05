# Contributing

Short version: bash only, one library, headers on every script, the guard runs before you do.

## Rules

- **No Rust here.** If the runtime needs to change, that is a PR to [Synaps](https://github.com/HaseebKhalid1507/SynapsCLI). `docs/architecture.md` lists what we still owe it.
- **The comparable distro is never named.** CI rejects it (case-insensitive). Every adopted pattern is described as ours.
- **Nothing personal.** `tests/grep-guard/` rejects names, hostnames, private IPs, personal paths, secret-shaped strings and data files. Run it before every commit: `tests/grep-guard/run.sh && tests/lint/run.sh` (< 10 s).
- **Never touch the bootloader or the display manager.** We install onto a desktop.
- **Packages never touch `$HOME`.** Everything per-user happens in `openjawz install|update|migrate`, as the user, logged, idempotent.

## Script conventions

Every executable under `bin/`, `*/bin/`, `ops/tools/`, `crew/tools/` starts with:

```bash
#!/usr/bin/env bash            # or python3
# openjawz-<verb>: <one-line summary, ≤ 70 chars>
# usage: openjawz <verb> [--flag] <arg>
# owner: openjawz-<core|daemon|hooks|ui|crew|ops|brain>
# ci: fast                    # optional: tests/tools runs --help on it
```

then `set -euo pipefail` and `. /usr/lib/openjawz/openjawz.sh; oj::paths`. The router (`bin/openjawz`) finds `openjawz-<verb>` in `/usr/lib/openjawz/bin` then `/usr/lib/openjawz/tools`; `openjawz help` reads the headers. Multi-word verbs are subcommands of one script (`openjawz brain init`).

Cross-package verb contract: exit **0** = ok, **2** = skipped with a printed reason, **127** = not installed, anything else = fail. Stage output ≤ 5 lines.

`lib/openjawz.sh` is the only shared library. Its API is documented at the top of the file. Do not copy helpers into scripts.

## Config

`daemon/config.default` is flat `key = value` — it is not TOML. `mcp.json.default` is JSON.

## Migrations

`migrations/<epoch>-<user|system>-<slug>.sh`, epoch = commit time (`git log -1 --format=%cd --date=unix`), ≥ every existing one. Idempotent, no inter-migration dependencies, header from `migrations/TEMPLATE.sh`. See `migrations/README.md`.

## Commits

`<scope>: <imperative>` with scope ∈ `core|pkg|daemon|hooks|ui|crew|ops|brain|docs|tests|ci`. The tree is green at every commit.

## Ownership

Paths have owners while a release is being built; if you need a file outside your prefix, write the need down and move on. Do not edit another package's files in the same PR.
