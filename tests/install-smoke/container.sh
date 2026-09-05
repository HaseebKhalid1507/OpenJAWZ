#!/usr/bin/env bash
# container.sh: start an ISOLATED archlinux:latest with systemd that runs /work/driver.sh as a oneshot unit.
# usage: container.sh <name> <workdir-on-host>   (workdir has src/, dist/, driver.sh; results land in workdir)
# No `docker exec` — ever. See README.md.
set -euo pipefail
name="$1"; work="$2"
base="${OPENJAWZ_SMOKE_IMAGE:-archlinux:latest}"
image="oj-smoke-base"
here="$(cd "$(dirname "$0")" && pwd)"
docker rm -f "$name" >/dev/null 2>&1 || true
mkdir -p "$HOME/pkgcache"
cat > "$work/oj-smoke.service" <<'UNIT'
[Unit]
Description=OpenJAWZ install-smoke driver
After=basic.target dbus.service
[Service]
Type=oneshot
ExecStart=/bin/bash /work/driver.sh
StandardOutput=append:/work/driver.log
StandardError=append:/work/driver.log
[Install]
WantedBy=multi-user.target
UNIT
: > "$work/driver.log"; rm -f "$work/result"
# the image layer masks udev BEFORE systemd starts (Dockerfile) — a container udevd re-triggers HOST devices
docker build -q -t "$image" --build-arg "BASE=$base" "$here" >/dev/null
# SAFE INCANTATION — see README.md. Never --cgroupns=host, never bind the host /sys/fs/cgroup, udev masked.
docker run -d --name "$name" \
  --privileged --cgroupns=private --cgroup-parent=oj-smoke.slice \
  --tmpfs /run --tmpfs /run/lock --tmpfs /tmp:exec,mode=1777 \
  --stop-timeout 10 \
  -v "$work:/work" -v "$HOME/pkgcache:/var/cache/pacman/pkg" \
  -v "$work/oj-smoke.service:/etc/systemd/system/oj-smoke.service:ro" \
  -v "$work/oj-smoke.service:/etc/systemd/system/multi-user.target.wants/oj-smoke.service:ro" \
  "$image" >/dev/null
