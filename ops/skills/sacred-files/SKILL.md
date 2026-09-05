---
name: sacred-files
description: The blast-radius rule — files agents never write directly, and how to test destructive operations.
---
# Sacred files

Listed in `/usr/share/openjawz/ops/sacred-files.md` (rendered with the user's paths):
`SOUL.md`, `OP.md`, `data/tasks.json`, `data/tasks_history.json`, `context/**`, `~/.synaps-cli/config`,
`~/.synaps-cli/system.md`, `~/.synaps-cli/subagent-preamble.md`, the `.r8` brain.

**Blast-radius rule** — before any destructive operation (`rm`, `rm -rf`, `mv`, `chmod`, DB writes):
1. Never test against the live `$OPENJAWZ_HOME/data/` — copy to `/tmp` first.
2. Sandbox destructive tests on the copy.
3. Sacred files are changed only through their tools (`openjawz tasks`, `openjawz sessions`, `openjawz checkpoint`)
   or by the orchestrator with `edit` — never by a subagent, never by a script that globs.
4. Post-op verification: `ls` the sacred files. Confirm nothing got nuked.

Why: an agent stress test once deleted an entire data directory. The backup was 18 hours stale because the timer only
fired on boot. Recovered, barely. Every destructive op gets a sandbox. No exceptions.

Subagents: the preamble makes these read-only to you. If a task requires changing one, stop and report — the
orchestrator does it.
