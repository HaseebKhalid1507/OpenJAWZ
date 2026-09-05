# OpenJAWZ

**An agent that lives in your OS, not in a terminal tab.**

OpenJAWZ is the operating layer on top of the [Synaps](https://github.com/HaseebKhalid1507/SynapsCLI) runtime: one daemon per user that owns your sessions, your memory, and your tools — and a ~2 MB client you open from any terminal, any screen, any machine.

Close the laptop mid-task. Open it on the desktop. Same session, same context. Every terminal is a window into one running mind.

## Install

Arch-based Linux (Arch, CachyOS, EndeavourOS, …). It installs **packages, not a distro** — it never touches your bootloader, display manager, or `/etc/pacman.conf`. `sudo` is used only where a package install needs it; the script itself refuses to run as root.

**Today, local mode is the only mode that installs.** The public `curl | sh` path is wired but deliberately fails closed (in ~1 s, writing nothing) until the maintainer prerequisites land — a Synaps prerelease tag, an axel release tarball, and the signing key (`docs/status.md`). No pretending otherwise.

### Local mode

You need an Arch-based system (or `archlinux:latest` in a container), `git`, `base-devel`, `gnupg`, and a **Synaps runtime tarball with daemon mode**. There is no Synaps release with daemon mode yet, so build one from the `integration` branch of [SynapsCLI](https://github.com/HaseebKhalid1507/SynapsCLI):

```sh
# build the runtime (once)
git clone -b integration https://github.com/HaseebKhalid1507/SynapsCLI && cd SynapsCLI
cargo build --release
tar czf /tmp/synaps.tar.gz -C target/release synaps
cd ..
```

Then build the packages and boot:

```sh
git clone https://github.com/HaseebKhalid1507/OpenJAWZ && cd OpenJAWZ
SYNAPS_TARBALL=/tmp/synaps.tar.gz packages/build-repo.sh --no-sign   # PKGBUILDs → build/repo (local UNSIGNED repo)
OPENJAWZ_YES=1 sh boot --local build/repo                            # non-interactive; prints a red UNSIGNED LOCAL REPO banner
openjawz doctor                                                      # green rows, some yellow (brain absent until axel ships)
synaps --attach --new                                               # you are attached
```

`--local` stages a world-readable copy of the repo under `/tmp` for the run (pacman ≥ 7 downloads as its own user and can't read your home directory) and uses a **transient** pacman config — your `/etc/pacman.conf` is never modified. `openjawz update --local build/repo` upgrades from the same directory later.

That is exactly what `tests/install-smoke` runs in `archlinux:latest` (boot → daemon active → doctor no red → attached, ~21 s on a warm mirror), and what `tests/install-smoke/verbatim-readme.sh` runs against the recipe above so it can't drift.

When it's done you have:

- **a daemon** — `synaps daemon` as a systemd *user* service (`synaps-daemon.service`, `Type=simple`). Sessions park to ~2 MB when nobody is watching; the daemon stays resident on desktop/laptop (the vm profile idle-exits after 30 min). No socket activation yet — the runtime auto-spawns the daemon on first attach; the `.socket` unit lands with a runtime PR (`docs/architecture.md`).
- **a brain** — persistent memory with provenance, one writer, every session reads it. Requires `axel`; `openjawz doctor` tells you if it's missing.
- **a crew** — planner / implementer / reviewer / tester (14 roles) with a build discipline that measures before it designs.
- **hooks** — your desktop, filesystem, notifications, and clock feed an always-on *ambient* session (~2 MB idle), through a content filter that drops OTPs, tokens, and password-manager prompts before the model ever sees them.
- **an identity** — yours, from a template. Tell it your name and what you do (`openjawz onboard`).

## Why a daemon

Every agent CLI you've used spawns a full engine, its own memory, and its own sidecar processes per terminal. On a real machine that's 40–260 MB *per open terminal*, and it all dies when the terminal does.

| | per additional terminal |
|---|---:|
| engine-per-terminal | 40–260 MB |
| OpenJAWZ (`synaps --attach`, one more TUI on the daemon) | **~2 MB** |

These are the Synaps daemon-mode numbers, measured there (`docs/memory-budget.md` restates them; re-measure with `tests/memprof/`, a bench-box run, not CI). Caveats stated, not hidden: one rendered code block costs **+11 MB** of compiled syntax grammars until idle eviction (120 s); the whole desktop hook set is budgeted at **≤ 25 MB**. Three names on purpose: `synaps --attach [--new]` is the TUI on the daemon (the hotkey — you); `synaps attach --create` is the line client (scripts, the ambient session); bare `synaps` is the in-process engine.

## The spectrum

| where | what runs there |
|---|---|
| desktop | daemon + everything, desktop hooks, bar widget |
| laptop | same; suspend/resume reach the ambient session as events, sessions park on a 60 s grace |
| cyberdeck | **client only** — daemon lives on your desktop. v0.1.0rc1 ships the profile (no local daemon, no hooks); you forward the daemon's socket over SSH yourself (`deck/README.md`, two lines). No `openjawz deck` verb yet; native `--tcp` + broker token is a runtime PR. |
| VM / server | the daemon *is* the machine's agent; a browser is a client |

Same binary. Same brain. Windows into one mind.

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
tests/      grep-guard, lint, pkg, templates, tools, hooks, install-smoke, uninstall-clean, memprof, + the round-5 proof tests
```

Config is flat `key = value` (`daemon/config.default`) — no sections. No Rust here; if the runtime needs to change, that's a PR to Synaps.

## Uninstall

```sh
openjawz uninstall              # packages + units + repo line; keeps the brain and your state
openjawz uninstall --all        # also removes synaps-bin / axel-bin
openjawz uninstall --purge      # also removes state and the brain (asks first; --yes to skip)
```

## Security

Signed repo on the public path (`SigLevel = Required` — not yet published; local mode is `Optional TrustAll` and says so, loudly). No secrets in this tree, enforced on every push by `tests/grep-guard` (the private-word list is HMAC-hashed under a key that isn't in the repo). Scripts never run as root. OS-event hooks fail *closed* — a malformed filter drops everything rather than leak it. The brain's secret-pattern refusal is in `brain/memory-policy.md`; the reviewer's table is in `docs/security.md`.

## Status

**v0.1.0rc1** — passes install-smoke in `archlinux:latest` via `boot --local` (boot → daemon active → doctor no red → attached, ~21 s on a warm mirror; image pull excluded). No public repo yet — the prerequisites are in `docs/status.md`.

What `openjawz doctor` shows yellow on a fresh box, honestly:

- **brain absent** — until an `axel` release tarball exists, `axel-bin` can't build from a URL; the brain rows stay yellow and `openjawz brain init` skips.
- **desktop / notify hooks** — condition-skipped until a Wayland session exports `WAYLAND_DISPLAY` to systemd.
- **fs hook** — exits clean if none of `watch.list` exists yet (`~/Projects`, `~/Downloads`).
- **repo unsigned** — always, in v0.1.0rc1: local mode is the only mode. The public repo will be `SigLevel = Required`.

**Gauntlet:** six adversaries — a stranger with only this README, a pacman maintainer, a security auditor, an architect, a docs skeptic, and a week-long operator — reviewed this in rounds until every one returned SHIP or SHIP-WITH-NITS with zero open must-fix. The full trail is in `docs/gauntlet/summary.md`.

## License

MIT.
