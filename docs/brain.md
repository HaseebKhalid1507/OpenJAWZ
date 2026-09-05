# Brain — memory with a policy

One `.r8` per user at `$XDG_CONFIG_HOME/axel/<AGENT_NAME>.r8`. One writer: the daemon's axel extension
(`mcp.json.default` marks it `shared`). Every session reads. It never enters a repo.

## Lifecycle
```bash
openjawz brain init          # axel init --name; sources.toml + axel.toml from defaults; index notes/ context/; first handoff; 6 h timer
openjawz brain status        # path, size, axel stats, last consolidation, backup count
openjawz brain backup        # sqlite .backup → tar.zst in ~/.local/state/openjawz/brain-backups (keep 3); --quick = plain tar
openjawz brain consolidate   # reindex → strengthen → reorganize → prune, then the secret scrub
```
`init` exits 2 when `axel` is absent; `openjawz install` shows that as yellow and continues. `openjawz update` and every
migration run `backup` first.

## The policy (`brain/memory-policy.md`) — the short version
- **Categories:** events · preferences · entities · cases · patterns.
- **Provenance:** source, created, confidence, importance, TTL, HMAC signature. Extraction is source-grounded
  (quote it or drop it); extracted memories are **staged**, promoted at shutdown or by review; rejected ones are kept for audit.
- **Sensitivity:** `public` / `private` (default) / `work` / `secret`. Subagents see `public` + the declared `work`
  scope. `secret` is **never stored**.
- **Never stored:** anything matching `brain/secret-patterns.txt` — a symlink to `tests/grep-guard/secrets.txt`, so the
  repo guard, the extractor and the consolidation scrub share one list.
- **Injection floor 0.30:** below it nothing is injected.
- **Retention:** optional TTL; unused documents decay, accessed ones strengthen; low-priority sources auto-prune.

## Files
`sources.toml.default` (notes, context, skills — high priority, sensitivity per source) · `axel.default`
(`~/.synaps-cli/axel.toml`: `injection_budget`, `injection_top_k`, `injection_min_score = 0.30`, `auto_extract`,
`default_sensitivity`, `secret_patterns`) · `axel-consolidate.{service,timer}` · `last-consolidation.sh`.

## Honest status
The policy is the contract; enforcement is split. Today the shipped `openjawz-brain` implements init/status/backup and
runs consolidation + a sqlite-side secret scan; the extractor role refuses secrets and tags sensitivity. The
`injection_min_score`, `default_sensitivity` and `secret_patterns` keys in `axel.toml` are read by the axel release
pinned in `packages/axel-bin` — an older local build ignores unknown keys and has no floor. `openjawz doctor` reports the
brain as *absent* until that release exists (plan D7).
