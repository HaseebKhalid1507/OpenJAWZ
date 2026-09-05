# Gauntlet — v0.1.0rc1

Six adversaries, run in rounds against the same tree, until a full round comes back clean or the round cap is hit.
Adversaries are read-only; builders fix; every finding has a stable id so a finding that survives a fix round is
visible as a **process failure**, not rediscovered as new. Round files live in the maintainer's workspace; this
summary ships with the repo.

## Verdicts

| adversary | pretends to be | round 1 | round 2 |
|---|---|---|---|
| The Stranger | a competent user with only the README, a fresh container, a stopwatch | NO-SHIP | NO-SHIP → local path fixed in round 3 |
| The Packager | a pacman repo maintainer | NO-SHIP | NO-SHIP → 2 items fixed in round 3 |
| The Auditor | a security reviewer who hates `curl \| sh` | NO-SHIP | NO-SHIP → 3 items fixed in round 3 |
| The Architect | the reviewer who read the plan | NO-SHIP | NO-SHIP → CI key fixed in round 3 |
| The Reader | a sceptic reading the docs | NO-SHIP | **SHIP-WITH-NITS** |
| The Operator | someone running it for a week | NO-SHIP | run by hand: 2 HIGHs fixed, 1 fixed in round 3 |

Round 3 was applied by hand by the maintainer's agent (builder budget exhausted); **round 4 — a full re-run of all six on the current tree — has not happened yet.** Until it does, this product is not "clean"; it is "two rounds fixed, third applied, unverified."

## What the rounds found (canonical, deduplicated)

- **Round 1:** ~90 raw findings → 40 canonical. A third of them were one root cause — a placeholder trust root — wearing six masks. The rest split into "the docs still describe the design the plan overruled" and "nobody ran the failure branch" (`openjawz update` deadlocked on its own lock on every real terminal; `doctor` printed nothing with the daemon down).
- **Two privacy failures, both the maintainer's, both found by the Auditor:** the guard's list of forbidden private words was itself committed to the public tree (round 1); its replacement — unsalted SHA-256 of each word — was a dictionary oracle that gave up the forbidden names in milliseconds (round 2). The list is now HMAC-SHA256 under a key that is not in the repo; history was rewritten both times and verified clean from fresh clones.
- **Round 2's number:** 33 fixes were dispatched with a named proof test each. **15 shipped with the test. All 14 REPEAT findings were in the 18 without one. Zero in the 15 with one.** The playbook now requires the test run to be pasted before an id is called fixed.
- **Hooks as a governed ingress:** the content filter for OS events (OTPs, tokens, password-manager prompts) shipped in round 1's fix and **failed open** on a malformed pattern (round 2). It fails closed now, with a test.

## Residue (open at this tag)

- Migrate takes no lock when run under `update` (exported lock fd); the uninstall manifest sweep can record pre-existing user config; the ambient unit's `Upholds=` has no retry limit.
- Several doc lines the Reader re-flagged (`docs/architecture.md` install flow, `manual/02` command syntax, a stale vm re-spawn claim).
- The signed-repo install test leg is unwritten (the code path exists).
- `synaps-bin` accepts any tarball as the pinned version.
- The public install path is not live: it needs a runtime prerelease, a brain release, and a signing key — maintainer prerequisites, listed in `docs/status.md`.

## Incidents

Two, on the maintainer's machines, during round-0 testing: an install-smoke container run `--privileged` with the host's cgroup namespace re-triggered the host's GPU devices and killed a laptop panel twice while it was in use. The test driver now uses a private cgroup namespace with udev masked in the image, checks the host's `/dev/dri` timestamps and journal before and after, and never runs on a machine someone is sitting at. Recorded here because a product that tests itself has to say what its tests did.
