#!/usr/bin/env bash
# ci: fast
# alpm-staging: pacman >= 7 downloads/reads the local repo as user `alpm` (DownloadUser=alpm). A repo left inside a
#   0700 $HOME is unreadable to it → `Could not open file …/openjawz.db` (Packager round-4 TEST A). boot --local AND
#   update --local fix this by staging a world-readable copy under /tmp (mktemp .../openjawz-repo.XXXXXX; chmod 755;
#   cp -r; chmod -R a+rX). This test asserts BOTH call sites stage that way, then REPLAYS the exact shipped staging
#   lines against a repo hidden under a 0700 dir and proves the staged copy is world-readable (dirs o+rx, files o+r)
#   while the original under 0700 is not — i.e. alpm under a 0700 HOME could read the stage (TEST A/B mechanism).
set -uo pipefail
cd "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)" || exit 1
fail=0; ok() { echo "  ok   $*"; }; bad() { echo "  FAIL $*"; fail=1; }

# 1. both call sites stage a world-readable /tmp copy
for pair in "boot:boot" "update:bin/openjawz-update"; do
  name="${pair%%:*}"; f="${pair#*:}"
  grep -Eq 'mktemp -d /tmp/openjawz-repo\.XXXXXX' "$f" && grep -Eq 'chmod 755' "$f" \
    && grep -Eq 'chmod -R a\+rX' "$f" \
    && ok "$name stages /tmp/openjawz-repo.XXXXXX (chmod 755 + cp -r + a+rX)" \
    || bad "$name does not stage a world-readable /tmp copy (alpm cannot read a 0700 HOME repo)"
done
# the staged copy, not the original, must be what pacman is pointed at
grep -Eq 'file://\$?\{?stage' boot && ok "boot points pacman at the /tmp stage, not the source dir" || bad "boot does not use the stage as the repo URL"
grep -Eq 'Server = file://%s' bin/openjawz-update && grep -q '"\$stage"' bin/openjawz-update && ok "update writes the /tmp stage as the repo Server" || bad "update does not use the stage as Server"

# 2. mechanism: hide a repo under a 0700 dir, replay the shipped staging lines, prove the stage is world-readable
src="$(mktemp -d)"; hidden="$src/home"; mkdir -p "$hidden/repo"; chmod 700 "$hidden"
printf 'db\n' > "$hidden/repo/openjawz.db"; printf 'pkg\n' > "$hidden/repo/openjawz-meta-0.1.0rc1-1-any.pkg.tar.zst"
mkdir -p "$hidden/repo/sub"; printf 'x\n' > "$hidden/repo/sub/nested"
stage=""
# shellcheck disable=SC2064
trap 'chmod -R u+rwX "$src" 2>/dev/null; rm -rf "$src" "${stage:-/nonexistent}"' EXIT
# lift the exact staging pipeline shipped in boot (mktemp/chmod/cp/chmod), retargeted at our fixture
stage_cmd="$(grep -oE 'stage=\$\(mktemp -d /tmp/openjawz-repo\.XXXXXX\); chmod 755 "\$stage"; cp -r [^;]+; chmod -R a\+rX "\$stage"' boot | head -1)"
[ -n "$stage_cmd" ] && ok "extracted boot's staging one-liner verbatim" || bad "could not find boot's staging one-liner"
# the cp source in boot is "$2"; bind it to our hidden repo and run the shipped pipeline
set -- x "$hidden/repo"; eval "$stage_cmd"
[ -d "$stage" ] || { bad "stage dir not created"; echo "alpm-staging: fail"; exit 1; }

# original under 0700: an "other" user (alpm) is blocked at the 0700 parent
[ "$(stat -c '%a' "$hidden")" = 700 ] && ok "source parent is 0700 (reproduces the alpm-unreadable case)" || bad "fixture parent not 0700"
# staged copy: dir 0755, every file world-readable, every subdir world-traversable
smode="$(stat -c '%a' "$stage")"; [ "$smode" = 755 ] && ok "stage dir mode 755 (o+rx)" || bad "stage dir mode $smode != 755"
badp=0
while IFS= read -r p; do
  m="$(stat -c '%a' "$p")"
  if [ -d "$p" ]; then case "$m" in *[157]) : ;; *) badp=1; echo "    dir not o+rx: $p ($m)";; esac
  else case "$m" in *[4567]) : ;; *) badp=1; echo "    file not o+r: $p ($m)";; esac; fi
done < <(find "$stage")
[ "$badp" = 0 ] && ok "every staged path is world-readable (alpm under a 0700 HOME can read it)" || bad "some staged paths are not world-readable"
[ -r "$stage/openjawz.db" ] && ok "staged openjawz.db present + readable" || bad "staged db missing/unreadable"

[ "$fail" = 0 ] && echo "alpm-staging: ok"
exit "$fail"
