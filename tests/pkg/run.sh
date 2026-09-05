#!/usr/bin/env bash
# ci: container
# pkg: PKGBUILD sanity — pkgver == VERSION, migrations well-formed, boot.sha256 current, namcap on PKGBUILDs if present.
set -uo pipefail
cd "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)" || exit 1
fail=0
ver="$(cat VERSION)"
pv="$(sed -n 's/^pkgver=//p' packages/openjawz/PKGBUILD)"
[ "$pv" = "$ver" ] || { echo "FAIL pkgver $pv != VERSION $ver"; fail=1; }
# boot.sha256
if [ -f boot.sha256 ]; then
  sha256sum -c boot.sha256 >/dev/null 2>&1 || { echo "FAIL boot.sha256 is stale (run: sha256sum boot > boot.sha256)"; fail=1; }
else echo "FAIL boot.sha256 missing"; fail=1; fi
[ "$(wc -c < boot)" -le 4096 ] || { echo "FAIL boot > 4 KB"; fail=1; }
# migrations: header + monotonic epoch
prev=0
for m in $(ls migrations/[0-9]*-*.sh 2>/dev/null | sort); do
  n="$(basename "$m")"; e="${n%%-*}"; scope="$(echo "$n" | cut -d- -f2)"
  grep -q '^set -euo pipefail' "$m" || { echo "FAIL $n: no set -euo pipefail"; fail=1; }
  grep -q '^# openjawz-migration: ' "$m" || { echo "FAIL $n: no '# openjawz-migration:' header"; fail=1; }
  case "$scope" in user|system) ;; *) echo "FAIL $n: scope must be user|system"; fail=1 ;; esac
  [ "$e" -ge "$prev" ] || { echo "FAIL $n: epoch older than previous ($prev)"; fail=1; }
  prev="$e"
done
# headers on every verb
for f in bin/openjawz-*; do
  sed -n 2p "$f" | grep -q "^# $(basename "$f"): " || { echo "FAIL $f: header line 2 must be '# $(basename "$f"): …'"; fail=1; }
  sed -n '3,5p' "$f" | grep -q '^# owner: openjawz-' || { echo "FAIL $f: no owner header"; fail=1; }
done
# unit invariants (D1)
u=daemon/synaps-daemon.service
for k in 'Type=simple' 'RestartPreventExitStatus=3' 'StartLimitIntervalSec=0' 'RuntimeDirectoryPreserve=yes'; do
  grep -q "^$k" "$u" || { echo "FAIL $u lacks $k"; fail=1; }
done
[ -e daemon/synaps-daemon.socket ] && { echo "FAIL synaps-daemon.socket must not exist (D1/D4)"; fail=1; }
grep -q 'idle-exit' daemon/profiles/desktop.env && ! grep -q 'OPENJAWZ_IDLE_EXIT=0' daemon/profiles/desktop.env && { echo "FAIL desktop profile must not idle-exit"; fail=1; }
grep -q '"shared": true' daemon/mcp.json.default || { echo "FAIL mcp.json.default: axel must be shared:true"; fail=1; }
grep -Eq '^\[' daemon/config.default && { echo "FAIL config.default has a [section] — it is flat key = value"; fail=1; }
if command -v namcap >/dev/null; then
  for p in packages/*/PKGBUILD; do namcap "$p" 2>&1 | grep -Ev 'dependency-detected-satisfied|^$' | grep -q . && { echo "namcap $p:"; namcap "$p"; }; done
fi
[ "$fail" = 0 ] && echo "pkg: ok"
exit "$fail"
