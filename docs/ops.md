# Ops — the discipline

`ops/` is what makes an agent *operate* rather than chat: the boot/shutdown loop, the sacred-files rule, the templates,
the skills, and a small set of tools that are general enough to ship.

## Verbs (`bin/`, dispatched by the router)
| verb | what |
|---|---|
| `openjawz onboard [--yes] [--force] [--render-only]` | the identity form → `identity.env` → renders SOUL/OP/AGENTS/system/preamble → `config` keys → `synaps daemon reload` |
| `openjawz boot [--quiet] [--no-world]` | Identity → Work → World briefing; `boot.d/` sections run in parallel with an 8 s cap; brain not recalled (the extension injects) |
| `openjawz checkpoint [--append] [--clear] [text]` | `context/active/checkpoint.md` with a timestamp — the ~10-exchange rule has a tool |
| `openjawz shutdown [--auto] [--no-handoff] [--number N] [--dry-run]` | the **verifier**: refuses unless brief + handoff + journal exist this session; then sessions add, checkpoint clear, `ls`, brain extract/handoff, backup. `--auto` never refuses — marks UNCLEAN, exit 2 |
| `openjawz crew install\|refresh\|list` | roles → `~/.synaps-cli/agents/` |
| `openjawz brain init\|status\|backup\|consolidate` | see `docs/brain.md` |

"This session" for the verifier = files newer than the last successful shutdown (`~/.local/state/openjawz/last-shutdown`), or 12 h on a fresh install.

## Templates (`ops/templates/`) and the preamble
See `docs/identity.md`. Placeholders ⊆ the keys of `identity.env.template`.

## Sacred files (`ops/sacred-files.md`)
One path per line, placeholders allowed. Read by the preamble (subagents: read-only), the shutdown verifier (step 7),
`toolmake check` (batch 2), and the v0.2 `before_tool_call` guard. The rule and the reason: `ops/skills/sacred-files`.

## Skills (`ops/skills/<name>/SKILL.md`, loaded with `load_skill`)
v0.1 ships the five discipline skills — `boot-briefing`, `checkpoint`, `handoff`, `shutdown-checklist`, `sacred-files`.
The twelve lifted general skills (code-review, systematic-debugging, TDD, …) are v0.1.1.

## Tools (`ops/tools/`, installed as `/usr/lib/openjawz/tools/openjawz-<name>`)
Batch 1: `toolstats`, `tasks`, `sessions`, `context`, `transcript` (+ `crew/tools/comms`), and `lib/`:
`openjawz-track-lib` (bash), `openjawz_track.py`, `openjawz_paths.py`. Every tool: `#!/usr/bin/env`, `--help` exits 0,
honours `NO_COLOR`, stdlib only, paths from `OPENJAWZ_HOME`/`OPENJAWZ_DATA`, tracked by `toolstats` unless
`OPENJAWZ_NO_TRACK=1`. The user's name comes from `identity.env`, never a literal.
Batch 2 (`toolmake`, `tools-doc`, `maintain`, `backup`, `yt`, `web`, `tracker`) is v0.1.1; `shutdown` step 9 skips
cleanly while `backup` is absent.

## Plugins (`ops/plugins.list`)
What ships (axel, chronos, synaps-tasks, weather-lens, heartbeat-off) and what is a declared upstream dependency
(web-tools, tmux-tools) — never vendored.
