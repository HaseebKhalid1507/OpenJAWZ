#!/usr/bin/env bash
# driver.sh: runs INSIDE the container as PID-1's oneshot. Prepares, builds, boots, asserts. Writes /work/result.
set -uo pipefail
P="$(cat /work/profile 2>/dev/null || echo desktop)"
step() { echo; echo "## $* ($(date +%T))"; }
finish() { chmod -R a+rwX /work 2>/dev/null; echo "$1" > /work/result; exit 0; }
step prepare
pacman -Syu --noconfirm --needed dbus sudo base-devel git >/dev/null || finish "prepare-failed"
systemctl start dbus
id tester >/dev/null 2>&1 || useradd -m -G wheel tester
echo "%wheel ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheel
loginctl enable-linger tester
for _ in $(seq 30); do systemctl is-active user@1000.service >/dev/null 2>&1 && break; sleep 1; done
[ -s /work/os-release ] && cp /work/os-release /etc/os-release
mkdir -p /repo && chown tester /repo
rm -rf /tmp/src; cp -a /work/src /tmp/src && chown -R tester /tmp/src
step "build (negative: no SYNAPS_TARBALL must fail)"
neg=0
if runuser -u tester -- env HOME=/home/tester SYNAPS_TARBALL= /tmp/src/packages/build-repo.sh --no-sign --out /repo-neg --src /tmp/src >/work/build-neg.log 2>&1; then
  echo "  FAIL A7 build-repo.sh succeeded without synaps-bin"; neg=1
else echo "  ok   A7 build-repo.sh refuses to publish without synaps-bin"; fi
rm -rf /repo-neg /tmp/src/packages/*/pkg /tmp/src/packages/*/src
step build
st=$(ls /work/dist/synaps-*.tar.gz 2>/dev/null | head -1); ax=$(ls /work/dist/axel-*.tar.gz 2>/dev/null | head -1)
runuser -u tester -- env HOME=/home/tester ${st:+SYNAPS_TARBALL=$st} ${ax:+AXEL_TARBALL=$ax} \
  /tmp/src/packages/build-repo.sh --no-sign --out /repo --src /tmp/src 2>&1 | grep -E "^(== |!!|--|repo:|throwaway|==> ERROR)"
ls /repo/*.pkg.tar.zst >/dev/null 2>&1 || finish "build-failed"
# repo2: same tree, pkgrel bumped — the target of the update leg (A2)
rm -rf /tmp/src2; cp -a /tmp/src /tmp/src2; sed -i 's/^pkgrel=1$/pkgrel=2/' /tmp/src2/packages/openjawz/PKGBUILD; chown -R tester /tmp/src2
mkdir -p /repo2 && chown tester /repo2
runuser -u tester -- env HOME=/home/tester ${st:+SYNAPS_TARBALL=$st} ${ax:+AXEL_TARBALL=$ax} \
  /tmp/src2/packages/build-repo.sh --no-sign --out /repo2 --src /tmp/src2 2>&1 | grep -E "^(!!|repo:)"
# the shared pkgcache is for distro packages only: our own names from an earlier run (possibly with a
# throwaway .sig beside them) would be picked over the freshly built bytes (A8 cache poisoning)
rm -f /var/cache/pacman/pkg/openjawz-* /var/cache/pacman/pkg/synaps-bin-* /var/cache/pacman/pkg/axel-bin-*
step "boot negatives (A1)"
cp /etc/pacman.conf /work/pacman.conf.before
mkdir -p /empty; chmod 755 /empty
runuser -u tester -- env HOME=/home/tester XDG_RUNTIME_DIR=/run/user/1000 OPENJAWZ_YES=1 sh /tmp/src/boot --local /empty >/work/boot-empty.log 2>&1 && { echo "  FAIL A1 boot --local /empty succeeded"; neg=1; } || echo "  ok   A1 boot --local /empty refused: $(tail -1 /work/boot-empty.log)"
pacman -Sy >/dev/null 2>&1 && echo "  ok   A1 pacman -Sy still works after the refused local boot" || { echo "  FAIL A1 pacman -Sy broken after the refused local boot"; neg=1; }
cp /etc/hosts /work/hosts.bak; echo "127.0.0.1 github.com" >> /etc/hosts
runuser -u tester -- env HOME=/home/tester XDG_RUNTIME_DIR=/run/user/1000 OPENJAWZ_YES=1 sh /tmp/src/boot >/work/boot-public.log 2>&1 && { echo "  FAIL A1 public boot succeeded against a dead host"; neg=1; } || echo "  ok   A1 public boot refused: $(tail -1 /work/boot-public.log)"
cat /work/hosts.bak > /etc/hosts
cmp -s /etc/pacman.conf /work/pacman.conf.before && [ ! -e /etc/pacman.d/openjawz.conf ] && echo "  ok   A1 /etc/pacman.conf byte-identical, no openjawz.conf" || { echo "  FAIL A1 public-path failure left /etc changed"; neg=1; }
runuser -u tester -- sh /tmp/src/boot --help >/dev/null 2>&1 && echo "  ok   A1 boot --help rc 0" || { echo "  FAIL A1 boot --help rc≠0"; neg=1; }
step "boot --local ($P)  [clock starts]"
T0=$(date +%s); echo "$T0" > /work/t0
runuser -u tester -- env HOME=/home/tester XDG_RUNTIME_DIR=/run/user/1000 OPENJAWZ_YES=1 OPENJAWZ_PROFILE="$P" sh /tmp/src/boot --local /repo 2>&1 | tee /work/boot.log
rc=${PIPESTATUS[0]}
grep -q 'synaps --attach' /work/boot.log && echo "  ok   A12 closing line says synaps --attach" || { echo "  FAIL A12 closing line lacks 'synaps --attach'"; neg=1; }
T1=$(date +%s); echo "$T1" > /work/t1
step assert
runuser -u tester -- env HOME=/home/tester XDG_RUNTIME_DIR=/run/user/1000 bash /work/assert.sh "$P"; arc=$?
[ "$neg" = 0 ] || { echo "  negatives failed (see above)"; arc=1; }
echo "boot=$rc assert=$arc seconds=$((T1-T0))" > /work/summary
step "verbatim README recipe (A/Stranger blocker guard)"
# runs the README local-mode recipe EXACTLY as printed (flags parsed from README.md) in a fresh tree copy — a signed
# build under boot's TrustAll mount would die at `pacman -Sy`. This is the leg that was missing when the README said
# `--throwaway` but the smoke used `--no-sign`, so the printed command was never exercised end-to-end.
runuser -u tester -- env HOME=/home/tester XDG_RUNTIME_DIR=/run/user/1000 VERBATIM_SRC=/tmp/src \
  bash /work/verbatim-readme.sh "$st" "$ax" | tee /work/verbatim.log
grep -q 'verbatim-readme: fail=0' /work/verbatim.log || { echo "  verbatim README recipe FAILED"; arc=1; }
echo "boot=$rc assert=$arc seconds=$((T1-T0))" > /work/summary
[ -f /work/keep ] && step "kept alive for uninstall-clean" && runuser -u tester -- env HOME=/home/tester XDG_RUNTIME_DIR=/run/user/1000 bash /work/uninstall-clean.sh > /work/uninstall.log 2>&1
finish "done"
