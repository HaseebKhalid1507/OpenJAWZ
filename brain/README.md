# brain/

Memory. One `.r8` per user, one writer (the daemon's axel extension), every session reads.

| file | what |
|---|---|
| `memory-policy.md` | the contract: categories, provenance, **sensitivity levels** (`public/private/work/secret`), what is never stored, the 0.30 injection floor, retention |
| `secret-patterns.txt` | → `tests/grep-guard/secrets.txt` — one list for the repo guard, the extractor and the consolidation scrub |
| `sources.toml.default` | what gets indexed: `notes`, `context`, `skills` — rendered into `$XDG_CONFIG_HOME/axel/sources.toml` |
| `axel.default` | the extension's settings (`~/.synaps-cli/axel.toml`): budget, top-k, `injection_min_score = 0.30`, default sensitivity |
| `axel-consolidate.{service,timer}` | every 6 h: reindex → strengthen → reorganize → prune → secret scrub |
| `last-consolidation.sh` | one sqlite line: when it last ran and what it did |
| `init.sh` | → `openjawz brain init` |

Verb: `openjawz brain init | status | backup [--quick] | consolidate` (`bin/openjawz-brain`).
`init` exits 2 ("skipped") when `axel` is not on PATH — the install stage turns that into a yellow line, nothing breaks.

Honest note: the shipped `axel.default` declares `injection_min_score` and `default_sensitivity`; the axel release that
reads them is the one pinned by `packages/axel-bin` (older local builds ignore unknown keys). `docs/brain.md` has the details.
