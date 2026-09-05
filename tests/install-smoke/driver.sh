#!/usr/bin/env bash
# driver.sh: runs INSIDE the container as PID-1's oneshot. Prepares, builds, boots, asserts. Writes /work/result.
set -uo pipefail
P="$(cat /work/profile 2>/dev/null || echo desktop)"
step() { echo; echo "## $* ($(date +%T))"; }
finish() { echo "$1" > /work/result; exit 0; }
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
step build
st=$(ls /work/dist/synaps-*.tar.gz 2>/dev/null | head -1); ax=$(ls /work/dist/axel-*.tar.gz 2>/dev/null | head -1)
runuser -u tester -- env HOME=/home/tester ${st:+SYNAPS_TARBALL=$st} ${ax:+AXEL_TARBALL=$ax} \
  /tmp/src/packages/build-repo.sh --no-sign --out /repo --src /tmp/src 2>&1 | tail -12
ls /repo/*.pkg.tar.zst >/dev/null 2>&1 || finish "build-failed"
step "boot --local ($P)  [clock starts]"
T0=$(date +%s); echo "$T0" > /work/t0
runuser -u tester -- env HOME=/home/tester XDG_RUNTIME_DIR=/run/user/1000 OPENJAWZ_YES=1 OPENJAWZ_PROFILE="$P" sh /tmp/src/boot --local /repo
rc=$?
T1=$(date +%s); echo "$T1" > /work/t1
step assert
runuser -u tester -- env HOME=/home/tester XDG_RUNTIME_DIR=/run/user/1000 bash /work/assert.sh "$P"; arc=$?
echo "boot=$rc assert=$arc seconds=$((T1-T0))" > /work/summary
[ -f /work/keep ] && step "kept alive for uninstall-clean" && runuser -u tester -- env HOME=/home/tester XDG_RUNTIME_DIR=/run/user/1000 bash /work/uninstall-clean.sh > /work/uninstall.log 2>&1
finish "done"
