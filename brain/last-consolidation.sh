#!/usr/bin/env bash
# last-consolidation.sh — when did the brain last consolidate? (used by `openjawz brain status` and doctor)
BRAIN="${AXEL_BRAIN:-${XDG_CONFIG_HOME:-$HOME/.config}/axel/${AGENT_NAME:-axel}.r8}"
[ -f "$BRAIN" ] || { echo "no brain at $BRAIN"; exit 1; }
command -v sqlite3 >/dev/null || { echo "sqlite3 not installed"; exit 77; }
sqlite3 "$BRAIN" "SELECT printf('Run #%d — %s — %.1fs | reindex: %d | strengthen: ↑%d ↓%d | prune: %d removed, %d flagged',
    id, substr(started_at, 1, 19), duration_secs, phase1_reindexed, phase2_boosted, phase2_decayed, phase4_removed, phase4_flagged)
  FROM consolidation_log ORDER BY id DESC LIMIT 1" 2>/dev/null || echo "never consolidated"
