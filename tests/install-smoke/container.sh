#!/usr/bin/env bash
# container.sh: start a privileged archlinux:latest with systemd, prepare a tester user, build the packages from /work/src into /repo
# usage: container.sh <name> <workdir-on-host>   (workdir has src/ and dist/)
set -euo pipefail
name="$1"; work="$2"
image="${OPENJAWZ_SMOKE_IMAGE:-archlinux:latest}"
docker rm -f "$name" >/dev/null 2>&1 || true
mkdir -p "$HOME/pkgcache"
# SAFE INCANTATION — see README.md. Never --cgroupns=host, never bind the host /sys/fs/cgroup:
# a second systemd on the host cgroup tree wrecks the host's session scopes.
docker run -d --name "$name" \
  --cgroupns=private --cgroup-parent=oj-smoke.slice \
  --cap-add SYS_ADMIN --security-opt seccomp=unconfined --security-opt apparmor=unconfined \
  --tmpfs /run --tmpfs /run/lock --tmpfs /tmp \
  --stop-timeout 10 \
  -v "$work:/work" -v "$HOME/pkgcache:/var/cache/pacman/pkg" \
  "$image" /usr/lib/systemd/systemd --system >/dev/null
for _ in $(seq 60); do docker exec "$name" systemctl is-system-running 2>/dev/null | grep -Eq 'running|degraded' && break; sleep 1; done
docker exec "$name" bash -euo pipefail -c '
  pacman -Syu --noconfirm --needed dbus sudo base-devel git >/dev/null
  systemctl start dbus
  id tester >/dev/null 2>&1 || useradd -m -G wheel tester
  echo "%wheel ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheel
  loginctl enable-linger tester
  for _ in $(seq 30); do systemctl is-active user@1000.service >/dev/null 2>&1 && break; sleep 1; done
  [ -n "${OPENJAWZ_OSRELEASE:-}" ] && printf "%s\n" "$OPENJAWZ_OSRELEASE" > /etc/os-release
  mkdir -p /repo && chown tester /repo
  rm -rf /tmp/src; cp -a /work/src /tmp/src && chown -R tester /tmp/src
  st=$(ls /work/dist/synaps-*.tar.gz 2>/dev/null | head -1); ax=$(ls /work/dist/axel-*.tar.gz 2>/dev/null | head -1)
  runuser -u tester -- env HOME=/home/tester ${st:+SYNAPS_TARBALL=$st} ${ax:+AXEL_TARBALL=$ax} \
    /tmp/src/packages/build-repo.sh --no-sign --out /repo --src /tmp/src 2>&1 | tail -15
  echo "container ready"
'
