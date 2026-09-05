---
name: checkpoint
description: The ~10-exchange rule — write where you are so a crash costs minutes, not the session.
---
# Checkpoint

Every ~10 exchanges, or before anything risky, write the state you would need to resume cold:

```bash
openjawz checkpoint "S42: porting tools; batch 1 done (tasks, sessions); next: context tool; blocker: none"
printf '%s\n' "…multi-line…" | openjawz checkpoint
openjawz checkpoint --append "…"     # concurrent sessions sharing one engram: APPEND, never overwrite
openjawz checkpoint --clear          # at shutdown (openjawz shutdown does this for you)
```

Rules:
- One checkpoint per session, overwritten — it is crash protection, not a log. The journal is the log.
- If two sessions share one engram, `--append` only. Overwriting someone else's checkpoint is a data-loss bug.
- Content: what is done, what is next, what is blocked, which files are mid-edit. Enough to resume with zero memory.
- The boot briefing shows a non-cleared checkpoint as **UNCLEAN SHUTDOWN** — that is the point.
