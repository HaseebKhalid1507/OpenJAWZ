# Gauntlet Loop

**When:** a product (repo, installer, release) is "done" by the builders and before it's called shippable. After `build-feature`, before the PR/release.

**What it is:** N adversaries, each with a different reason to reject, run in ROUNDS. Every finding gets fixed by a builder, then the *whole* gauntlet runs again. Exit only when a full round returns planner must-fix from every adversary — or after MAX_ROUNDS with the residue listed honestly.

Not one reviewer. Not "review then fix once." A loop, with a memory of what was already found so nobody re-finds it.

## The adversaries (pick per product; these are the defaults)

| # | adversary | agent | pretends to be | rejects for |
|---|---|---|---|---|
| 1 | **The Stranger** | implementer/debugger in a **fresh container**, README-only, no repo access beyond the public URL | a competent user who has never seen the project | anything that doesn't work from the README alone; every place they had to guess; the 10-minute clock |
| 2 | **The Packager** | debugger | an AUR/repo maintainer | PKGBUILD/`namcap` errors, files outside package ownership, scriptlets doing user-home work, broken upgrade path (install v0 → upgrade → migrations ran once), uninstall leaves junk |
| 3 | **The Auditor** | reviewer (security mode) | a security reviewer reading `curl \| bash` with contempt | unpinned/unchecksummed payloads, socket perms, secrets in files, the privacy grep-guard, anything that runs as root that shouldn't, env leakage |
| 4 | **The Architect** | reviewer | the reviewer who read the plan | divergence from the design, coupling to a specific person/machine, missing kill-switches, claims without a test |
| 5 | **The Reader** | researcher | a skeptic reading the docs | every claim without a command or number behind it; stale/contradicting docs; the forbidden-topic rule (e.g. no naming competitors) |
| 6 | **The Operator** (optional) | debugger | someone running it for a week | update path, idle-exit, reboot survival, logs, what breaks on a laptop lid-close, uninstall |

## The loop

```
round = 1
findings_seen = {}
loop:
  run all adversaries IN PARALLEL, each writes GAUNTLET/round-<n>-<adversary>.md
     (verdict SHIP | SHIP-WITH-NITS | NO-SHIP; findings by severity, file:line;
      each finding has a stable id = sha1(adversary + short title))
  merge → GAUNTLET/round-<n>.md  (dedupe against findings_seen; NEW vs REPEAT is explicit)
  if every adversary == SHIP (nits allowed only if listed as accepted): EXIT PASS
  if round == MAX_ROUNDS: EXIT with residue listed
  dispatch builders on disjoint scopes for every NEW must-fix; tests for each
  builders push; re-run the product's own test/bench gates
  round += 1
```

MAX_ROUNDS default 4. A REPEAT finding (same id, still open after a fix round) is a **process failure** — escalate it, don't just fix it again.

## Rules

- Adversaries are **read-only** on the product. Builders never review their own round.
- The Stranger always runs in a **fresh environment** (container / VM); if the product is an installer, it runs the public entry point, not a local path.
- Every round's file is kept. The final `GAUNTLET/summary.md` lists rounds, findings per round (new/repeat/fixed), residue, and the exit condition — it ships with the product (`docs/` or the PR body).
- Fixes land with tests. A fix without a test is a REPEAT waiting to happen.
- The orchestrator does not fix findings by hand except merge conflicts. Dispatch, collect, merge, loop.

## Output

`GAUNTLET/summary.md` in the workspace, and a short "Gauntlet: N rounds, exited on PASS / residue: …" line in the release notes. If it exited on residue, the residue is the first line, not the last.
