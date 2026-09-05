#!/usr/bin/env bash
# ci: fast
# migrate: the runner against a temp SHARE/STATE — runs once, second run prints none, failure keeps .running and
#          refuses until --skip/--force, two concurrent runners touch the file exactly once, migrate takes a lock.
set -uo pipefail
cd "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)" || exit 1
fail=0; ok() { echo "  ok   $*"; }; bad() { echo "  FAIL $*"; fail=1; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export OPENJAWZ_LIB="$PWD/lib" OPENJAWZ_SHARE="$T/share" OPENJAWZ_STATE="$T/state" OPENJAWZ_CONFIG="$T/cfg" \
       OPENJAWZ_HOME="$T/home" OPENJAWZ_RUN="$T/run" SYNAPS_BASE_DIR="$T/sb" OPENJAWZ_YES=1 HOME="$T/h"
mkdir -p "$OPENJAWZ_SHARE/migrations" "$HOME" "$T/bin"
# a router that finds our bin/ (migrate calls `openjawz help brain`)
printf '#!/usr/bin/env bash\nexec "%s/bin/openjawz" "$@"\n' "$PWD" > "$T/bin/openjawz"; chmod +x "$T/bin/openjawz"
export PATH="$T/bin:$PATH"
M() { "$PWD/bin/openjawz-migrate" "$@"; }

cat > "$OPENJAWZ_SHARE/migrations/1-user-touch.sh" <<'EOF'
#!/usr/bin/env bash
# openjawz-migration: touch a file, count the runs
# scope: user
set -euo pipefail
. "${OPENJAWZ_LIB:-/usr/lib/openjawz}/openjawz.sh"
oj::paths
sleep 0.3
echo run >> "$OPENJAWZ_STATE/touched"
EOF

# 1. the shipped migration sources the lib through OPENJAWZ_LIB (no hardcoded /usr/lib)
for m in migrations/[0-9]*-*.sh migrations/TEMPLATE.sh; do
  grep -q 'OPENJAWZ_LIB:-/usr/lib/openjawz' "$m" && ok "$m sources \${OPENJAWZ_LIB}" || bad "$m hardcodes the lib path"
done
grep -q '^Target = usr/share/openjawz/migrations/\[0-9\]\*-\*\.sh' packages/openjawz/95-openjawz-migrations.hook && ok "hook glob skips TEMPLATE.sh" || bad "hook Target matches TEMPLATE.sh"
grep -q 'oj::lock migrate' bin/openjawz-migrate && ok "runner takes oj::lock migrate" || bad "runner has no lock"

# 2. run twice: once applied, marker present, no .running, second run prints none
out="$(M 2>&1)"; rc=$?
[ "$rc" = 0 ] && echo "$out" | grep -q 'migrated 1-user-touch.sh' && ok "first run applied 1-user-touch.sh" || bad "first run rc=$rc: $out"
[ -e "$OPENJAWZ_STATE/migrations/1-user-touch.sh" ] && ok "marker present" || bad "no marker"
compgen -G "$OPENJAWZ_STATE/migrations/*.running" >/dev/null && bad ".running left behind" || ok "no .running"
[ "$(M 2>/dev/null)" = none ] && ok "second run → none" || bad "second run did not print none"
[ "$(M --pending)" = none ] && ok "--pending → none" || bad "--pending not none"
[ "$(grep -c run "$OPENJAWZ_STATE/touched")" = 1 ] && ok "ran exactly once" || bad "ran $(grep -c run "$OPENJAWZ_STATE/touched") times"

# 3. a failing migration keeps .running; the next run refuses; --skip clears it
cat > "$OPENJAWZ_SHARE/migrations/2-user-fail.sh" <<'EOF'
#!/usr/bin/env bash
# openjawz-migration: always fails
# scope: user
set -euo pipefail
exit 1
EOF
M >/dev/null 2>&1; rc=$?
[ "$rc" != 0 ] && ok "failing migration → rc=$rc" || bad "failing migration returned 0"
[ -e "$OPENJAWZ_STATE/migrations/2-user-fail.sh.running" ] && ok ".running kept after failure" || bad ".running missing after failure"
M >/dev/null 2>&1; rc=$?
[ "$rc" != 0 ] && ok "next run refuses (rc=$rc) while dirty" || bad "runner ignored the dirty flag"
M --skip 2-user-fail.sh >/dev/null 2>&1 && ok "--skip accepted" || bad "--skip failed"
[ ! -e "$OPENJAWZ_STATE/migrations/2-user-fail.sh.running" ] && [ -e "$OPENJAWZ_STATE/migrations/2-user-fail.sh" ] && ok "--skip cleared .running" || bad "--skip left .running"
[ "$(M 2>/dev/null)" = none ] && ok "clean again → none" || bad "not clean after --skip"

# 4. two concurrent runners: one wins the lock, the file is touched exactly once
cp "$OPENJAWZ_SHARE/migrations/1-user-touch.sh" "$OPENJAWZ_SHARE/migrations/3-user-touch.sh"
: > "$OPENJAWZ_STATE/touched"
M >/dev/null 2>&1 & M >/dev/null 2>&1 & wait
[ "$(grep -c run "$OPENJAWZ_STATE/touched")" = 1 ] && ok "two concurrent runners → touched once" || bad "concurrent runners touched $(grep -c run "$OPENJAWZ_STATE/touched") times"
compgen -G "$OPENJAWZ_STATE/migrations/*.running" >/dev/null && bad ".running after the race" || ok "no .running after the race"

# 5. read-only modes work while the lock is held
exec 9>"$OPENJAWZ_RUN/migrate.lock"; flock 9
M --pending >/dev/null 2>&1 && ok "--pending needs no lock" || bad "--pending blocked by the lock"
M --list >/dev/null 2>&1 && ok "--list needs no lock" || bad "--list blocked by the lock"
exec 9>&-

[ "$fail" = 0 ] && echo "migrate: ok"
exit "$fail"
