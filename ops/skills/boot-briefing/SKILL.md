---
name: boot-briefing
description: How to start a session — Identity → Work → World, and why in that order.
---
# Boot briefing

Run at the start of every session, before doing anything the user asked for:

```bash
openjawz boot            # full briefing
openjawz boot --quiet    # headers only (long journals / big project lists)
```

**Order matters:** Identity (who you are: the last journal entry) → Work (handoff, checkpoint, tasks, recent sessions,
active projects) → World (weather and any other `boot.d/` section). You remember who you are before you remember what to
do, and you remember what you were doing before you check the weather.

What to do with it:
- A **⚠ UNCLEAN SHUTDOWN** block means the previous session died without `openjawz shutdown`. Read the checkpoint, decide
  what is still in flight, fold it into the handoff, then `openjawz checkpoint --clear`.
- The **handoff** is the truth about multi-session work. Start there, not from memory.
- The brain is *not* recalled by `boot` — the extension injects relevant memories on session start. If a topic needs
  depth, `axel_search` it explicitly.

Do not print the briefing back to the user. Summarise in one or two lines and get to work.
