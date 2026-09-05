# install-smoke

Boots systemd inside `archlinux:latest`, builds the packages from the checked-out commit into a local `file://` repo, runs `boot --local`, asserts (`assert.sh`), and prints the clock.

## The container incantation — read before changing

```
docker run -d --name oj-smoke \
  --privileged --cgroupns=private --cgroup-parent=oj-smoke.slice \
  --tmpfs /run --tmpfs /run/lock --tmpfs /tmp --stop-timeout 10 \
  -v $work:/work -v $work/units:/etc/systemd/system \
  archlinux:latest /usr/lib/systemd/systemd --system
```

and then **no `docker exec`, ever**: the test is driven by `oj-smoke.service` (a oneshot unit bind-mounted in via `/etc/systemd/system`) which runs `driver.sh`, and the host only tails `$work/driver.log` and waits for `$work/result`.

**Never** `--cgroupns=host` and **never** bind-mount the host's `/sys/fs/cgroup` rw. That puts a second systemd on the *host's* cgroup tree: the host journal fills with `Couldn't move process to requested cgroup`, the host's session scopes get deactivated and a live desktop session can die. On cgroup v2 a private cgroup namespace plus the container's own (rw) cgroup mount is all systemd needs; `--privileged` is required for that mount to be rw (with only `--cap-add SYS_ADMIN` it is ro and systemd exits silently — verified). `docker exec` is banned because every exec'd process is placed in the scope's root cgroup, which the inner systemd has already split into children: the host logs `Couldn't move process … Device or resource busy` per exec (verified: 0 with no exec, 4 with 4 execs). `--cgroup-parent=oj-smoke.slice` keeps everything it does under one host slice; `--stop-timeout 10` + the `trap` in `run.sh` guarantee the container is removed.

Host-side check after starting (both must hold): `journalctl -b --since "30 sec ago" | grep -c "Couldn't move"` → `0`, and `loginctl list-sessions` unchanged.

## Run

```
SYNAPS_TARBALL=~/dist/synaps-v0.9.1rc1-x86_64-unknown-linux-gnu.tar.gz [AXEL_TARBALL=…] tests/install-smoke/run.sh [desktop|vm]
```
`KEEP=1` leaves the container for `tests/uninstall-clean/run.sh`. Image pull and package build are outside the clock; `boot --local` → assert is inside it (< 600 s).
