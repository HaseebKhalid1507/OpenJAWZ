# Identity — how the agent gets a self without carrying anyone else's

OpenJAWZ ships **templates**, never a person. The runtime reads identity from four places; `openjawz onboard` fills all four
from one file of answers.

## The answers: `~/.config/openjawz/identity.env` (0600)
```
AGENT_NAME USER_NAME USER_DOES VOICE PUSHBACK NEVER PROFILE MEMORY_MODE BUILD_RULE OPENJAWZ_HOME MODEL
```
These are the **only** placeholders any template may use (`tests/templates` enforces it). No secrets: credentials are
`synaps login` / `~/.config/openjawz/env`.

## Where each rendered file lands and who reads it

| template (`ops/templates/`) | rendered to | read by |
|---|---|---|
| `SOUL.md.template` | `$OPENJAWZ_HOME/SOUL.md` | the main agent at boot (with OP.md, via `--system`) |
| `system.md.template` | `~/.synaps-cli/system.md` | the runtime's default session system prompt (`resolve_system_prompt`) |
| — (one line from SOUL "Who am I") | `identity = …` in `~/.synaps-cli/config` | the prompt-cache-stable preamble; **cached process-wide** → `synaps daemon reload` |
| `OP.md.template` | `$OPENJAWZ_HOME/OP.md` | the main agent; the operating manual |
| `AGENTS.md.template` | `$OPENJAWZ_HOME/AGENTS.md` | humans and subagents — the crew table, **no identity** |
| `ops/subagent-preamble.md` | `~/.synaps-cli/subagent-preamble.md` | **prepended to every subagent prompt** by the runtime |
| `crew/roles/*.md` | `~/.synaps-cli/agents/<role>.md` | the `subagent` tool, by name |

## The agent-bleed rule
The main agent's identity travels **only** via `--system` (SOUL + OP) and the `identity=` line. It is never put into
AGENTS.md or the preamble, because those are read by subagents — and a subagent that thinks it is the orchestrator
delegates, speaks in the wrong voice, or touches sacred files. The preamble is 8 lines of ops: *you are a subagent, you do
not delegate, you are not {{AGENT_NAME}}, scratch goes here, sacred files are read-only, search first, build rule, report
format.*

## SOUL — what is fixed and what is yours
The SOUL template keeps ten rules. Eight are the product's stance and read the same for everyone (be real, read the
room, own mistakes, no yapping, look after the user, delegate substantial / do trivial, notify after agent work, search
before you speak). Two carry your words: **push back** (`PUSHBACK`) and **never** (`NEVER`). The **voice** is one
sentence of yours. That is the whole personality surface — deliberately small.

## Changing it
Edit `identity.env` or re-run `openjawz onboard` (previous answers are the defaults; `--force` resets). Rendering is
idempotent: `config` gets three keys replaced in place, nothing else is touched. Hand-edits to `SOUL.md`/`OP.md` survive
until the next `onboard` — they are sacred files, so agents never write them; you can.
