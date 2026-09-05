#!/usr/bin/env bash
# uninstall-clean.sh: runs INSIDE the smoke container as tester, after a successful install.
set -uo pipefail
fail=0; ok() { echo "  ok   $*"; }; bad() { echo "  FAIL $*"; fail=1; }
mkdir -p ~/.config/axel && touch ~/.config/axel/axel.r8 ~/.local/share/openjawz/keep-me
openjawz uninstall --yes --keep-brain || bad "uninstall exited non-zero"
[ -z "$(pacman -Qq | grep '^openjawz' || true)" ] && ok "no openjawz packages" || bad "packages left: $(pacman -Qq | grep openjawz | tr '\n' ' ')"
pacman -Q synaps-bin >/dev/null 2>&1 && ok "synaps-bin kept (no --all)" || bad "synaps-bin removed without --all"
[ -z "$(systemctl --user list-unit-files 'openjawz-*' 'synaps-*' --no-legend 2>/dev/null)" ] && ok "no units" || bad "units left"
[ ! -e /etc/pacman.d/openjawz.conf ] && ok "openjawz.conf gone" || bad "openjawz.conf left"
grep -q 'openjawz.conf' /etc/pacman.conf && bad "Include left in pacman.conf" || ok "Include removed"
[ -z "$(ls ~/.synaps-cli/plugins/ 2>/dev/null)" ] && ok "plugin symlinks gone" || bad "plugin symlinks left"
[ -f ~/.config/axel/axel.r8 ] && ok "brain (~/.config/axel) kept" || bad "brain removed"
[ -f ~/.local/share/openjawz/keep-me ] && ok "state kept with --keep-brain" || bad "state removed"
openjawz uninstall --yes --purge >/dev/null 2>&1 || true
[ ! -e ~/.local/share/openjawz ] && ok "--purge removed state" || bad "--purge left state"
echo "uninstall-clean: fail=$fail"; exit "$fail"
