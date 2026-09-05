# Crew — roles, not characters

`crew/roles/` ships 14 files. Each is a **role**: frontmatter (`name`, `description`, `tools`, `model: {{MODEL}}`,
optional `thinking`) → the SUBAGENT block ("not the orchestrator; do not delegate") → *Your specialty* → *How you work*
→ *Output style* → a `## Tools` footer (`axel search` first, workspace, sacred files, preamble). No personality.

| role | tools | for |
|---|---|---|
| planner | read, bash | specs, schemas, interfaces; designs, doesn't build |
| implementer | read, bash, edit, write | general execution |
| reviewer | read, bash (thinking: high) | read-only critique, severity-ranked, verdict |
| tester | read, bash, edit, write | writes and *runs* tests; reports what is uncovered |
| debugger | read, bash, edit, write | hypothesis → evidence → root cause → proof |
| researcher | read, bash (thinking: high) | deep survey; the Recon Output Format |
| sysadmin | read, bash, edit, write (thinking: high) | shell, systemd, packaging, permissions |
| optimizer | read, bash, edit, write (thinking: high) | the real bottleneck; before/after |
| archivist | read, bash, edit, write | what IS vs SHOULD BE; diffs; rollback paths |
| pentester | read, bash, edit, write | authorised targets only; demonstrated vs suspected |
| writer | read, bash, edit, write | docs, copy; every claim paired with a command |
| heavy | read, bash, edit, write | big rewrites; explains as it goes |
| context-updater | read, bash, edit, write | shutdown step 6: search → read → diff → apply |
| extractor | read | pure function: brief → source-grounded JSON memories with a sensitivity level |

Install: `openjawz crew install` (copies where absent, resolves `{{MODEL}}` from `identity.env`);
`refresh` updates only files you have not edited; `list` shows state.

## Flavors
`crew/flavors/` is **empty in v0.1** by design. A flavor is ≤ 15 lines of voice, concatenated at dispatch, never merged;
it never adds tools, rules, paths or authority. No franchise characters ship — anything added must be an original archetype.

## Playbooks (`crew/playbooks/`)
Fixed orchestration patterns the agent loads when a request matches a trigger phrase:
`build-feature` (spec → parallel review → refine/implement/test → security+quality → final review) · `code-review` ·
`debug` · `deep-research` ("every research task connects back to us") · `quick-recon` · `security-audit` ·
`auto-research` · `orchestration` (the consolidated reference) · `gauntlet` (N adversaries in rounds until a clean
round). `README.md` is the format spec. There is no playbook CLI in v0.1; the orchestrator reads the file.

## Comms (`crew/tools/comms`)
Parallel phases with 3+ agents coordinate through a local SQLite board (`$OPENJAWZ_DATA/comms.db`):
`openjawz comms post <channel> <from> "msg" [--to role] [--type finding|question|answer|alert]`, `read`, `unread`,
`channels`, `archive`. Nothing leaves the machine.
