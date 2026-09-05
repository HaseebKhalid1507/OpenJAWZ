#!/usr/bin/env bash
# uninstall-clean.sh: runs INSIDE the smoke container as tester, after a successful install.
set -uo pipefail
fail=0; ok() { echo "  ok   $*"; }; bad() { echo "  FAIL $*"; fail=1; }
mkdir -p ~/.config/axel && touch ~/.config/axel/axel.r8 ~/.local/share/openjawz/keep-me
# A6: a bar poll must not leave __pycache__ under /usr/share/openjawz
[ -x /usr/lib/openjawz/ui/waybar-status ] && timeout 20 /usr/lib/openjawz/ui/waybar-status >/dev/null 2>&1 || true
[ "$(find /usr/share/openjawz -name __pycache__ 2>/dev/null | wc -l)" = 0 ] && ok "A6 no __pycache__ after a bar poll" || bad "A6 __pycache__ under /usr/share/openjawz: $(find /usr/share/openjawz -name __pycache__ | head -3 | tr '\n' ' ')"
[ -s ~/.local/share/openjawz/installed-files ] && ok "A6 installed-files manifest ($(wc -l < ~/.local/share/openjawz/installed-files) paths)" || bad "A6 no installed-files manifest"
openjawz uninstall --yes --keep-brain || bad "uninstall exited non-zero"
[ ! -e /var/lib/pacman/sync/openjawz.db ] && ok "A6 sync db removed" || bad "A6 /var/lib/pacman/sync/openjawz.db left"
[ -z "$(pacman -Qq | grep '^openjawz' || true)" ] && ok "no openjawz packages" || bad "packages left: $(pacman -Qq | grep openjawz | tr '\n' ' ')"
pacman -Q synaps-bin >/dev/null 2>&1 && ok "synaps-bin kept (no --all)" || bad "synaps-bin removed without --all"
[ -z "$(systemctl --user list-unit-files 'openjawz-*' 'synaps-*' --no-legend 2>/dev/null)" ] && ok "no units" || bad "units left"
[ ! -e /etc/pacman.d/openjawz.conf ] && ok "openjawz.conf gone" || bad "openjawz.conf left"
grep -q 'openjawz.conf' /etc/pacman.conf && bad "Include left in pacman.conf" || ok "Include removed"
[ -z "$(ls ~/.synaps-cli/plugins/ 2>/dev/null)" ] && ok "plugin symlinks gone" || bad "plugin symlinks left"
[ -f ~/.config/axel/axel.r8 ] && ok "brain (~/.config/axel) kept" || bad "brain removed"
[ -f ~/.local/share/openjawz/keep-me ] && ok "state kept with --keep-brain" || bad "state removed"
# --purge --all leg: reinstall from the local repo, then remove everything
marker="$(mktemp)"; sleep 1
OPENJAWZ_YES=1 sh /tmp/src/boot --local /repo > /work/reboot.log 2>&1 || bad "reinstall (boot --local) for the purge leg failed"
[ -f ~/.config/axel/axel.r8 ] && ok "A6 .r8 still there after plain uninstall + reinstall" || bad "A6 .r8 gone"
# purge without --yes and no tty must refuse (A6: README's 'asks first' is true)
openjawz uninstall --purge </dev/null >/dev/null 2>&1 && bad "A6 --purge without --yes did not ask" || ok "A6 --purge without --yes refuses (no tty)"
openjawz uninstall --yes --purge --all > /work/purge.log 2>&1 || bad "uninstall --purge --all exited non-zero"
[ ! -e ~/.local/share/openjawz ] && ok "--purge removed state" || bad "--purge left state"
[ ! -e ~/.config/axel ] && ok "A6 --purge removed ~/.config/axel" || bad "A6 --purge left ~/.config/axel"
[ ! -e ~/.synaps-cli ] && ok "A6 --purge --all removed ~/.synaps-cli" || bad "A6 --purge --all left ~/.synaps-cli: $(ls -A ~/.synaps-cli | tr '\n' ' ')"
left="$(find ~ /usr/share/openjawz /var/lib/pacman/sync -newer "$marker" -not -path "$HOME/.cache/*" -not -path "$HOME/.gnupg/*" -not -name '.bash_history' 2>/dev/null)"
[ -z "$left" ] && ok "A6 nothing newer than the marker survives --purge --all" || { bad "A6 leftovers after --purge --all:"; echo "$left" | head -20; }
grep -q '^kept:' /work/purge.log && ok "A6 kept: line printed" || bad "A6 no kept: line"
pacman -Q synaps-bin >/dev/null 2>&1 && bad "--all left synaps-bin" || ok "--all removed synaps-bin"
echo "uninstall-clean: fail=$fail"; exit "$fail"
