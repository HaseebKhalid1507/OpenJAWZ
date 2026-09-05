#!/usr/bin/env bash
# ci: container
# install-smoke: fresh archlinux:latest + systemd → packages built from THIS commit → boot --local → doctor green → attach → < 600 s
# usage: tests/install-smoke/run.sh [desktop|vm]   env: SYNAPS_TARBALL=path (required; SHA256SUMS beside it), AXEL_TARBALL=path, KEEP=1
set -uo pipefail
cd "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)" || exit 1
P="${1:-desktop}"; name="${OPENJAWZ_SMOKE_NAME:-oj-smoke}"
command -v docker >/dev/null || { echo "install-smoke: docker missing"; exit 77; }
[ -n "${SYNAPS_TARBALL:-}" ] && [ -f "$SYNAPS_TARBALL" ] || { echo "install-smoke: SYNAPS_TARBALL=<synaps-vX-x86_64-unknown-linux-gnu.tar.gz> required"; exit 77; }
work="$(mktemp -d "${TMPDIR:-/tmp}/oj-smoke.XXXXXX")"; chmod 755 "$work"
if [ "${KEEP:-0}" = 1 ]; then trap 'rm -rf "$work"' EXIT; else trap 'docker rm -f "$name" >/dev/null 2>&1; rm -rf "$work"' EXIT; fi
mkdir -p "$work/src" "$work/dist"
git archive HEAD | tar -x -C "$work/src"
cp "$SYNAPS_TARBALL" "$work/dist/"; d="$(dirname "$SYNAPS_TARBALL")"
[ -n "${AXEL_TARBALL:-}" ] && [ -f "$AXEL_TARBALL" ] && cp "$AXEL_TARBALL" "$work/dist/"
{ [ -f "$d/SHA256SUMS" ] && cat "$d/SHA256SUMS"; [ -n "${AXEL_TARBALL:-}" ] && [ -f "$(dirname "$AXEL_TARBALL")/SHA256SUMS" ] && cat "$(dirname "$AXEL_TARBALL")/SHA256SUMS"; } > "$work/dist/SHA256SUMS" 2>/dev/null
chmod -R a+rX "$work"
echo "== container + package build (not on the clock)"
tests/install-smoke/container.sh "$name" "$work" || { echo "install-smoke: container/build failed"; exit 1; }
echo "== boot --local ($P)  [clock starts]"
T0=$(date +%s)
docker exec "$name" runuser -u tester -- env HOME=/home/tester XDG_RUNTIME_DIR=/run/user/1000 OPENJAWZ_YES=1 OPENJAWZ_PROFILE="$P" sh /tmp/src/boot --local /repo
rc=$?
T1=$(date +%s)
echo "== assert"
docker cp tests/install-smoke/assert.sh "$name:/tmp/assert.sh"
docker exec "$name" runuser -u tester -- env HOME=/home/tester XDG_RUNTIME_DIR=/run/user/1000 bash /tmp/assert.sh "$P"; arc=$?
echo
echo "install-smoke: boot=$rc assert=$arc profile=$P  $((T1-T0)) s"
[ "$rc" = 0 ] && [ "$arc" = 0 ] && [ $((T1-T0)) -lt 600 ]
