# tests/

Every `tests/<name>/run.sh`: exit **0** pass / **1** fail / **77** skipped (missing prerequisite, printed). First lines carry `# ci: fast|container|hardware`. All honour `OPENJAWZ_TEST_VERBOSE=1`.

| tier | when | tests |
|---|---|---|
| `fast` | every push, < 10 s, no container | `grep-guard`, `lint`, `templates`, `tools`, `brain`, `hook-filter`, `pkg`, `migrate`, `boot-db-sig`, `build-repo-pkgrel`, `ambient-unit`, `heartbeat`, `memprof` (dry parse only) |
| `container` | by hand on a builder (`.github/workflows/install-smoke.yml` is `workflow_dispatch` only until a runner exists); a privileged `archlinux:latest` with systemd | `install-smoke`, `uninstall-clean`, `hooks` |
| `hardware` | never in CI; run by hand on real hardware, numbers pasted into release notes | memprof's real gates (tests/memprof/gates.sh without --dry) |

Run locally: `tests/grep-guard/run.sh && tests/lint/run.sh`. Container tests need docker: `tests/install-smoke/run.sh` (≈ 3–8 min, builds the packages from the checked-out commit into a local repo and runs `boot --local` against it).

`tests/pkg` checks that every `tests/*/run.sh` header tier equals this table.
