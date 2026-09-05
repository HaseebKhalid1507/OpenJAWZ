#!/usr/bin/env bash
# container.sh: start an ISOLATED archlinux:latest with systemd that runs /work/driver.sh as a oneshot unit.
# usage: container.sh <name> <workdir-on-host>   (workdir has src/, dist/, driver.sh; results land in workdir)
# No `docker exec` — ever. See README.md.
set -euo pipefail
name="$1"; work="$2"
image="${OPENJAWZ_SMOKE_IMAGE:-archlinux:latest}"
docker rm -f "$name" >/dev/null 2>&1 || true
mkdir -p "$HOME/pkgcache"
cat > "$work/oj-smoke.service" <<'UNIT'
[Unit]
Description=OpenJAWZ install-smoke driver
After=multi-user.target
[Service]
Type=oneshot
ExecStart=/bin/bash /work/driver.sh
StandardOutput=append:/work/driver.log
StandardError=append:/work/driver.log
[Install]
WantedBy=multi-user.target
UNIT
: > "$work/driver.log"; rm -f "$work/result"
# SAFE INCANTATION — see README.md. Never --cgroupns=host, never bind the host /sys/fs/cgroup.
docker run -d --name "$name" \
  --privileged --cgroupns=private --cgroup-parent=oj-smoke.slice \
  --tmpfs /run --tmpfs /run/lock --tmpfs /tmp:exec,mode=1777 \
  --stop-timeout 10 \
  -v "$work:/work" -v "$HOME/pkgcache:/var/cache/pacman/pkg" \
  -v "$work/oj-smoke.service:/etc/systemd/system/oj-smoke.service:ro" \
  -v "$work/oj-smoke.service:/etc/systemd/system/multi-user.target.wants/oj-smoke.service:ro" \
  "$image" /usr/lib/systemd/systemd --system >/dev/null
