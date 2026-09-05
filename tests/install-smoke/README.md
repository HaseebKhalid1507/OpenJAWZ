# install-smoke

Boots systemd inside an `archlinux:latest`-derived image, builds the packages from the checked-out commit into a local `file://` repo, runs `boot --local`, asserts (`assert.sh`), and prints the clock. The whole test is driven **from inside** by a oneshot unit (`driver.sh`); the host only tails a log.

## Why the container is built the way it is — read before changing anything

Two incidents shaped this. Both took down a live desktop session on the docker host.

1. **`--cgroupns=host -v /sys/fs/cgroup:/sys/fs/cgroup:rw`** (the "classic" systemd-in-docker recipe) puts a second systemd on the *host's* cgroup tree. The host journal fills with `Couldn't move process to requested cgroup`, session scopes get deactivated, the display dies. **Never.** We use `--cgroupns=private --cgroup-parent=oj-smoke.slice` and no host cgroup bind.
2. **`--privileged` alone lets the container's `systemd-udevd` re-trigger HOST devices** (regardless of cgroupns): `/dev/dri/card*` got recreated on the host and the panel died. So udev is **masked in the image layer, before systemd ever starts** (`Dockerfile`: `systemd-udevd.service`, `-control.socket`, `-kernel.socket`, `-varlink.socket`, `systemd-udev-trigger.service`, `systemd-udev-settle.service`, plus modules-load / networkd / resolved / timesyncd / firstboot).

`--privileged` is still required: with only `--cap-add SYS_ADMIN --security-opt seccomp=unconfined --security-opt apparmor=unconfined --security-opt systempaths=unconfined` (also tried with a slice bind at `/sys/fs/cgroup`) the cgroup2 mount is read-only and systemd exits 255 — verified. Hence privileged + masked udev, and the verification below is mandatory whenever this file, the Dockerfile or the flags change.

**`docker exec` is banned.** Every exec'd process lands in the scope's root cgroup, which the inner systemd has already split into children: the host logs `Couldn't move process … Device or resource busy` per exec (verified: 0 with no exec, N with N execs). The driver unit + shared workdir replace it.

The incantation (`container.sh`):

```
docker build -t oj-smoke-base --build-arg BASE=archlinux:latest tests/install-smoke   # masks udev, sets the systemd entrypoint
docker run -d --name oj-smoke \
  --privileged --cgroupns=private --cgroup-parent=oj-smoke.slice \
  --tmpfs /run --tmpfs /run/lock --tmpfs /tmp:exec,mode=1777 --stop-timeout 10 \
  -v $work:/work \
  -v $work/oj-smoke.service:/etc/systemd/system/oj-smoke.service:ro \
  -v $work/oj-smoke.service:/etc/systemd/system/multi-user.target.wants/oj-smoke.service:ro \
  oj-smoke-base
```

### Host-side verification (do it on a box whose display nobody is using)

```
ls -la --time-style=+%T /dev/dri/card*                      # before
docker run -d … oj-smoke-base ; sleep 40                     # no exec during the window
ls -la --time-style=+%T /dev/dri/card*                      # after: timestamps MUST be identical
journalctl -b --since "1 min ago" | grep -c "Couldn't move"  # MUST be 0
loginctl list-sessions                                       # unchanged
```

Run this test only on a machine nobody is sitting at. Never on a box with a live desktop session you care about.

## Run

```
SYNAPS_TARBALL=~/dist/synaps-v0.9.1rc1-x86_64-unknown-linux-gnu.tar.gz [AXEL_TARBALL=…] tests/install-smoke/run.sh [desktop|vm]
```
`KEEP=1` additionally runs `tests/uninstall-clean/uninstall-clean.sh` inside the same container and keeps the workdir. Image build and package build are outside the clock; `boot --local` → assert is inside it (< 600 s). The `trap` always removes the container.
