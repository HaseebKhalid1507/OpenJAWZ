# OpenJAWZ v0.1.0 — status

Integration pass on `main` (A + B + C merged), tests run on the build box against the Synaps
`integration@07007af7` tarball (`synaps 0.9.0` reporting; the `0.9.1rc1` tag is P-R1, see below).

## Test table

| test | ci | result | time |
|---|---|---|---|
| `tests/grep-guard` | fast | **PASS** | 0.1 s |
| `tests/lint` | fast | **PASS** | 6.5 s |
| `tests/pkg` | fast | **PASS** (namcap on built packages: 0 errors) | 0.1 s |
| `tests/templates` | fast | **PASS** | 0.1 s |
| `tests/tools` | fast | **PASS** | 1.2 s |
| `tests/hooks` | container | **PASS** — event delivered, ambient live (delivery leg; toast leg by `openjawz notify` directly) | 104 s |
| `tests/install-smoke desktop` | container | **PASS** — boot → daemon → doctor no red → attached in **21 s** (8 s / 34 s on reruns), warm mirror | 200 s wall incl. image prep |
| `tests/install-smoke vm` | container | **PASS** — 34 s | — |
| `tests/uninstall-clean` | container | **PASS** — 10/10 incl. the `--purge --all` leg (reinstall via `boot --local`, then purge) | 384 s wall (two installs) |
| `tests/memprof/gates.sh --dry` | hardware | **PASS** (scripts execute; real gates not run — hardware box only) | 0.1 s |
| `tests/upgrade-path` | container | **not written** (slipped, §9 allowed) | — |

Container rule: smoke runs only on the build box with udev masked in the image layer and a private
cgroupns; host `/dev/dri` timestamps and the journal were checked before and after every run — clean.

## Green

- Split packages (`openjawz-meta` + 7 members) install everything B and C produced; `openjawz doctor` sees
  templates, crew roles, hook bridges, brain policy, plugins (green rows) on a fresh box.
- `boot --local` → `openjawz install` (12 stages) → doctor **0 red** → `synaps attach --create` attaches.
- bug-1 canary: `daemon.json` survives `synaps send` and `status --memory`.
- Ambient session named at create; `oj::send` and `bridge::_send` both target it by name.
- `openjawz-ambient.service` (oneshot, after the daemon) enabled at install.
- Uninstall keeps `synaps-bin`/`axel-bin` unless `--all`; `--purge` removes state + brain.
- Every push: grep-guard (no forbidden names, no secrets, no distro name), shellcheck, `bash -n`, `py_compile`.

## Yellow (what doctor shows on a fresh box, and why)

- **brain absent** — no `axel` release tarball exists yet, so `axel-bin` cannot build from a URL and `boot`
  does not pull it (`optdepends`). With `AXEL_TARBALL=` the local build produces the package; the meta still
  only recommends it. `openjawz brain init` skips; the consolidation timer is installed but idle.
- **desktop / notify hooks** — `ConditionEnvironment=WAYLAND_DISPLAY`; in a container and on any box that
  has not exported the Wayland env to systemd they exit clean. `doctor` prints the exec-once line.
- **fs hook** — exits clean when none of `watch.list` (`~/Projects`, `~/Downloads`) exists.
- **repo unsigned** — `--local` mode only (`OPENJAWZ-LOCAL` marker); public repo is `SigLevel = Required`.
- `openjawz-keyring` builds from `$startdir/keys` (namcap E) until real key material lands (P-R3), at which
  point the keys become `source=()` entries.
- `synaps-bin`/`axel-bin` PKGBUILDs carry placeholder sha256 (`000…`) for the release-URL path; the local
  tarball path verifies against `SHA256SUMS`.
- The `axel` binary in hand has no `consolidate`/`extract` and does not read `~/.synaps-cli/axel.toml`;
  `brain/axel.default` ships the contract, `openjawz brain consolidate` degrades to a reindex.

## Slipped to v0.1.1

From the three handoffs and PLAN §9:

- **A**: `tests/upgrade-path`; `release.yml`; `build-repo.sh` signing path (needs P-R3); `update`'s snapshot
  tree beyond the yellow line; AUR mirror (`.SRCINFO`, `synaps-bin` + `openjawz-meta`).
- **B**: `deck/openjawz-deck` script + `docs/deck.md` (README skeleton line only); chronos timer is shipped
  but unexercised; `tests/hooks/sway-headless.sh` written, not executed in a container; memprof `gates.sh`
  real run on the hardware box; quickshell note; hotkey timing on real Hyprland.
- **C**: tools batch 2 (toolmake, tools-doc, maintain, backup, yt, web, tracker); the 12 lifted skills
  (5 discipline skills shipped); manual 03–05 (01–02 shipped); `refresh`; whiptail fallback for onboard.
- Derivative-distro matrix entry (`ID_LIKE=arch` os-release override in the smoke).
- Gauntlet round 2 (round 1: see "Gauntlet" below) → `docs/gauntlet/summary.md` once committed.

## Gauntlet

Playbook: `crew/playbooks/gauntlet.md`. **Round 1 has run** (five adversaries — Stranger, Packager, Auditor,
Architect, Reader — on the A+B+C merge). Verdict: **NO-SHIP**, findings split into three fix scopes
(A: packaging/boot, B: daemon/hooks/ui, C: docs truth + brain + ops) and landed as `fix1/{a,b,c}`. The
round files themselves are not in this tree; the fixes are the commits and this section is the summary.
Scope C, this branch: README says local mode is the only install path; no `openjawz deck` verb is
claimed; architecture/spectrum describe the shipped `Type=simple` daemon; memory gates are stated as
bench-box-only; `brain scan` really scans (Python `sqlite3` REGEXP, fixture-DB test); `brain purge`;
`umask 077` on brain backups; one axel spawn story; onboarding counted honestly; OP.md lists only verbs
that exist; `openjawz shutdown` verifies before it writes. Round 2 has not run. `docs/gauntlet/` does
not exist until a round's merged file is committed.

## Synaps PRs still needed (PLAN §7)

Landing on `integration` (prerelease carries them):
1. `fix(registry): list_active_sessions skips daemon*.json instead of unlinking`
2. `feat(session): name propagates at create — attach --name, saveas rewrites run/<sid>.json + SessionMeta`
3. `fix(daemon): --continue <journal> attaches to the live actor holding it`

To file:
4. `feat(daemon): systemd socket activation — adopt LISTEN_FDS fd 3, sd_notify(READY=1), keep flock + daemon.json`
5. `feat(daemon): --tcp ADDR --token-file F (check_bind_policy, ct_eq)`
6. `feat(daemon): remote-ready liveness — SYNAPS_DAEMON_REMOTE=1 trusts a connectable socket, skips reap_stale/autospawn`
7. `feat(daemon): notification tap — Subscribe{notifications} control frame`
8. `feat(daemon): daemon sessions --json gains keep_warm, streaming, last_activity`
9. `feat(cli): synaps hook <event> --data JSON --expects-response`
10. `feat(extensions): system plugin root /usr/share/synaps/plugins + SYNAPS_PLUGIN_PATH`
11. `fix(events): honour events.auto_turn=false in SessionActor`
12. `fix(status): --memory in daemon mode counts the daemon tree once`
13. `feat(daemon): restore Parked sessions on cold start (--restore)`
14. `docs: PROTOCOL_VERSION 2; --idle-exit help text; un-globalise --attach flags`

axel (from HANDOFF-C): `feat(config): load ~/.synaps-cli/axel.toml` · `feat(inject): relevance floor
injection_min_score` · `feat(extract): sensitivity level + secret-pattern refusal` · `feat: consolidate phase 4 scrub`.

## Prerequisites the maintainer owns

- **P-R1** SynapsCLI prerelease tag `v0.9.1rc1` from `integration` (cargo-dist artifacts + `SHA256SUMS`);
  `packages/synaps-bin/PKGBUILD` sha256 then gets its real value.
- **P-R2** axel release tarball (`axel-vX-x86_64-unknown-linux-gnu.tar.gz` + sha256) → `axel-bin` builds from
  a URL → the brain rows go green.
- **P-R3** The signing key: generate on the hardware box, public material into `packages/openjawz-keyring/keys/`,
  fingerprint into README; `build-repo.sh` signing path + `SigLevel = Required` end to end.
