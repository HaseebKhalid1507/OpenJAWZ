#!/bin/sh
# OpenJAWZ bootstrap.  curl -fsSLo boot https://raw.githubusercontent.com/HaseebKhalid1507/OpenJAWZ/main/boot
#   sha256sum -c boot.sha256 && sh boot
# env: OPENJAWZ_VERSION=0.1.0 OPENJAWZ_TRACK=stable|edge OPENJAWZ_YES=1 OPENJAWZ_DRY_RUN=1 OPENJAWZ_PROFILE=P
#      OPENJAWZ_REPO=file:///dir   (or --local DIR: unsigned local repo, test mode)
set -eu
main() {
  ver="${OPENJAWZ_VERSION:-latest}"; track="${OPENJAWZ_TRACK:-stable}"; dry="${OPENJAWZ_DRY_RUN:-0}"
  yes="${OPENJAWZ_YES:-0}"; repo="${OPENJAWZ_REPO:-}"; prof="${OPENJAWZ_PROFILE:-}"
  while [ $# -gt 0 ]; do case "$1" in
    --local) repo="file://$(cd "$2" && pwd)"; shift;; --dry-run) dry=1;; --yes|-y) yes=1;;
    --profile) prof="$2"; shift;; --version) ver="$2"; shift;;
    *) echo "boot: unknown flag $1" >&2; exit 1;; esac; shift; done
  run() { if [ "$dry" = 1 ]; then printf '+ %s\n' "$*"; else "$@"; fi; }
  need() { command -v "$1" >/dev/null 2>&1 || { echo "boot: need '$1'" >&2; exit 1; }; }
  need pacman; need curl; need sha256sum
  # 1. distro / arch / systemd
  ID=; ID_LIKE=; [ -r /etc/os-release ] && . /etc/os-release
  case " $ID $ID_LIKE " in *arch*) ;; *) echo "boot: OpenJAWZ installs onto Arch-based Linux only (ID=${ID:-?})" >&2; exit 1;; esac
  case "$ID" in manjaro*) echo "boot: warning — Manjaro delays Arch packages" >&2;; esac
  [ "$(uname -m)" = x86_64 ] || { echo "boot: $(uname -m) is not supported yet (aarch64 client is v0.2)" >&2; exit 1; }
  systemctl --user --version >/dev/null 2>&1 || { echo "boot: needs a systemd user session" >&2; exit 1; }
  # 2. privilege: never the whole script as root
  [ "$(id -u)" -ne 0 ] || { echo "boot: run as your user, not root (sudo is called where needed)" >&2; exit 1; }
  if command -v sudo >/dev/null 2>&1; then SUDO=sudo; elif command -v doas >/dev/null 2>&1; then SUDO=doas; else echo "boot: need sudo or doas" >&2; exit 1; fi
  # 3. stdin is the pipe; prompts go through /dev/tty or not at all
  if [ "$yes" != 1 ] && [ ! -t 0 ]; then
    [ -t 1 ] || { echo "boot: not a terminal; re-run with OPENJAWZ_YES=1" >&2; exit 1; }
    exec </dev/tty
  fi
  tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
  if [ -n "$repo" ]; then
    # local test mode: no trust root, no signatures
    printf '\033[31m!! UNSIGNED LOCAL REPO — test mode (%s)\033[0m\n' "$repo" >&2
    printf '# OPENJAWZ-LOCAL test repo written by boot\n[openjawz]\nSigLevel = Optional TrustAll\nServer = %s\n' "$repo" > "$tmp/openjawz.conf"
  else
    # 4. trust root: keyring package pinned + checksummed HERE (bump on rotation)
    KURL="https://github.com/HaseebKhalid1507/OpenJAWZ/releases/download/keyring/openjawz-keyring-20260905-1-any.pkg.tar.zst"
    KSHA="0000000000000000000000000000000000000000000000000000000000000000"
    run curl -fsSL --proto '=https' --tlsv1.2 -o "$tmp/keyring.pkg.tar.zst" "$KURL"
    [ "$dry" = 1 ] || echo "$KSHA  $tmp/keyring.pkg.tar.zst" | sha256sum -c - >/dev/null || { echo "boot: keyring checksum mismatch" >&2; exit 1; }
    run $SUDO pacman -U --noconfirm --needed "$tmp/keyring.pkg.tar.zst"
    printf '[openjawz]\nSigLevel = Required DatabaseOptional\nServer = https://github.com/HaseebKhalid1507/OpenJAWZ/releases/download/repo-%s-$arch\n' "$track" > "$tmp/openjawz.conf"
  fi
  # 5. repo line, idempotent
  run $SUDO install -m644 "$tmp/openjawz.conf" /etc/pacman.d/openjawz.conf
  grep -q '^Include = /etc/pacman.d/openjawz.conf' /etc/pacman.conf 2>/dev/null ||
    { [ "$dry" = 1 ] && echo "+ append Include to /etc/pacman.conf" || printf '\nInclude = /etc/pacman.d/openjawz.conf\n' | $SUDO tee -a /etc/pacman.conf >/dev/null; }
  # 6. install (pinned if asked)
  pkg=openjawz-meta; [ "$ver" = latest ] || pkg="openjawz-meta=$ver"
  run $SUDO pacman -Sy --needed --noconfirm "$pkg"
  # 7. hand off to the packaged, logged, idempotent installer (user side)
  set -- ; [ "$yes" = 1 ] && set -- --yes; [ -n "$prof" ] && set -- "$@" --profile "$prof"
  [ "$dry" = 1 ] && { echo "+ openjawz install $*"; exit 0; }
  OPENJAWZ_YES="$yes" openjawz install "$@"
  echo "Done. Uninstall any time: openjawz uninstall"
}
main "$@"
