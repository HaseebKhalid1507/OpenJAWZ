# Brain — memory with a policy

One `.r8` per user at `$XDG_CONFIG_HOME/axel/<AGENT_NAME>.r8`. Every session reads. It never enters a repo.

**Two axel processes, one brain file.** The MCP server (`mcp.json.default`, `axel mcp`, `shared: true`) serves tool
calls (`search`/`remember`/`recall`); the extension (`plugins/axel`, `axel extension`, `shared: true`) does session-end
extraction. Both open the same `.r8`; SQLite serialises the writes. "One writer" means **one brain file, no second
engine** — not one process. `openjawz brain init` adds the MCP entry to `~/.synaps-cli/mcp.json` when it is absent
(merge, never overwrite); the extension is symlinked by `openjawz install` like every other plugin.

## Lifecycle
```bash
openjawz brain init          # axel init --name; sources.toml + axel.toml from defaults; mcp.json axel entry; index notes/ context/; first handoff; 6 h timer
openjawz brain status        # path, size, axel stats, last consolidation, backup count
openjawz brain backup        # sqlite .backup → tar.zst (0600) in ~/.local/state/openjawz/brain-backups (keep 3); --quick = plain tar
openjawz brain consolidate   # reindex → strengthen → reorganize → prune, then `brain scan`
openjawz brain scan          # secret scan: every pattern in secret-patterns.txt against stored memories; hits are DELETED and logged
openjawz brain purge [--yes] # remove the .r8 (+ .hnsw, sources.toml) after asking — what `openjawz uninstall --purge` calls
```
`scan` runs the patterns through python's `sqlite3` module with a `REGEXP` function (the `sqlite3` CLI has none);
a hit is deleted with `axel forget` when this axel has it, otherwise with a plain `DELETE`, and one line per row
(`timestamp id pattern-N deleted`) goes to `~/.local/state/openjawz/brain-scrub.log` (0600). `tests/brain` plants a
token and proves the row goes. Refusal at **extract** time is an axel PR (`docs/status.md`); until it lands the scan is
the enforcement.
`init` exits 2 when `axel` is absent; `openjawz install` shows that as yellow and continues. `openjawz update` and every
migration run `backup` first.

## The policy (`brain/memory-policy.md`) — the short version
- **Categories:** events · preferences · entities · cases · patterns.
- **Provenance:** source, created, confidence, importance, TTL, HMAC signature. Extraction is source-grounded
  (quote it or drop it); extracted memories are **staged**, promoted at shutdown or by review; rejected ones are kept for audit.
- **Sensitivity:** `public` / `private` (default) / `work` / `secret`. Subagents see `public` + the declared `work`
  scope. `secret` is **never stored**.
- **Never stored:** anything matching `brain/secret-patterns.txt` — a symlink to `tests/grep-guard/secrets.txt`, so the
  repo guard, the extractor role and `brain scan` share one list.
- **Injection floor 0.30:** below it nothing is injected.
- **Retention:** optional TTL; unused documents decay, accessed ones strengthen; low-priority sources auto-prune.

## Files
`sources.toml.default` (notes, context, skills — high priority, sensitivity per source) · `axel.default`
(`~/.synaps-cli/axel.toml`: `injection_budget`, `injection_top_k`, `injection_min_score = 0.30`, `auto_extract`,
`default_sensitivity`, `secret_patterns`) · `axel-consolidate.{service,timer}` · `last-consolidation.sh`.

## Honest status
The policy is the contract; enforcement is split. Today the shipped `openjawz-brain` implements init/status/backup/purge,
consolidation (a reindex when this axel has no `consolidate`) and the secret **scan** (deletes + logs — proven by
`tests/brain`); the extractor *role* refuses secrets and tags sensitivity, the axel binary does not yet. The
`injection_min_score`, `default_sensitivity` and `secret_patterns` keys in `axel.toml` **will be read by the axel release
once P-R2 lands; the local build in hand ignores them** and has no floor. `openjawz doctor` reports the brain as *absent*
until that release exists (plan D7).
