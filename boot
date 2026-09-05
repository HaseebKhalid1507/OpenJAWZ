#!/bin/sh
# OpenJAWZ bootstrap.  curl -fsSLo boot https://raw.githubusercontent.com/HaseebKhalid1507/OpenJAWZ/main/boot
#   sha256sum -c boot.sha256 && sh boot
# env: OPENJAWZ_VERSION=0.1.0 OPENJAWZ_TRACK=stable|edge OPENJAWZ_YES=1 OPENJAWZ_DRY_RUN=1 OPENJAWZ_PROFILE=P
#      OPENJAWZ_REPO=file:///dir   (or --local DIR: unsigned local repo, test mode; writes nothing under /etc)
set -eu
usage() {
  sed -n '2,5p' "$0"
  cat <<'EOF'
flags: --local DIR   built local repo (packages/build-repo.sh --no-sign --out DIR); unsigned, transient, no /etc
       --dry-run     print what would run (and the pinned keyring sha)
       --yes | -y    no prompts (non-tty needs it)   --profile P   desktop|laptop|deck|vm
       --version V   pin openjawz-meta=V             --help | -h
EOF
}
die() { echo "boot: $*" >&2; exit 1; }
main() {
  ver="${OPENJAWZ_VERSION:-latest}"; track="${OPENJAWZ_TRACK:-stable}"; dry="${OPENJAWZ_DRY_RUN:-0}"
  yes="${OPENJAWZ_YES:-0}"; repo="${OPENJAWZ_REPO:-}"; prof="${OPENJAWZ_PROFILE:-}"
  while [ $# -gt 0 ]; do case "$1" in
    --local) [ -d "${2:-}" ] || die "--local needs a directory"; repo="file://$(cd "$2" && pwd)"; shift;;
    --dry-run) dry=1;; --yes|-y) yes=1;;
    --profile) prof="${2:?--profile needs P}"; shift;; --version) ver="${2:?--version needs V}"; shift;;
    -h|--help) usage; exit 0;;
    *) echo "boot: unknown flag $1" >&2; usage >&2; exit 2;; esac; shift; done
  # 0. validate
  case "$track" in stable|edge) ;; *) die "track must be stable|edge";; esac
  case "$ver" in latest) ;; *) printf '%s' "$ver" | grep -Eq '^[0-9][0-9A-Za-z.]*$' || die "bad version $ver";; esac
  case "$prof" in ''|desktop|laptop|deck|vm) ;; *) die "profile must be desktop|laptop|deck|vm";; esac
  case "$repo" in ''|file:///*) ;; *) die "OPENJAWZ_REPO must be file:///DIR";; esac
  run() { if [ "$dry" = 1 ]; then printf '+ %s\n' "$*"; else "$@"; fi; }
  need() { command -v "$1" >/dev/null 2>&1 || die "need $1"; }
  need pacman; need curl; need sha256sum
  # 1. distro
  ID=; ID_LIKE=; [ -r /etc/os-release ] && . /etc/os-release
  case " $ID $ID_LIKE " in *arch*) ;; *) die "Arch-based Linux only (ID=${ID:-?})";; esac
  case "$ID" in manjaro*) echo "boot: warning: Manjaro delays Arch packages" >&2;; esac
  [ "$(uname -m)" = x86_64 ] || die "$(uname -m) unsupported yet (aarch64 client is v0.2)"
  systemctl --user --version >/dev/null 2>&1 || die "needs a systemd user session"
  # 2. never the whole script as root
  [ "$(id -u)" -ne 0 ] || die "run as your user, not root (sudo is called where needed)"
  SUDO=sudo; command -v sudo >/dev/null 2>&1 || { SUDO=doas; need doas; }
  # 3. stdin is the pipe; prompts go through /dev/tty
  if [ "$yes" != 1 ] && [ ! -t 0 ]; then
    [ -t 1 ] || die "not a terminal; re-run with OPENJAWZ_YES=1"
    exec </dev/tty
  fi
  tmp=$(mktemp -d); added=0
  # what we wrote to /etc comes back out on failure
  cleanup() { rc=$?; if [ "$rc" -ne 0 ] && [ "$added" = 1 ]; then
      $SUDO sed -i '/^Include = \/etc\/pacman.d\/openjawz.conf$/d' /etc/pacman.conf; $SUDO rm -f /etc/pacman.d/openjawz.conf
      echo "boot: failed (rc=$rc); repo line removed" >&2; fi; rm -rf "$tmp"; }
  trap cleanup EXIT
  pkg=openjawz-meta; [ "$ver" = latest ] || pkg="openjawz-meta=$ver"
  ask() { [ "$yes" = 1 ] && return; printf 'Install %s from %s (also upgrades your system)? [y/N] ' "$1" "$2"; read -r a; case "$a" in y|Y) ;; *) die aborted;; esac; }
  if [ -n "$repo" ]; then
    # 4a. local mode: no trust root, nothing under /etc — trust lives in $tmp and dies with it
    dir="${repo#file://}"
    { [ -r "$dir/openjawz.db" ] && ls "$dir"/openjawz-meta-*.pkg.tar.zst >/dev/null 2>&1; } ||
      die "$dir is not a built repo (packages/build-repo.sh --no-sign --out DIR)"
    printf '\033[31m!! UNSIGNED LOCAL REPO (test mode) %s\033[0m\n' "$dir" >&2
    cp /etc/pacman.conf "$tmp/pacman.conf"
    printf '\n[openjawz]\nSigLevel = Optional TrustAll\nServer = %s\n' "$repo" >>"$tmp/pacman.conf"
    ask "$pkg" "$dir"
    run $SUDO rm -f /var/lib/pacman/sync/openjawz.db /var/lib/pacman/sync/openjawz.files
    run $SUDO pacman --config "$tmp/pacman.conf" -Syu --needed --noconfirm "$pkg"
  else
    # 4b. trust root: keyring pinned + checksummed HERE (bump on rotation)
    KURL="https://github.com/HaseebKhalid1507/OpenJAWZ/releases/download/keyring/openjawz-keyring-20260905-1-any.pkg.tar.zst"
    KSHA="0000000000000000000000000000000000000000000000000000000000000000"
    SERVER="https://github.com/HaseebKhalid1507/OpenJAWZ/releases/download/repo-$track-x86_64"
    [ "$dry" = 1 ] && printf '+ keyring %s\n  sha256=%s\n' "$KURL" "$KSHA"
    # verify the repo exists BEFORE anything is written
    curl -fsSI --proto '=https' --tlsv1.2 "$SERVER/openjawz.db" >/dev/null 2>&1 ||
      die "repo $track is not published yet — see README 'Local mode'"
    run curl -fsSL --proto '=https' --tlsv1.2 -o "$tmp/keyring.pkg.tar.zst" "$KURL" || die "keyring download failed"
    [ "$dry" = 1 ] || echo "$KSHA  $tmp/keyring.pkg.tar.zst" | sha256sum -c - >/dev/null || die "keyring checksum mismatch"
    ask "$pkg" "$track"
    run $SUDO pacman -U --noconfirm --needed "$tmp/keyring.pkg.tar.zst"
    # 5. repo line; the trap removes it if anything below fails
    printf '[openjawz]\nSigLevel = Required DatabaseOptional\nServer = %s\n' "${SERVER%-x86_64}-\$arch" > "$tmp/openjawz.conf"
    grep -q '^Include = /etc/pacman.d/openjawz.conf' /etc/pacman.conf 2>/dev/null || [ "$dry" = 1 ] || added=1
    run $SUDO install -m644 "$tmp/openjawz.conf" /etc/pacman.d/openjawz.conf
    [ "$added" = 0 ] || printf '\nInclude = /etc/pacman.d/openjawz.conf\n' | $SUDO tee -a /etc/pacman.conf >/dev/null
    [ "$dry" = 1 ] && echo "+ append Include to /etc/pacman.conf"
    # 6. -Syu: never a partial upgrade
    run $SUDO pacman -Syu --needed --noconfirm "$pkg"; added=0
  fi
  # 7. the packaged installer (user side)
  set -- ; [ "$yes" = 1 ] && set -- --yes; [ -n "$prof" ] && set -- "$@" --profile "$prof"
  [ "$dry" = 1 ] && { echo "+ openjawz install $*"; exit 0; }
  OPENJAWZ_YES="$yes" OPENJAWZ_REPO="$repo" openjawz install "$@"
  echo "Done. Uninstall: openjawz uninstall"
}
main "$@"
