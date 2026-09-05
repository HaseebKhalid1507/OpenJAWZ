#!/usr/bin/env bash
# ci: fast
# build-repo-pkgrel: `build-repo.sh --throwaway` must emit a pkgrel makepkg accepts. makepkg's lint allows only
#   integer[.integer] (/usr/share/makepkg/lint_pkgbuild/pkgrel.sh: +([0-9])?(.+([0-9]))). round-2 shipped
#   `1.twF20B750C` (rejected); round-3 fixed it to a DECIMAL of the fingerprint's first 6 hex digits (Packager
#   round-4 live proof: pkgrel=1.6646545, makepkg rc=0). This test replays the SHIPPED relsuffix expression and
#   the SHIPPED sed transform from build-repo.sh and asserts the result matches ^[0-9]+(\.[0-9]+)?$ (and makepkg's
#   own lint, if present) — no key/tarball/makepkg run needed, so it is CI-fast.
set -uo pipefail
cd "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)" || exit 1
fail=0; ok() { echo "  ok   $*"; }; bad() { echo "  FAIL $*"; fail=1; }
rx='^[0-9]+(\.[0-9]+)?$'

# the exact relsuffix expression shipped in build-repo.sh (fail loudly if it ever moves)
rel_line="$(grep -oE 'relsuffix="\.\$\(\(16#\$\{key:0:6\}\)\)"' packages/build-repo.sh)"
[ -n "$rel_line" ] && ok "build-repo.sh:46 relsuffix is decimal-of-fingerprint (not the round-2 raw-hex bug)" \
  || bad "build-repo.sh no longer computes relsuffix=.\$((16#\${key:0:6})) — the pkgrel-legality fix moved"
# the exact sed transform that stamps the suffix onto pkgrel=N
sed_line="$(grep -oE 's/\^\(pkgrel=\[0-9\]\+\)\$/\\1\$relsuffix/' packages/build-repo.sh)"
[ -n "$sed_line" ] && ok "build-repo.sh stamps the suffix only onto a bare integer pkgrel=N" \
  || bad "build-repo.sh pkgrel sed transform moved"

# replay: for a spread of realistic ed25519 fingerprint prefixes, compute the suffix + apply the sed, assert legal.
# Cross-check against makepkg's OWN rule by lifting its extglob pattern verbatim from lint_pkgbuild/pkgrel.sh
# (`+([0-9])?(.+([0-9]))`) — that is the exact predicate makepkg enforces, without the fragile libmakepkg sourcing.
lint=/usr/share/makepkg/lint_pkgbuild/pkgrel.sh
shopt -s extglob
if [ -r "$lint" ]; then
  mk_pat="$(sed -nE 's/.*\[\[ \$rel != (.*) \]\].*/\1/p' "$lint" | head -1)"
fi
[ -n "${mk_pat:-}" ] && have_lint=1 || have_lint=0
check_pkgrel() {  # $1 = pkgrel string
  [[ "$1" =~ $rx ]] || { bad "pkgrel '$1' fails ^[0-9]+(\\.[0-9]+)?\$"; return; }
  if [ "$have_lint" = 1 ]; then
    local rel="$1"
    eval "[[ \"\$rel\" == $mk_pat ]]" && ok "pkgrel '$1' — accepted by makepkg's own pattern ($mk_pat)" \
      || bad "pkgrel '$1' — makepkg pattern $mk_pat REJECTS"
  else ok "pkgrel '$1' matches integer[.integer]"; fi
}
for key in 6646545abc 4079562def 000001ffff ffffffaaaa 100000beef abcdef1234; do
  relsuffix=".$((16#${key:0:6}))"                      # ← build-repo.sh:46, verbatim
  pkgrel="$(printf 'pkgrel=1\n' | sed -E "s/^(pkgrel=[0-9]+)$/\1$relsuffix/")"   # ← build-repo.sh:56, verbatim
  pkgrel="${pkgrel#pkgrel=}"
  check_pkgrel "$pkgrel"
done
# the round-2 regression string must be rejected by both our regex AND makepkg's own pattern (guards the guard)
[[ "1.twF20B750C" =~ $rx ]] && bad "regex would accept the round-2 raw-hex bug" || ok "round-2 raw-hex pkgrel (1.twF20B750C) rejected by our regex"
if [ "$have_lint" = 1 ]; then rel="1.twF20B750C"; eval "[[ \"\$rel\" == $mk_pat ]]" && bad "makepkg pattern would accept the round-2 bug" || ok "round-2 raw-hex pkgrel rejected by makepkg's pattern"; : "$rel"; unset rel; fi

[ "$have_lint" = 1 ] && ok "cross-checked against makepkg's own lint_pkgbuild/pkgrel.sh pattern" || echo "  note: makepkg not installed — regex-only (makepkg run proven live on bella, Packager TEST)"
[ "$fail" = 0 ] && echo "build-repo-pkgrel: ok"
exit "$fail"
