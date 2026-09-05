# 1 · First run

You installed OpenJAWZ (`openjawz install` ran, or `boot` did it for you). This page is the first hour.
Every claim has a command next to it. If a command does not do what this page says, that is a bug — file it.

## 1. Who is this agent?

```bash
openjawz onboard
```
Nine prompts — seven identity questions, then memory policy and model — under a minute, every one with a default. Nothing here asks for an API key.

| # | question | lands in |
|---|---|---|
| 1 | What do you want to call the agent? | `AGENT_NAME` |
| 2 | What should it call you? | `USER_NAME` |
| 3 | In one line: what do you do? | `USER_DOES` |
| 4 | How should it talk to you? (pick, or write your own sentence) | `VOICE` |
| 5 | What should it push back on? | `PUSHBACK` |
| 6 | What should it never do? | `NEVER` |
| 7 | Where is this machine in the spectrum? (desktop / laptop / deck / vm — pre-selected) | `PROFILE` |
| 8 | Memory policy: everything except secrets / work only / ask each session | `MEMORY_MODE` |
| 9 | Model (`provider/model`) | `MODEL` |

Answers go to `~/.config/openjawz/identity.env` (mode 0600). From them the templates are rendered:

```
$OPENJAWZ_HOME/SOUL.md          who the agent is        (from ops/templates/SOUL.md.template)
$OPENJAWZ_HOME/OP.md            how it operates          (OP.md.template)
$OPENJAWZ_HOME/AGENTS.md        the crew table, no identity
~/.synaps-cli/system.md         the session system prompt
~/.synaps-cli/subagent-preamble.md   8 lines prepended to every subagent
~/.synaps-cli/config            identity= agent_name= model=   (three lines; nothing else is touched)
```
Check: `grep -c '{{' $OPENJAWZ_HOME/SOUL.md` prints `0`. Re-run `openjawz onboard` any time; previous answers are the
defaults. `openjawz onboard --yes` takes every default (CI, SSH, scripts). `--force` starts from scratch.

The daemon caches the identity line, so onboarding ends with `synaps daemon reload`. If the daemon was not running,
the identity loads on its next start.

## 2. Credentials

Not an onboarding question, on purpose.
```bash
synaps login                    # OAuth picker; credentials → ~/.synaps-cli/auth.json (0600, the daemon's)
# or: export ANTHROPIC_API_KEY=…  in ~/.config/openjawz/env (0600) — never in identity.env, never in the repo
```

## 3. The crew

```bash
openjawz crew install           # 14 role files → ~/.synaps-cli/agents/<role>.md
openjawz crew list
```
planner · implementer · reviewer · tester · debugger · researcher · sysadmin · optimizer · archivist · pentester · writer ·
heavy · context-updater · extractor. Roles carry method and output format — no personality. Your agent's voice is yours
(question 4); subagents get none. `crew/flavors/` is empty by design.

Edited a role file? `openjawz crew refresh` keeps your edits and updates only untouched ones.

## 4. The brain

```bash
openjawz brain init             # fresh ~/.config/axel/<AGENT_NAME>.r8, sources.toml, axel.toml, first handoff, 6 h timer
openjawz brain status
```
If `axel` is not installed this prints a yellow "absent" line and exits 2. Nothing else depends on it.
What it keeps and what it never keeps: `/usr/share/openjawz/brain/memory-policy.md` (4 · Brain).

## 5. First session

```bash
synaps --attach                 # the TUI, attached to the daemon; the system prompt is your rendered SOUL
```
The agent's first move is `openjawz boot` (its OP.md tells it so). You will see: Identity → Work → World.
On a fresh install that is: no journal yet, "No active handoff.", no tasks, no sessions.

Say something. Then, before you leave: the agent runs `openjawz shutdown`. If it did not write the session brief,
the handoff and a journal entry, `shutdown` refuses and prints what is missing. That is the discipline, enforced.

## 6. Check the install

```bash
openjawz doctor                 # green / yellow / red table
```
Yellow is fine on a first run: brain absent (no axel), no ambient session yet, `graphical-session.target` inactive when a display is present but the target hasn't started (over SSH the whole row is absent — `doctor` only checks it when `WAYLAND_DISPLAY`/`DISPLAY` is set).
Red means stop and read the line.

Next: [02-daily.md](02-daily.md).
