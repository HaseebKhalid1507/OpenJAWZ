#!/usr/bin/env bash
# build-repo.sh: build every package from THIS tree into a pacman repo (optionally signed)
# usage: packages/build-repo.sh [--out DIR] [--key KEYID | --throwaway | --no-sign] [--src TREE]
#   env: SYNAPS_TARBALL=… AXEL_TARBALL=… (local -bin builds; SHA256SUMS beside each tarball)
#        OPENJAWZ_KEYS=dir  (public key material for openjawz-keyring; --throwaway generates it)
# Output: DIR/{*.pkg.tar.zst[.sig], openjawz.db, openjawz.db.tar.zst, openjawz.files, …} with real files (no symlinks)
# so it can be uploaded to a GitHub Release as-is.
set -euo pipefail
root="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
out="$root/build/repo"; key=""; sign=1; throwaway=0; src=""
while [ $# -gt 0 ]; do
  case "$1" in
    --out) out="$2"; shift ;;
    --key) key="$2"; shift ;;
    --throwaway) throwaway=1 ;;
    --no-sign) sign=0 ;;
    --src) src="$2"; shift ;;
    -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
    *) echo "unknown flag $1" >&2; exit 1 ;;
  esac; shift
done
[ "$(id -u)" -ne 0 ] || { echo "makepkg refuses root; run as a user" >&2; exit 1; }
mkdir -p "$out"; out="$(cd "$out" && pwd)"
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT

if [ -z "$src" ]; then
  src="$work/tree"; mkdir -p "$src"
  git -C "$root" archive HEAD | tar -x -C "$src"
fi
ver="$(cat "$src/VERSION")"

if [ "$throwaway" = 1 ]; then
  export GNUPGHOME="$work/gnupg"; mkdir -m700 -p "$GNUPGHOME"
  gpg --batch --quiet --passphrase '' --quick-gen-key "OpenJAWZ throwaway (CI) <ci@localhost>" ed25519 sign 0 >/dev/null 2>&1
  key="$(gpg --batch --list-keys --with-colons | awk -F: '/^fpr/{print $10; exit}')"
  export OPENJAWZ_KEYS="$work/keys"; mkdir -p "$OPENJAWZ_KEYS"
  gpg --batch --export "$key" > "$OPENJAWZ_KEYS/openjawz.gpg"
  printf '%s:4:\n' "$key" > "$OPENJAWZ_KEYS/openjawz-trusted"
  : > "$OPENJAWZ_KEYS/openjawz-revoked"
  echo "throwaway key: $key"
fi
[ "$sign" = 1 ] && [ -z "$key" ] && { echo "no --key given; building unsigned (--no-sign to silence)" >&2; sign=0; }
mk=(makepkg -f --noconfirm --syncdeps); [ "$sign" = 1 ] && mk+=(--sign --key "$key")
export PKGDEST="$out"

build() { # dir env…
  local d="$1"; shift
  echo "== $d"
  ( cd "$src/packages/$d" && env "$@" "${mk[@]}" ) || { echo "!! $d failed" >&2; return 1; }
}
build openjawz OPENJAWZ_SRC="$src"
if [ -n "${SYNAPS_TARBALL:-}" ]; then build synaps-bin SYNAPS_TARBALL="$SYNAPS_TARBALL" ${SYNAPS_SHA256:+SYNAPS_SHA256="$SYNAPS_SHA256"}
else echo "-- synaps-bin: no SYNAPS_TARBALL, trying the release URL"; build synaps-bin A=1 || echo "!! synaps-bin skipped"; fi
if [ -n "${AXEL_TARBALL:-}" ]; then build axel-bin AXEL_TARBALL="$AXEL_TARBALL" ${AXEL_SHA256:+AXEL_SHA256="$AXEL_SHA256"}
else echo "-- axel-bin: no AXEL_TARBALL, skipped (D7)"; fi
if [ -s "${OPENJAWZ_KEYS:-$src/packages/openjawz-keyring/keys}/openjawz.gpg" ]; then
  build openjawz-keyring ${OPENJAWZ_KEYS:+OPENJAWZ_KEYS="$OPENJAWZ_KEYS"}
else echo "-- openjawz-keyring: no public key material, skipped"; fi

cd "$out"
rm -f openjawz.db* openjawz.files*
ra=(repo-add); [ "$sign" = 1 ] && ra+=(--sign --key "$key")
"${ra[@]}" openjawz.db.tar.zst ./*.pkg.tar.zst >/dev/null
# GitHub Releases cannot host symlinks: materialise them
for f in openjawz.db openjawz.files openjawz.db.sig openjawz.files.sig; do
  [ -L "$f" ] && { t="$(readlink "$f")"; rm "$f"; cp "$t" "$f"; }
done
if command -v namcap >/dev/null; then namcap ./*.pkg.tar.zst 2>/dev/null | grep -v 'dependency-detected-satisfied' || true; fi
echo "repo: $out (openjawz $ver, signed=$sign)"; ls -1 "$out"
