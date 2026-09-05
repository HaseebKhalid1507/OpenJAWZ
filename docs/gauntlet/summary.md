# Gauntlet — v0.1.0rc1

Six adversaries, run in rounds against the same tree, until a full round comes back clean or the round cap is hit.
Adversaries are read-only; builders fix; every finding has a stable id so a finding that survives a fix round is
visible as a **process failure**, not rediscovered as new. Round files live in the maintainer's workspace; this
summary ships with the repo.

## Verdicts

| adversary | pretends to be | r1 | r2 | r4 (verify) | r6 (final) |
|---|---|---|---|---|---|
| The Stranger | a competent user with only the README, a fresh container, a stopwatch | NO-SHIP | NO-SHIP | NO-SHIP (1 new blocker) | **SHIP-WITH-NITS** |
| The Packager | a pacman repo maintainer | NO-SHIP | NO-SHIP | **SHIP-WITH-NITS** (proven by real build) | — |
| The Auditor | a security reviewer who hates `curl \| sh` | NO-SHIP | NO-SHIP | **SHIP-WITH-NITS** | — |
| The Architect | the reviewer who read the plan | NO-SHIP | NO-SHIP | NO-SHIP (fixes without tests) | **SHIP** |
| The Reader | a sceptic reading the docs | NO-SHIP | SHIP-WITH-NITS | **SHIP-WITH-NITS** (held) | — |
| The Operator | someone running it for a week | NO-SHIP | run by hand | **SHIP-WITH-NITS** (proven live) | — |

**Exit: PASS at round 6.** Round 3 was applied by hand (builder budget exhausted) and left unverified. Round 4 was the full six-adversary re-run against the round-3 tree: four flipped to SHIP-WITH-NITS (the two that install — Packager, Operator — proved the round-3 fixes hold with real builds on an isolated box), two stayed NO-SHIP — the Stranger for one new blocker (the README local-mode recipe said `--throwaway`, which *signs* the repo, while `boot --local` mounts it `TrustAll`, which pacman 7.1 no longer honours for an unknown key — the recipe was never run end-to-end) and the Architect for a *mechanism*, not a bug: only 2 of ~9 round-3 fixes shipped a runnable proof test. Round 5 fixed all 24 actionable findings across disjoint builders (README `--throwaway`→`--no-sign`; the three-round `architecture.md` install-flow paragraph finally replaced; onboard TTY, heartbeat comment, ambient lock; and **the live proofs the adversaries produced were codified into seven fast-tier tests + a doc-drift guard + a verbatim-README smoke leg**). Round 6 re-ran the two NO-SHIP adversaries: the Stranger's recipe now installs `openjawz-meta` clean (no signature death), the Architect's seven tests run green and the docs guard bites. Zero NO-SHIP, zero open must-fix.

## What the rounds found (canonical, deduplicated)

- **Round 1:** ~90 raw findings → 40 canonical. A third of them were one root cause — a placeholder trust root — wearing six masks. The rest split into "the docs still describe the design the plan overruled" and "nobody ran the failure branch" (`openjawz update` deadlocked on its own lock on every real terminal; `doctor` printed nothing with the daemon down).
- **Two privacy failures, both the maintainer's, both found by the Auditor:** the guard's list of forbidden private words was itself committed to the public tree (round 1); its replacement — unsalted SHA-256 of each word — was a dictionary oracle that gave up the forbidden names in milliseconds (round 2). The list is now HMAC-SHA256 under a key that is not in the repo; history was rewritten both times and verified clean from fresh clones.
- **Round 2's number:** 33 fixes were dispatched with a named proof test each. **15 shipped with the test. All 14 REPEAT findings were in the 18 without one. Zero in the 15 with one.** The playbook now requires the test run to be pasted before an id is called fixed.
- **Rounds 4–6 (the verify-and-close):** round 4 proved round-3's hand-applied fixes actually held (the Packager and Operator installed a real build in an isolated container and watched the deadlock, the `.db.sig` poison, and the alpm-sandbox read all behave). It also caught the one thing reading can't: a recipe never run end-to-end (`--throwaway` vs `--no-sign`) and ~7 fixes with no test. Round 5 closed all 24 actionable findings and, crucially, **turned the adversaries' live proofs into seven committed fast-tier tests + a doc-drift guard that bites + a verbatim-README smoke leg** — so "reading isn't proof" is now enforced by CI, not by the reviewer's memory. Round 6 re-ran the two hold-outs and both flipped.
- **Hooks as a governed ingress:** the content filter for OS events (OTPs, tokens, password-manager prompts) shipped in round 1's fix and **failed open** on a malformed pattern (round 2). It fails closed now, with a test.

## Residue (open at this tag)

- **Prerequisites (maintainer, not code):** the public install path is not live — it needs a runtime prerelease, a brain release, and a real signing key (`docs/status.md`). Until then `synaps-bin` ships a `0.9.0` binary under a `0.9.1rc1` pin (the version cross-check warns, non-fatal, and flips to fail-closed once the real release lands), and the signed-repo install leg stays unwritten.
- **Container test legs need a real runner:** install-smoke / uninstall-clean / the verbatim-README leg boot systemd as PID 1, which needs `--privileged` — forbidden after the GPU incident below. They are proven at the pacman level in a non-privileged, udev-masked, blood-rule container (build → `pacman -Sy` → `openjawz-meta` installed, verified live); the user-session stages (attach line, live `Upholds=` re-ensure, reboot enablement) are verified by code + static analysis and want a maintainer VM to exercise end-to-end.
- Minor latent hardening kept as declared LOW: uninstall `realpath` containment (added), the ambient-ensure lock (added), `manifest`/env-path `rm` guards (added) — closed in round 5; anything still open is noted inline in `docs/status.md`.

## Incidents

Two, on the maintainer's machines, during round-0 testing: an install-smoke container run `--privileged` with the host's cgroup namespace re-triggered the host's GPU devices and killed a laptop panel twice while it was in use. The test driver now uses a private cgroup namespace with udev masked in the image, checks the host's `/dev/dri` timestamps and journal before and after, and never runs on a machine someone is sitting at. Recorded here because a product that tests itself has to say what its tests did.
