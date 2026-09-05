# OpenJAWZ

**An agent that lives in your OS, not in a terminal tab.**

OpenJAWZ is the operating layer on top of the [Synaps](https://github.com/HaseebKhalid1507/SynapsCLI) runtime: one daemon per user that owns your sessions, your memory, and your tools — and a ~2 MB client you can open from any terminal, any screen, any machine.

Close the laptop mid-task. Open it on the desktop. Same session, same context. Every terminal is a window into one running mind.

## The 10-minute promise

```sh
curl -fsSLO https://raw.githubusercontent.com/HaseebKhalid1507/OpenJAWZ/main/boot
curl -fsSLO https://raw.githubusercontent.com/HaseebKhalid1507/OpenJAWZ/main/boot.sha256
sha256sum -c boot.sha256 && sh boot
```

Two files, one checksum, then run it. (A short domain will front this once it is live; the raw URL is the source of truth.)

**Not live yet.** v0.1.0 has no published repo, no release keyring, and no signed packages: the keyring
checksum in `boot` is a placeholder and the public path stops there on purpose (it fails closed in about a
second and writes nothing under `/etc`). Today the only path that installs is local mode.

### Local mode

Prerequisites: an Arch-based system (or `archlinux:latest` in a container), `git`, `base-devel`, `gnupg`,
and a **Synaps runtime tarball** — there is no Synaps release with daemon mode yet, so build one from the
`integration` branch of [SynapsCLI](https://github.com/HaseebKhalid1507/SynapsCLI) (`cargo build --release`,
then `tar czf synaps.tar.gz -C target/release synaps`) and pass it in. Without it the build fails on purpose.

```sh
git clone https://github.com/HaseebKhalid1507/OpenJAWZ && cd OpenJAWZ
SYNAPS_TARBALL=/path/to/synaps.tar.gz packages/build-repo.sh --no-sign     # PKGBUILDs → build/repo, local UNSIGNED repo
OPENJAWZ_YES=1 sh boot --local build/repo                                   # non-interactive; prints a red UNSIGNED LOCAL REPO banner
openjawz doctor                                                             # green rows, some yellow (brain absent until axel ships)
synaps --attach --new                                                       # you are attached
```

`--local` stages a world-readable copy of the repo under `/tmp` for the run (pacman ≥ 7 downloads as its
own user and cannot read your home directory) and uses a **transient** pacman config — `/etc/pacman.conf`
is never modified. `openjawz update --local build/repo` upgrades from the same directory later.

That is exactly what `tests/install-smoke` runs in `archlinux:latest` (21 s on a warm mirror). The public
path turns on when the maintainer prerequisites in `docs/status.md` land: a Synaps prerelease tag, an axel
release tarball, and the signing key.

Arch-based Linux (Arch, CachyOS, EndeavourOS, …). Installs packages, not a distro. Never touches your bootloader or display manager. `sudo` is called where needed; the script itself refuses to run as root.

When it's done you have:

- **a daemon** — `synaps daemon` as a systemd *user* service (`synaps-daemon.service`, `Type=simple`). Sessions park to ~2 MB when nobody is watching; the daemon itself stays resident on desktop/laptop (the vm profile idle-exits after 30 min). No socket activation yet — the runtime auto-spawns the daemon on first attach if it is not running; the `.socket` unit lands with a runtime PR (`docs/architecture.md`, "What the runtime still owes us").
- **a brain** — persistent memory with provenance, one writer, every session reads it. Requires `axel`; `openjawz doctor` tells you if it is missing.
- **a crew** — planner / implementer / reviewer / tester (14 roles) with a build discipline that measures before it designs.
- **hooks** — your desktop, filesystem, notifications, and clock feed an always-on *ambient* session that costs ~2 MB while nothing is happening.
- **an identity** — yours, from a template. Tell it your name and what you do (`openjawz onboard`).

## Why a daemon

Every agent CLI you've used spawns a full engine, its own memory, and its own sidecar processes per terminal. On a real machine that's 40–260 MB *per open terminal*, and it all dies when the terminal does.

| | per additional terminal |
|---|---:|
| engine-per-terminal | 40–260 MB |
| OpenJAWZ (`synaps --attach`, one more TUI on the daemon) | **~2 MB** |

The numbers are the Synaps daemon-mode numbers, measured there (its memory-budget doc is the source; ours restates them in `docs/memory-budget.md`). The scripts to re-measure are in `tests/memprof/`; the gates are a bench-box run, not CI, and v0.1.0 has not re-run them in this tree. Caveats stated, not hidden: one rendered code block costs **+11 MB** of compiled syntax grammars until idle eviction (120 s); desktop hooks are budgeted at **≤ 25 MB total** for the whole set (table in `docs/memory-budget.md`). Two spellings, on purpose: `synaps --attach [--new]` is the TUI on the daemon (the hotkey, you); `synaps attach --create` is the line client (scripts, the smoke, the ambient session). Bare `synaps` is the in-process engine. Our install smoke measures *attach*, not resume — the resume latency is the runtime's number, not ours.

## The spectrum

| where | what runs there |
|---|---|
| desktop | daemon + everything, desktop hooks, bar widget |
| laptop | same; suspend/resume reach the ambient session as events, sessions park on the same 60 s grace |
| cyberdeck | **client only** — daemon on your desktop. v0.1.0 ships the profile (no local daemon, no hooks) and nothing else: you forward the daemon's socket over SSH yourself (`deck/README.md` has the two lines). No `openjawz deck` verb exists yet; native `--tcp` + broker token is a runtime PR. |
| VM / server | the daemon *is* the machine's agent; a browser is a client |

Same binary. Same brain. Two windows into one mind.

## Layout

```
packages/   PKGBUILDs — the product; everything else is source for these
daemon/     systemd user unit, config.default (flat key = value), profiles (desktop/laptop/deck/vm)
hooks/      desktop / fs / notify / chronos / system → `synaps send` → the ambient session
crew/       roles, playbooks, flavors
ops/        skills, tools, the SOUL / OP / AGENTS templates, boot/checkpoint/shutdown
brain/      memory policy, consolidation timer, axel defaults
ui/         hotkey summon, bar widget, themes
deck/       the client-only profile and aarch64 notes
migrations/ timestamped, run in order by `openjawz update` — from commit one
docs/       architecture, spectrum, memory budget, security, status
tests/      grep-guard, lint, pkg, templates, tools, hooks, install-smoke, uninstall-clean, memprof
```

Config is flat `key = value` (`daemon/config.default`) — no sections. No Rust here. If the runtime needs to change, that's a PR to Synaps.

## Uninstall

```sh
openjawz uninstall              # packages + units + repo line; keeps the brain and your state
openjawz uninstall --all        # also removes synaps-bin / axel-bin
openjawz uninstall --purge      # also removes state and the brain (asks first; --yes to skip)
```

## Security

Signed repo (`SigLevel = Required` on the public path — not yet published; local mode is `Optional TrustAll` and says so), no secrets in this tree (`tests/grep-guard` enforces it on every push), scripts never run as root, the brain's secret-pattern refusal is documented in `brain/memory-policy.md`. The reviewer's table lives in `docs/security.md`.

## Status

**v0.1.0 — passes install-smoke in `archlinux:latest` via `boot --local`: boot → daemon active → doctor no red → attached in 21 s on a warm mirror** (image pull excluded). No public repo yet — see "The 10-minute promise". Full table, what is yellow, and what slipped: `docs/status.md`.

What `openjawz doctor` shows yellow on a fresh box, honestly:

- **brain absent** — until an `axel` release tarball exists, `axel-bin` cannot be built from a URL; the brain rows stay yellow and `openjawz brain init` skips.
- **desktop / notify hooks** — condition-skipped until a Wayland session exports `WAYLAND_DISPLAY` to systemd (`doctor` prints the exec-once line).
- **fs hook** — exits clean if none of `watch.list` exists yet (`~/Projects`, `~/Downloads`).
- **repo unsigned** — always, in v0.1.0: local mode is the only mode. The public repo will be `SigLevel = Required`.

Gauntlet: round 1 ran and returned NO-SHIP; the fixes are on `main` and `docs/status.md` ("Gauntlet") summarises what changed. There is no `docs/gauntlet/` directory yet.

## License

MIT.
