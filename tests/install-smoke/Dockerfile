# archlinux:latest with udev MASKED before systemd ever starts. See README.md — a container's systemd-udevd
# with broad privileges re-triggers HOST devices (/dev/dri/card* recreated, the host's display panel dies).
ARG BASE=archlinux:latest
FROM ${BASE}
RUN systemctl mask systemd-udevd.service systemd-udevd-control.socket systemd-udevd-kernel.socket \
      systemd-udev-trigger.service systemd-udev-settle.service systemd-udevd-varlink.socket systemd-modules-load.service \
      systemd-firstboot.service systemd-networkd.service systemd-resolved.service systemd-timesyncd.service \
 && rm -f /etc/systemd/system/*.wants/systemd-udev* 2>/dev/null; true
ENTRYPOINT ["/usr/lib/systemd/systemd", "--system"]
