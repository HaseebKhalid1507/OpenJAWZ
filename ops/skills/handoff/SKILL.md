---
name: handoff
description: context/active/handoff.md — the multi-session scratchpad. Overwrite on progress, clear when done.
---
# Handoff

`$OPENJAWZ_HOME/context/active/handoff.md` is the one file the next session reads before anything else.
It is also stored in the brain at shutdown (`axel handoff set`) so `axel_recall` returns it.

- **Overwrite whenever progress is made.** Include enough to resume cold: what is done, what is next, exact paths,
  commands that worked, decisions and why.
- **Numbered items** survive better than prose. Roll unfinished items forward; delete finished ones.
- **Clear it** (`# Handoff` / `No active handoff.`) when no multi-session work is in flight. A stale handoff is worse
  than none — it sends the next session chasing ghosts.
- Concurrent sessions **append** a section with their session number; they never `cat >` over the file.
- Sensitive values (tokens, keys, private addresses) never go in the handoff — it is indexed by the brain.

`openjawz shutdown` refuses to finish unless the handoff was touched this session (or `--no-handoff` was passed
because nothing is in flight).
