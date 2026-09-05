#!/usr/bin/env bash
# verbatim-readme.sh: run the README "Local mode" recipe EXACTLY as printed, with ZERO out-of-README flags.
#   This is the guard for the round-4 Stranger blocker: the passing smoke built with `--no-sign` while the README
#   said `--throwaway` (which SIGNS the repo) — and boot --local mounts `SigLevel = Optional TrustAll`, which pacman
#   7.1 no longer trusts for an unknown DB key → the exact README command died at `pacman -Sy`. The smoke never ran
#   the README's own words. This leg extracts the build-repo flags + the boot --local dir straight FROM README.md and
#   runs them, so if the recipe ever drifts back to a signed build under TrustAll, `pacman -Sy` fails and so do we.
#
# Runs INSIDE the smoke container as the tester user, from a FRESH copy of the tree (so build/repo default + ./boot
# resolve exactly like a stranger's `git clone && cd OpenJAWZ`). Args: $1 = SYNAPS_TARBALL, $2 = AXEL_TARBALL (opt).
set -uo pipefail
fail=0; ok() { echo "  ok   $*"; }; bad() { echo "  FAIL $*"; fail=1; }
ST="${1:?SYNAPS_TARBALL required}"; AX="${2:-}"
SRC="${VERBATIM_SRC:-/tmp/src}"
README="$SRC/README.md"
[ -f "$README" ] || { echo "verbatim-readme: no README at $README"; exit 1; }

# ── extract the recipe straight from README.md (the fenced block that contains `boot --local build/repo`) ──
recipe="$(awk '/^```sh/{b++; buf=""; inb=1; next} /^```/{ if(inb && buf ~ /boot --local/) print buf; inb=0; next } inb{ buf=buf $0 "\n" }' "$README")"
[ -n "$recipe" ] && ok "found the README local-mode recipe block" || { bad "no local-mode recipe block in README"; echo "verbatim-readme: fail=1"; exit 1; }

buildline="$(grep -E 'build-repo\.sh' <<<"$recipe" | head -1)"
bootline="$(grep -E 'boot --local' <<<"$recipe" | head -1)"
echo "  README build line: $buildline"
echo "  README boot  line: $bootline"

# the exact build-repo flags README prints (everything after build-repo.sh, minus trailing comment)
build_flags="$(sed -E 's/.*build-repo\.sh//; s/#.*$//' <<<"$buildline" | xargs echo)"
boot_dir="$(sed -E 's/.*boot --local[[:space:]]+//; s/#.*$//' <<<"$bootline" | awk '{print $1}')"
echo "  parsed build flags: [$build_flags]   boot dir: [$boot_dir]"

# ── static consistency (also catches the blocker without a pacman run) ──
# boot --local mounts TrustAll (not Never); a TrustAll mount of a SIGNED repo is the blocker. So the README build
# must be unsigned (--no-sign). --throwaway signs → would die at pacman -Sy.
if grep -q 'SigLevel = Optional TrustAll' "$SRC/boot"; then
  case " $build_flags " in
    *" --no-sign "*) ok "README builds --no-sign, consistent with boot's TrustAll local mount" ;;
    *" --throwaway "*|*" --sign "*|*" --key "*) bad "README builds a SIGNED repo but boot --local uses TrustAll → pacman -Sy will reject the unknown DB key (the Stranger blocker)" ;;
    *) bad "README build-repo flags [$build_flags] are neither --no-sign nor a known signed mode — cannot vouch for TrustAll compatibility" ;;
  esac
fi
[ "$boot_dir" = "build/repo" ] && ok "README boots the default build-repo output dir (build/repo)" || echo "  note: README boot dir is [$boot_dir] (build-repo default is build/repo)"

# ── run it for real, verbatim, from a fresh tree copy ──
work="$(mktemp -d /tmp/oj-verbatim.XXXXXX)"; cp -a "$SRC" "$work/OpenJAWZ"; cd "$work/OpenJAWZ" || exit 1
d="$(dirname "$ST")"; [ -f "$d/SHA256SUMS" ] && cp "$d/SHA256SUMS" . 2>/dev/null || true
# the README recipe starts with `git clone`, so build-repo.sh's default source (git archive HEAD) needs a git HEAD.
# reproduce the clone's git-ness if the copy arrived without a .git (e.g. from a git-archive export).
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  git init -q .; git add -A; git -c user.name=oj -c user.email=oj@localhost commit -qm tree >/dev/null 2>&1
fi
export HOME="$work/home"; mkdir -p "$HOME"
XDG_RUNTIME_DIR="/run/user/$(id -u)"; export XDG_RUNTIME_DIR; mkdir -p "$XDG_RUNTIME_DIR" 2>/dev/null || true

# line 1: build with README's exact flags (only the tarball path is substituted, as README instructs)
env SYNAPS_TARBALL="$ST" ${AX:+AXEL_TARBALL="$AX"} bash -c "packages/build-repo.sh $build_flags" > "$work/build.log" 2>&1
brc=$?
[ "$brc" = 0 ] && [ -f "$boot_dir/openjawz.db" ] && ok "build-repo.sh $build_flags → $boot_dir/openjawz.db (rc=0)" || { bad "build-repo.sh $build_flags failed (rc=$brc)"; tail -5 "$work/build.log"; }

# line 2: boot --local <dir>, VERBATIM
env OPENJAWZ_YES=1 sh boot --local "$boot_dir" > "$work/boot.log" 2>&1
crc=$?
# THE blocker check (this is the whole point of the leg): pacman -Sy must not die on a signature
if grep -qE 'invalid or corrupted database \(PGP signature\)|key ".*" is unknown' "$work/boot.log"; then
  bad "boot --local died at pacman -Sy on a DB signature — the Stranger blocker is BACK"; grep -E 'error:|invalid or corrupted' "$work/boot.log" | head -3
else ok "boot --local got past pacman -Sy without a signature rejection"; fi
# the recipe must actually install the meta package from the unsigned repo
if pacman -Q openjawz-meta >/dev/null 2>&1; then ok "openjawz-meta installed from the verbatim recipe"; else bad "openjawz-meta not installed by the verbatim recipe"; fi
# the closing 'synaps --attach' line is printed by openjawz install's user-side stages, which need a LIVE systemd
# --user manager (logind session bus). `systemctl --user --version` only prints the binary version (passes even with
# no session — Stranger round-4), so probe the actual user bus with list-jobs. It IS live in the real
# (systemd-PID-1) install-smoke; under a no-session container (blood rule forbids --privileged PID-1) it is not.
if systemctl --user list-jobs >/dev/null 2>&1; then
  grep -q 'synaps --attach' "$work/boot.log" && ok "boot reached the closing 'synaps --attach' line (full install)" || { bad "boot did not reach the attach line (rc=$crc)"; tail -8 "$work/boot.log"; }
else
  echo "  defer: no live systemd --user manager (blood rule forbids --privileged PID-1) — attach-line tail verified only in the real install-smoke; blocker-guard (pacman -Sy + meta install) proven above"
fi

rm -rf "$work" 2>/dev/null || true
echo "verbatim-readme: fail=$fail"
exit "$fail"
