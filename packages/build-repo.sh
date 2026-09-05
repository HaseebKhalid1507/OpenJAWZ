#!/usr/bin/env bash
# build-repo.sh: build every package from THIS tree into a pacman repo (optionally signed); refuses to publish a partial set
# usage: packages/build-repo.sh [--out DIR] [--key KEYID | --throwaway | --no-sign] [--src TREE] [--allow-missing] [--keyring-key KEYID]
#   env: SYNAPS_TARBALL=… AXEL_TARBALL=… (local -bin builds; SHA256SUMS beside each tarball)
#        OPENJAWZ_KEYS=dir  (public key material for openjawz-keyring; --throwaway generates it)
#   --allow-missing: a member that fails to build is skipped (dev only; the repo is then unsatisfiable and says so)
#   --throwaway: fresh key per run; every package gets pkgrel .tw<fpr8> so two runs never share a name with different bytes
#   the keyring package is NEVER signed with the key it contains (circular); --keyring-key signs it with an older key on rotation
# Output: DIR/{*.pkg.tar.zst[.sig], openjawz.db, openjawz.db.tar.zst, openjawz.files, …} with real files (no symlinks)
# so it can be uploaded to a GitHub Release as-is.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
out="$root/build/repo"; key=""; sign=1; throwaway=0; src=""; allow_missing=0; keyring_key=""
while [ $# -gt 0 ]; do
  case "$1" in
    --out) out="$2"; shift ;;
    --key) key="$2"; shift ;;
    --keyring-key) keyring_key="$2"; shift ;;
    --throwaway) throwaway=1 ;;
    --no-sign) sign=0 ;;
    --src) src="$2"; shift ;;
    --allow-missing) allow_missing=1 ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
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

relsuffix=""
if [ "$throwaway" = 1 ]; then
  export GNUPGHOME="$work/gnupg"; mkdir -p "$GNUPGHOME"; chmod 700 "$GNUPGHOME"
  gpg --batch --quiet --passphrase '' --quick-gen-key "OpenJAWZ throwaway (CI) <ci@localhost>" ed25519 sign 0 >/dev/null 2>&1
  key="$(gpg --batch --list-keys --with-colons | awk -F: '/^fpr/{print $10; exit}')"
  export OPENJAWZ_KEYS="$work/keys"; mkdir -p "$OPENJAWZ_KEYS"
  gpg --batch --export "$key" > "$OPENJAWZ_KEYS/openjawz.gpg"
  printf '%s:4:\n' "$key" > "$OPENJAWZ_KEYS/openjawz-trusted"
  : > "$OPENJAWZ_KEYS/openjawz-revoked"
  relsuffix=".tw${key:0:8}"
  echo "$key" > "$out/THROWAWAY"
  echo "throwaway key: $key (pkgrel suffix $relsuffix)"
fi
[ "$sign" = 1 ] && [ -z "$key" ] && { echo "no --key given; building unsigned (--no-sign to silence)" >&2; sign=0; }
mk=(makepkg -f --noconfirm --syncdeps)
export PKGDEST="$out" BUILDDIR="$work/build"
mkdir -p "$BUILDDIR"

# pkgrel suffix for throwaway builds (never the same name with different bytes across runs)
[ -n "$relsuffix" ] && for p in "$src"/packages/*/PKGBUILD; do sed -i -E "s/^(pkgrel=[0-9]+)$/\1$relsuffix/" "$p"; done

failed=()
build() { # dir [--unsigned] env…
  local d="$1" s="$sign" cmd; shift
  [ "${1:-}" = --unsigned ] && { s=0; shift; }
  cmd=("${mk[@]}"); [ "$s" = 1 ] && cmd+=(--sign --key "$key")
  echo "== $d"
  ( cd "$src/packages/$d" && env "$@" "${cmd[@]}" ) || { echo "!! $d failed" >&2; failed+=("$d"); return 1; }
}
build openjawz OPENJAWZ_SRC="$src" || true
if [ -n "${SYNAPS_TARBALL:-}" ]; then cp -f "$SYNAPS_TARBALL" "$src/packages/synaps-bin/"; build synaps-bin SYNAPS_TARBALL="$SYNAPS_TARBALL" ${SYNAPS_SHA256:+SYNAPS_SHA256="$SYNAPS_SHA256"} || true
else echo "-- synaps-bin: no SYNAPS_TARBALL, trying the release URL"; build synaps-bin A=1 || true; fi
if [ -n "${AXEL_TARBALL:-}" ]; then cp -f "$AXEL_TARBALL" "$src/packages/axel-bin/"; build axel-bin AXEL_TARBALL="$AXEL_TARBALL" ${AXEL_SHA256:+AXEL_SHA256="$AXEL_SHA256"} || true
else echo "-- axel-bin: no AXEL_TARBALL, skipped (D7: optdepends, the repo stays satisfiable)"; fi
if [ -s "${OPENJAWZ_KEYS:-$src/packages/openjawz-keyring/keys}/openjawz.gpg" ]; then
  # never signed by the key it ships; an older key may vouch for it on rotation
  if [ -n "$keyring_key" ]; then
    ( cd "$src/packages/openjawz-keyring" && env ${OPENJAWZ_KEYS:+OPENJAWZ_KEYS="$OPENJAWZ_KEYS"} "${mk[@]}" --sign --key "$keyring_key" ) || { echo "!! openjawz-keyring failed" >&2; failed+=(openjawz-keyring); }
  else
    build openjawz-keyring --unsigned ${OPENJAWZ_KEYS:+OPENJAWZ_KEYS="$OPENJAWZ_KEYS"} || true
  fi
else echo "-- openjawz-keyring: no public key material, skipped"; fi

if [ "${#failed[@]}" -gt 0 ]; then
  echo "!! failed to build: ${failed[*]}" >&2
  [ "$allow_missing" = 1 ] || { echo "!! not publishing a partial repo (--allow-missing to override)" >&2; exit 1; }
fi

cd "$out"
rm -f openjawz.db* openjawz.files*
ra=(repo-add); [ "$sign" = 1 ] && ra+=(--sign --key "$key")
"${ra[@]}" openjawz.db.tar.zst ./*.pkg.tar.zst >/dev/null
# GitHub Releases cannot host symlinks: materialise them
for f in openjawz.db openjawz.files openjawz.db.sig openjawz.files.sig; do
  [ -L "$f" ] && { t="$(readlink "$f")"; rm "$f"; cp "$t" "$f"; }
done

# the repo must resolve openjawz-meta on its own (plus the distro repos): no dangling synaps-*/openjawz-* deps
tmpconf="$work/pacman.conf"
{ grep -Ev '^\s*(Include|\[.*\])' /etc/pacman.conf 2>/dev/null | sed -n '/^\[options\]/,$p' || true; } > "$tmpconf"
grep -q '^\[options\]' "$tmpconf" || printf '[options]\nArchitecture = auto\n' > "$tmpconf"
printf '[openjawz]\nSigLevel = Never\nServer = file://%s\n' "$out" >> "$tmpconf"
missing="$(pacman --config "$tmpconf" --dbpath "$work/db" -Sp openjawz-meta 2>&1 >/dev/null | grep -Eo "(unable to satisfy|could not satisfy|target not found).*" || true)"
if [ -n "$missing" ]; then
  echo "!! repo is unsatisfiable: $missing" >&2
  [ "$allow_missing" = 1 ] || exit 1
fi
if command -v namcap >/dev/null; then namcap ./*.pkg.tar.zst 2>/dev/null | grep -v 'dependency-detected-satisfied' || true; fi
echo "repo: $out (openjawz $ver, signed=$sign, throwaway=$throwaway)"; ls -1 "$out"
