# Memory policy

What the brain keeps, what it never keeps, and who sees what. This file is the contract; `openjawz brain init`
applies the defaults; the extractor role and the consolidation pass enforce it.

## Where
One brain per user: `$XDG_CONFIG_HOME/axel/<agent>.r8` (one SQLite file + an `.hnsw` sidecar).
**Single writer** — the daemon's axel extension. Every session reads. Never two daemons on one brain.
Backups: `openjawz brain backup` (tarball, keep 3), taken before every `openjawz update` and every migration.
No `.r8`, `.hnsw` or `.db` file ever enters a git repository (`.gitignore` ships the rule).

## Categories
| category | what goes in |
|---|---|
| `events` | decisions, milestones, insights, state transitions — as described (default) |
| `preferences` | the user's stated behavioural patterns, workflow choices, interaction preferences |
| `entities` | people, projects, concepts with documented relationships |
| `cases` | problem → solution pairs, debugging patterns, technical learnings with actual detail |
| `patterns` | reusable processes and workflows — documented, not inferred |

## Provenance
Every memory carries: source (session id or file), created, confidence (`high|medium|low`), importance (0–1),
optional TTL, and an HMAC signature.
- Extraction is **source-grounded**: quote the source; never infer; thin source ⇒ `confidence: low`.
- **Staging gate**: extracted memories land in `staged_memories`; they are promoted by the orchestrator at shutdown
  or by review. Rejected ones are kept (`rejected/`) for audit and are never indexed.
- Signatures are checked on read. `TAMPERED` memories are excluded from injection and flagged in `axel_verify`.

## Sensitivity
Every memory and every indexed document gets a level. **Default for unknown = `private`.**

| level | meaning | injected into |
|---|---|---|
| `public` | fine in any context (default for `notes/`) | every session, every subagent |
| `private` | personal | the user's own sessions only — never a subagent's context |
| `work` | a named employer/client scope | only sessions that declare that scope |
| `secret` | credentials, tokens, keys, private addresses, health/financial identifiers | **never stored** |

Subagents receive `public` + the declared `work` scope only. The memory mode chosen at onboarding
(`everything except secrets` / `work only` / `ask each session`) sets the default level the extractor assigns.

## Never stored
Anything matching `brain/secret-patterns.txt` — the **same list the repo's grep-guard uses** (`tests/grep-guard/secrets.txt`) —
is dropped at extract time **and** at index time, and a scrub pass runs in consolidation phase 4.
If a secret is found in an already-stored memory it is deleted, not redacted, and the deletion is logged.

Ambient injection has a **relevance floor: 0.30**. Below it nothing is injected — a low-scoring hit is noise at best and
a leak at worst.

## Retention
- TTL is optional per memory; expired memories are pruned by consolidation.
- Consolidation (every 6 h, `axel-consolidate.timer`): reindex changed files → strengthen accessed documents, decay unused
  ones (exponential) → reorganise graph edges → prune. Low-priority sources auto-prune; high-priority ones flag for review.
- `openjawz brain status` shows the last consolidation run.

## Sources
`sources.toml` default: `notes` (high), `context` (high), `skills` (high). Users add their own.
Symlinked vaults are the user's choice and default to `private`. A source can be marked `index = false` to be
searchable by path but never embedded.
