---
name: shutdown-checklist
description: The 7 steps that end every session, verified by `openjawz shutdown` — light session or heavy, all 7.
---
# Shutdown checklist

Before the last message of a session:

1. **Session brief** — write `context/active/session-brief.md`:
   `# Session Brief — S<N> (date)` · `## Summary` · `## Tasks Changed` · `## Projects Updated` · `## People` ·
   `## Key Decisions` · `## Tools Built`. Overwrite each session. You lived it; you summarise it.
2. **Session log** — done for you by `openjawz shutdown` (`sessions add`, number auto, summary from `## Summary`).
3. **Handoff** — update `context/active/handoff.md` (see the `handoff` skill) or pass `--no-handoff`.
4. **Checkpoint** — cleared for you.
5. **Journal** — `notes/journal/YYYY-MM-DD.md`: observations, lessons, what mattered and why. Not a log.
6. **Context files** — `projects_active.md`, `people.md`, `projects_full.md` if anything changed
   (dispatch `context-updater` with the brief; it searches before it edits).
7. **Post-op verification** — done for you: `ls` of the sacred files.

Then:
```bash
openjawz shutdown                    # verifies 1/3/5, performs 2/4/7, then brain extract + handoff store + backup
openjawz shutdown --no-handoff       # nothing in flight
openjawz shutdown --dry-run          # see what would be refused
```
It **refuses** (exit 1) if the brief, the handoff or the journal is missing — write them and run it again.
The daemon's session-end hook runs `openjawz shutdown --auto`, which never refuses but marks the checkpoint
**UNCLEAN** so the next boot knows.
