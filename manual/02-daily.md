# 2 · Daily use

The loop is: boot → work (checkpoint every ~10 exchanges) → shutdown. Everything else is a tool.

## The session
```bash
synaps --attach                 # the TUI attached to the daemon (--new: fresh session). Bare `synaps` runs the engine in-process — not what you want here
synaps attach --create          # the line client, same daemon, for scripts and non-TTY shells
openjawz boot                   # the agent runs this; you can too — Identity → Work → World
openjawz checkpoint "…"         # every ~10 exchanges; --append for concurrent sessions; --clear
openjawz shutdown               # the 7-step checklist, verified first, written last; refuses if the brief/handoff/journal are missing
openjawz shutdown --no-handoff  # nothing in flight
```
What the agent writes and where:

| file | what | who writes |
|---|---|---|
| `context/active/session-brief.md` | this session: Summary · Tasks Changed · Projects Updated · People · Key Decisions · Tools Built | the agent, at the end |
| `context/active/handoff.md` | multi-session work state — enough to resume cold | the agent, on progress |
| `context/active/checkpoint.md` | crash protection | `openjawz checkpoint` |
| `context/active/sessions_recent.md` · `context/full/sessions_full.md` | last 3 · all | `openjawz sessions` only |
| `notes/journal/YYYY-MM-DD.md` | observations, not logs | the agent |
| `data/tasks.json` · `tasks_history.json` | tasks | `openjawz tasks` / the synaps-tasks plugin |

All of these are **sacred**: subagents never write them, destructive tests run on a `/tmp` copy, `shutdown` ends with an `ls`.

## Tasks
```bash
openjawz tasks add "Fix the build" -p high -c work --deadline 2026-09-12
openjawz tasks list | today | due | search "build" | history
openjawz tasks done 3 | update 3 --status in-progress | subtask 3 "write the test"
```
Same `tasks.json` the agent's native task tools use (`synaps-tasks` plugin) — edit from either side.

## Sessions and transcripts
```bash
openjawz sessions recent 5 | list | get S12 | search "daemon" | next
openjawz transcript list                      # every stored session: date, messages, cost, title
openjawz transcript show <id> | search "q"     # the dialogue only — no tool calls, no thinking
```

## The crew
Ask for something substantial and the agent delegates: `subagent(agent: "implementer", task: "…")`.
Playbooks in `/usr/share/openjawz/crew/playbooks/` are the fixed patterns — say "deep research on X",
"review this", "debug this", "security audit ./project", "quick recon on Y", "build feature Z" and the agent loads the
matching one. Parallel phases coordinate through `openjawz comms` (a local SQLite board):
```bash
openjawz comms channels | read <channel> | unread
```

## The brain
```bash
openjawz brain status           # size, documents, memories, last consolidation
openjawz brain backup           # tarball → ~/.local/state/openjawz/brain-backups/ (keeps 3); update does this for you
openjawz brain consolidate      # what the 6 h timer runs; ends with `brain scan`
openjawz brain scan             # secret-pattern scan of stored memories: hits are deleted and logged
```
> **Yellow until the axel release (P-R2) exists.** If `axel` is not installed every line above prints "absent" and
> exits 2 — nothing else depends on it. The local axel build in hand has no `consolidate`/`extract` and ignores
> `axel.toml`, so `consolidate` degrades to a reindex and the 0.30 injection floor is not enforced yet. What *is*
> enforced today: `brain scan` — the same pattern list that guards this repo (`brain/secret-patterns.txt`) runs
> against stored memories, matching rows are deleted and logged to `~/.local/state/openjawz/brain-scrub.log`.

The agent searches before it answers ("search before you speak" is rule 9 in its SOUL).

## Tool stats
```bash
openjawz toolstats stats | top | failures | tool tasks
```
Local SQLite, no network, records tool name / duration / exit code / caller. Opt out: `OPENJAWZ_NO_TRACK=1`.

## Where things live
```
~/.config/openjawz/identity.env     your answers (0600)          ~/.config/openjawz/profile.env   the machine profile
$OPENJAWZ_HOME  (~/.local/share/openjawz)   SOUL.md OP.md AGENTS.md  data/  context/  notes/  workspace/
~/.synaps-cli/                      config  system.md  subagent-preamble.md  agents/  skills/  plugins/  axel.toml
~/.config/axel/<agent>.r8           the brain (+ .hnsw)          ~/.local/state/openjawz/          logs, markers, backups
```
Change an answer: edit `identity.env` (or re-run `openjawz onboard`), then `openjawz onboard` renders and reloads.

## When something is off
```bash
openjawz doctor
tail -50 ~/.local/state/openjawz/openjawz.log
openjawz boot --quiet           # is there an UNCLEAN SHUTDOWN block?
```
