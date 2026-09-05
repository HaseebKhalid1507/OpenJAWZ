#!/usr/bin/env bash
# ci: hardware
# memprof gates — runs the ported runtime memory benches against the INSTALLED binary and asserts:
#   G1 client RssAnon (fixture 0)   <= 10 MB      G2 client RssAnon (fixture 20 MB) <= 12 MB
#   G3 client threads               <= 4          G4 first frame                    <= 100 ms
#   G5 all-in marginal per session  <= 10 MB      G7 retention (pre − post)         <= 0.5 MB
#   parked_marginal                 <= 1.0 MB
# Numbers are hardware-bound: this runs on the bench box only (ci: hardware). `--dry` proves the scripts execute
# (bash -n + --help paths) without a daemon — that is what CI runs. Exit 0/1/77.
# env: SYNAPS_BIN (default /usr/bin/synaps, then PATH), REPEAT (1), OUT_DIR (/tmp/openjawz-memprof)
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
OUT_DIR=${OUT_DIR:-/tmp/openjawz-memprof}; mkdir -p "$OUT_DIR"
rc=0
say() { printf '%-18s %-10s %-10s %s\n' "$1" "$2" "$3" "$4"; }
gate() { # name value limit
  local n=$1 v=$2 lim=$3
  if [ -z "$v" ] || [ "$v" = "-" ]; then say "$n" "?" "<= $lim" "NO DATA"; rc=1; return; fi
  if awk -v a="$v" -v b="$lim" 'BEGIN{exit !(a<=b)}'; then say "$n" "$v" "<= $lim" ok; else say "$n" "$v" "<= $lim" FAIL; rc=1; fi
}

if [ "${1:-}" = --dry ]; then
  for s in "$HERE"/*.sh; do bash -n "$s" || rc=1; done
  for p in "$HERE"/*.py; do python3 -m py_compile "$p" || rc=1; done
  [ $rc = 0 ] && echo "memprof: dry ok ($(ls "$HERE"/*.sh "$HERE"/*.py | wc -l) scripts parse)"
  exit $rc
fi

BIN=${SYNAPS_BIN:-/usr/bin/synaps}; [ -x "$BIN" ] || BIN=$(command -v synaps || true)
[ -x "${BIN:-}" ] || { echo "memprof: SKIP — no synaps binary"; exit 77; }
command -v tmux >/dev/null || { echo "memprof: SKIP — tmux missing"; exit 77; }
export REPEAT=${REPEAT:-1}

# client table: N=1, fixture 0 and 20 (BOUNDED=1 runs both) → G1 G2 G3 G4 G5 G7
DAEMON=1 CLIENT=1 BOUNDED=1 bash "$HERE/bench-sessions.sh" "$BIN" 1 2 > "$OUT_DIR/client.txt" 2>&1 || true
# rows: N fixture_mb client_anon_post client_anon_pre retention threads first_frame_ms attach_ms daemon_anon anon_marginal all_in_marginal
row0=$(awk '$1=="1" && $2=="0"  {print; exit}' "$OUT_DIR/client.txt")
row20=$(awk '$1=="1" && $2=="20" {print; exit}' "$OUT_DIR/client.txt")
row2=$(awk '$1=="2" && $2=="0"  {print; exit}' "$OUT_DIR/client.txt")
gate G1_client_anon   "$(awk '{print $3}' <<<"$row0")"  10
gate G2_client_anon20 "$(awk '{print $3}' <<<"$row20")" 12
gate G3_threads       "$(awk '{print $6}' <<<"$row0")"  4
gate G4_first_frame   "$(awk '{print $7}' <<<"$row0")"  100
gate G5_all_in_marg   "$(awk '{print $11}' <<<"$row2")" 10
gate G7_retention     "$(awk '{print $5}' <<<"$row0")"  0.5

# parked table: N=1,2 → parked_marginal at N=2
DAEMON=1 PARKED=1 bash "$HERE/bench-sessions.sh" "$BIN" 1 2 > "$OUT_DIR/parked.txt" 2>&1 || true
# rows: N live_anon_MB live_marginal parked_anon parked_marginal ratio daemon_procs attach_ms
rowp=$(awk '$1=="2" {print; exit}' "$OUT_DIR/parked.txt")
gate parked_marginal  "$(awk '{print $5}' <<<"$rowp")" 1.0

echo "memprof: tables in $OUT_DIR (binary $BIN, $("$BIN" --version 2>/dev/null))"
exit $rc
