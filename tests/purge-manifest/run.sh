#!/usr/bin/env bash
# ci: fast
# purge-manifest: `uninstall --purge` deletes only what install CREATED, never files that already existed under
#   ~/.synaps-cli (the user's own config, mcp.json). round-2 Architect: the -newer sweep recorded EDITED pre-existing
#   config → --purge would delete the user's file. round-3 fixed it with a .pre snapshot + `comm -23` (new-files-only).
#   The round-3 proof (tests/uninstall-clean) is container-tier and never runs in CI. This test lifts install's OWN
#   snapshot + comm pipeline verbatim and replays it against a fixture where a pre-existing config is later EDITED and
#   a new file is created — asserting the manifest excludes the pre-existing file and includes only the new one.
#   => the round-3 fix is now proven in the fast tier, not only in the (unrun) container.
set -uo pipefail
cd "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)" || exit 1
fail=0; ok() { echo "  ok   $*"; }; bad() { echo "  FAIL $*"; fail=1; }

# 0. the shipped install still uses the snapshot + comm mechanism (fail loudly if the fix regresses to raw -newer)
grep -q 'find "\$SYNAPS_BASE_DIR" -maxdepth 2 -type f .* > "\$manifest.pre"' bin/openjawz-install \
  && ok "install snapshots pre-existing files to \$manifest.pre" || bad "install no longer snapshots .pre — the new-files-only fix regressed"
grep -q 'comm -23 - "\$manifest.pre"' bin/openjawz-install \
  && ok "install filters the -newer sweep through comm -23 (new files only)" || bad "install no longer comm -23's against .pre — raw -newer would purge edited user files"

# 1. replay: build a fixture ~/.synaps-cli with a PRE-EXISTING config, snapshot, then EDIT it + CREATE a new file
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export SYNAPS_BASE_DIR="$T/synaps-cli" OPENJAWZ_STATE="$T/state"
mkdir -p "$SYNAPS_BASE_DIR" "$OPENJAWZ_STATE"
printf 'user = mine\n' > "$SYNAPS_BASE_DIR/config"        # a file the user already had
printf '{"pre":true}\n' > "$SYNAPS_BASE_DIR/mcp.json"     # ditto

manifest="$OPENJAWZ_STATE/installed-files"; touch "$manifest"; touch "$manifest.t0"
oj::record() { local p; for p in "$@"; do grep -qxF "$p" "$manifest" || printf '%s\n' "$p" >> "$manifest"; done; }  # ← install:40 verbatim
find "$SYNAPS_BASE_DIR" -maxdepth 2 -type f 2>/dev/null | sort > "$manifest.pre"                                    # ← install:39 verbatim

sleep 1.1                                                  # let mtimes cross $manifest.t0
echo "edited by install" >> "$SYNAPS_BASE_DIR/config"     # install EDITS the pre-existing config (round-2 trap)
printf 'created\n' > "$SYNAPS_BASE_DIR/system.md"         # install CREATES a brand-new file
oj::record "$SYNAPS_BASE_DIR/system.md"                   # (install records ones it wrote directly, like crew roles)

# ── the exact new-files-only pipeline shipped at install:134-135 ──
find "$SYNAPS_BASE_DIR" -maxdepth 2 \( -name '*.md' -o -name mcp.json -o -name config \) -newer "$manifest.t0" 2>/dev/null | sort \
  | comm -23 - "$manifest.pre" | while IFS= read -r p; do oj::record "$p"; done
rm -f "$manifest.pre" "$manifest.t0"

# 2. assertions: the manifest --purge reads must NOT contain pre-existing files, MUST contain the new one
grep -qxF "$SYNAPS_BASE_DIR/config" "$manifest" && bad "manifest contains the EDITED pre-existing config (would be purged!)" || ok "pre-existing config excluded (edited, but not created here → never purged)"
grep -qxF "$SYNAPS_BASE_DIR/mcp.json" "$manifest" && bad "manifest contains pre-existing mcp.json" || ok "pre-existing mcp.json excluded"
grep -qxF "$SYNAPS_BASE_DIR/system.md" "$manifest" && ok "newly-created system.md IS in the manifest (gets purged)" || bad "new file missing from manifest"
[ ! -e "$manifest.pre" ] && ok "the .pre snapshot is consumed (no residue)" || bad ".pre snapshot left behind"

[ "$fail" = 0 ] && echo "purge-manifest: ok"
exit "$fail"
