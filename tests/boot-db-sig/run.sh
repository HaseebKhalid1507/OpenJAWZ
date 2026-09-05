#!/usr/bin/env bash
# ci: fast
# boot-db-sig: a stale openjawz.db.sig in pacman's sync dir poisons `pacman -Sy` on a signed→local switch
#              (GPGME "No data" / "invalid or corrupted database (PGP signature)"). Codifies Packager round-4 TEST E:
#              boot AND update AND uninstall must rm openjawz.{db,files}{,.sig}. Asserts all three call sites, then
#              runs the exact rm lines against a fake sync dir to prove the .sig is actually gone (necessary+sufficient).
set -uo pipefail
cd "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)" || exit 1
fail=0; ok() { echo "  ok   $*"; }; bad() { echo "  FAIL $*"; fail=1; }

# 1. all three call sites remove the signature files, not just the db (the round-2/4 REPEAT was boot omitting .sig)
for pair in "boot:boot" "openjawz-update:bin/openjawz-update" "openjawz-uninstall:bin/openjawz-uninstall"; do
  name="${pair%%:*}"; f="${pair#*:}"
  grep -Eq 'rm -f .*/var/lib/pacman/sync/openjawz\.db\.sig' "$f" \
    && grep -Eq 'rm -f .*/var/lib/pacman/sync/openjawz\.files\.sig' "$f" \
    && ok "$name removes openjawz.db.sig + openjawz.files.sig" \
    || bad "$name does not rm the stale .sig files (Packager TEST E: -Sy stays poisoned)"
  grep -Eq 'rm -f .*/var/lib/pacman/sync/openjawz\.db( |$)' "$f" \
    && ok "$name removes openjawz.db + openjawz.files" \
    || bad "$name does not rm openjawz.db/.files"
done

# 2. the mechanism: replay the exact rm lines against a fake sync dir; the .sig must actually disappear
sync="$(mktemp -d)"; trap 'rm -rf "$sync"' EXIT
touch "$sync"/openjawz.db "$sync"/openjawz.files "$sync"/openjawz.db.sig "$sync"/openjawz.files.sig
# extract every rm command that targets the sync dir from all three scripts, retarget it at our fake dir, run it
grep -hoE 'rm -f [^;#]*var/lib/pacman/sync/openjawz[^;#]*' boot bin/openjawz-update bin/openjawz-uninstall \
  | sed "s#\(\$SUDO \|\$sudo \)##g; s#/var/lib/pacman/sync#$sync#g" \
  | while IFS= read -r cmd; do eval "$cmd"; done
[ ! -e "$sync/openjawz.db.sig" ] && [ ! -e "$sync/openjawz.files.sig" ] && ok "replayed rm lines removed the stale .sig (sufficient)" || bad "stale .sig survived the shipped rm lines"
[ ! -e "$sync/openjawz.db" ] && [ ! -e "$sync/openjawz.files" ] && ok "replayed rm lines removed the stale db" || bad "stale db survived"

[ "$fail" = 0 ] && echo "boot-db-sig: ok"
exit "$fail"
