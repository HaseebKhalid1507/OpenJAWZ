#!/usr/bin/env bash
# ci: container
# install-smoke: isolated archlinux:latest + systemd → packages built from THIS commit → boot --local → doctor green → attach → < 600 s
# usage: tests/install-smoke/run.sh [desktop|vm]   env: SYNAPS_TARBALL=path (required; SHA256SUMS beside it), AXEL_TARBALL=path
#        KEEP=1 also runs tests/uninstall-clean/uninstall-clean.sh inside afterwards (no second container needed)
set -uo pipefail
cd "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)" || exit 1
P="${1:-desktop}"; name="${OPENJAWZ_SMOKE_NAME:-oj-smoke}"
command -v docker >/dev/null || { echo "install-smoke: docker missing"; exit 77; }
[ -n "${SYNAPS_TARBALL:-}" ] && [ -f "$SYNAPS_TARBALL" ] || { echo "install-smoke: SYNAPS_TARBALL=<synaps-vX-x86_64-unknown-linux-gnu.tar.gz> required"; exit 77; }
work="$(mktemp -d "${TMPDIR:-/tmp}/oj-smoke.XXXXXX")"; chmod 755 "$work"
trap 'docker rm -f "$name" >/dev/null 2>&1; [ "${KEEP:-0}" = 1 ] || rm -rf "$work"' EXIT
mkdir -p "$work/src" "$work/dist"
git archive HEAD | tar -x -C "$work/src"
cp "$SYNAPS_TARBALL" "$work/dist/"; d="$(dirname "$SYNAPS_TARBALL")"
[ -n "${AXEL_TARBALL:-}" ] && [ -f "$AXEL_TARBALL" ] && cp "$AXEL_TARBALL" "$work/dist/"
{ [ -f "$d/SHA256SUMS" ] && cat "$d/SHA256SUMS"; [ -n "${AXEL_TARBALL:-}" ] && [ -f "$(dirname "$AXEL_TARBALL")/SHA256SUMS" ] && cat "$(dirname "$AXEL_TARBALL")/SHA256SUMS"; } > "$work/dist/SHA256SUMS" 2>/dev/null
cp tests/install-smoke/driver.sh tests/install-smoke/assert.sh tests/uninstall-clean/uninstall-clean.sh "$work/"
echo "$P" > "$work/profile"; [ -n "${OPENJAWZ_OSRELEASE:-}" ] && printf '%s\n' "$OPENJAWZ_OSRELEASE" > "$work/os-release"
[ "${KEEP:-0}" = 1 ] && : > "$work/keep"
chmod -R a+rX "$work"
tests/install-smoke/container.sh "$name" "$work" || { echo "install-smoke: container start failed"; exit 1; }
# follow the driver log until the result file appears (no docker exec, ever)
tail -n +1 -f "$work/driver.log" & tp=$!
for _ in $(seq 1 1800); do [ -f "$work/result" ] && break; docker inspect -f '{{.State.Running}}' "$name" 2>/dev/null | grep -q true || break; sleep 1; done
sleep 1; kill "$tp" 2>/dev/null
res="$(cat "$work/result" 2>/dev/null || echo "container-died")"
echo; echo "install-smoke: result=$res  $(cat "$work/summary" 2>/dev/null)"
[ "${KEEP:-0}" = 1 ] && { echo "uninstall-clean:"; cat "$work/uninstall.log" 2>/dev/null; }
[ "$res" = "done" ] || exit 1
read -r _ boot _ arc _ secs < <(sed 's/[a-z]*=//g' "$work/summary")
[ "$boot" = 0 ] && [ "$arc" = 0 ] && [ "$secs" -lt 600 ]
