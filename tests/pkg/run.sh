#!/usr/bin/env bash
# ci: fast
# pkg: PKGBUILD sanity — pkgver == VERSION, migrations well-formed, boot.sha256 current, boot --help, build-repo/PKGBUILD invariants, .SRCINFO, namcap (hard fail when present).
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
[ "$(wc -c < boot)" -le 6144 ] || { echo "FAIL boot > 6 KB"; fail=1; }
sh boot --help >/tmp/oj-boot-help.$$ 2>&1 && grep -q -- '--local' /tmp/oj-boot-help.$$ || { echo "FAIL boot --help must exit 0 and mention --local"; fail=1; }
rm -f /tmp/oj-boot-help.$$
# placeholder gate: a non-rc VERSION may not ship an all-zero KSHA
if grep -q 'KSHA="0\{64\}"' boot; then case "$ver" in *rc*) ;; *) echo "FAIL boot KSHA is a placeholder on a non-rc VERSION ($ver)"; fail=1 ;; esac; fi
# A7/A8: build-repo.sh + -bin PKGBUILD invariants
bash -n packages/build-repo.sh || { echo "FAIL build-repo.sh: syntax"; fail=1; }
grep -q 'allow-missing' packages/build-repo.sh || { echo "FAIL build-repo.sh lacks --allow-missing"; fail=1; }
grep -q 'pacman -Sp' packages/build-repo.sh 2>/dev/null || grep -q '\-Sp openjawz-meta' packages/build-repo.sh || { echo "FAIL build-repo.sh lacks the pacman -Sp resolvability check"; fail=1; }
for p in packages/*-bin/PKGBUILD; do
  grep -q '!debug' "$p" || { echo "FAIL $p lacks !debug"; fail=1; }
  grep -q "^depends=.*glibc" "$p" || { echo "FAIL $p lacks depends=(glibc …)"; fail=1; }
  grep -q 'placeholder' "$p" || { echo "FAIL $p prepare() lacks the placeholder-sha guard"; fail=1; }
done
grep -q "^license=('MIT')" packages/openjawz-keyring/PKGBUILD && [ -f packages/openjawz-keyring/LICENSE ] || { echo "FAIL keyring: license/LICENSE"; fail=1; }
grep -q "^provides=('openjawz')" packages/openjawz/PKGBUILD || grep -q "provides=('openjawz')" packages/openjawz/PKGBUILD || { echo "FAIL openjawz-meta lacks provides=('openjawz')"; fail=1; }
grep -q '^Target = usr/share/openjawz/migrations/\[0-9\]\*-\*\.sh' packages/openjawz/95-openjawz-migrations.hook || { echo "FAIL migrations hook Target must be [0-9]*-*.sh"; fail=1; }
# A11: .SRCINFO is environment-independent and committed
if command -v makepkg >/dev/null; then
  if [ -f packages/openjawz/.SRCINFO ]; then
    (cd packages/openjawz && OPENJAWZ_SRC=. makepkg --printsrcinfo 2>/dev/null) | diff -q - packages/openjawz/.SRCINFO >/dev/null || { echo "FAIL packages/openjawz/.SRCINFO stale (cd packages/openjawz && makepkg --printsrcinfo > .SRCINFO)"; fail=1; }
  else echo "FAIL packages/openjawz/.SRCINFO missing"; fail=1; fi
else echo "skip .SRCINFO check (no makepkg)"; fi
# A12: hidden verbs stay out of help
grep -q '^# hidden' bin/openjawz-daemon-exec || { echo "FAIL openjawz-daemon-exec lacks '# hidden'"; fail=1; }
OPENJAWZ_LIB="$PWD" bash bin/openjawz-help 2>/dev/null | grep -q daemon-exec && { echo "FAIL openjawz help lists daemon-exec"; fail=1; }
# A9: every tests/*/run.sh tier header equals the tier in tests/README.md
for t in tests/*/run.sh; do
  n="$(basename "$(dirname "$t")")"; h="$(sed -n '1,3p' "$t" | sed -n 's/^# ci: //p')"
  r="$(awk -F'|' -v n="$n" '/^\| `/ { t=$2; gsub(/[` ]/,"",t); s=$4; if (s ~ ("`" n "`")) print t }' tests/README.md | head -1)"
  [ -n "$r" ] || { echo "FAIL tests/README.md does not list tests/$n"; fail=1; continue; }
  [ "$h" = "$r" ] || { echo "FAIL tests/$n: header '$h' != README tier '$r'"; fail=1; }
done
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
  for p in packages/*/PKGBUILD; do
    o="$(namcap "$p" 2>&1 | grep -Ev 'dependency-detected-satisfied|^$')"
    [ -n "$o" ] && echo "namcap $p:" && echo "$o"
    echo "$o" | grep -q ' E: ' && { echo "FAIL namcap errors in $p"; fail=1; }
  done
else echo "skip (no namcap)"; fi
[ "$fail" = 0 ] && echo "pkg: ok"
exit "$fail"
