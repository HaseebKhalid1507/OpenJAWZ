# Architecture

Seven layers, bottom up. Each maps to one directory.

1. **Base** — an Arch-based Linux. Not ours. We install a package onto it.
2. **Runtime** — [Synaps](https://github.com/HaseebKhalid1507/SynapsCLI): the engine, the daemon, the session model (attach / detach / park / reload), the extension host, the thin client. Pinned as `synaps-bin`.
3. **Daemon as a service** — `daemon/`: a socket-activated user unit. Exists at login, spawns on first connect, idle-exits, never aborts a running turn. One per user.
4. **Sidecars** — memory (`axel`), scheduling (`chronos`), web tools, bridges: extensions of *the* daemon, started once, shared by every session. Memory is `shared: true` — one brain, one writer.
5. **Hooks** — `hooks/`: everything is `synaps send` into an **ambient session** that is parked by default and wakes on events. Desktop IPC (focus, workspace, idle), filesystem (inotify on projects and downloads), notifications (in and out), the clock (chronos as cron), the network (usb, wifi, peers).
6. **UI** — `ui/`: a global hotkey that opens a terminal running `synaps --attach --new`; a bar widget that reads `synaps daemon sessions` and `synaps status --memory`; agent notifications through the system notifier.
7. **Crew, ops, brain, identity** — `crew/ ops/ brain/`: the agents, the discipline (boot briefing, checkpoint, handoff, shutdown, sacred files), the memory policy, and the SOUL / OP / AGENTS **templates** the installer fills. The identity is the user's, never ours.

## Install and update

```
curl … | bash            30 lines: verify Arch, install paru if missing, install openjawz-meta
  → openjawz-meta        PKGBUILD: synaps-bin + daemon + sidecars + hooks + crew + ops + brain + ui
  → openjawz install     staged, logged, idempotent: config → unit → hooks → crew → brain → identity form → first session
  → openjawz update      lock → snapshot → pacman -Syu → openjawz-migrate → post-update hooks → restart check
```

The script is what a stranger types. The package is the truth. `migrations/` exists from the first commit so it never has to be retrofitted.

## What stays out

- The runtime. No Rust in this repo.
- Any specific person's identity. Templates only.
- The bootloader, the display manager, the kernel. We install *onto* a desktop.
