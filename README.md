# OpenJAWZ

**An agent that lives in your OS, not in a terminal tab.**

OpenJAWZ is the operating layer on top of the [Synaps](https://github.com/HaseebKhalid1507/SynapsCLI) runtime: one daemon per user that owns your sessions, your memory, and your tools — and a 2 MB client you can open from any terminal, any screen, any machine.

Close the laptop mid-task. Open it on the desktop. Same session, same context, ~50 ms to resume. Every terminal is a window into one running mind.

## The 10-minute promise

```sh
curl -fsSL https://openjawz.dev/boot | bash
```

Arch-based Linux (Arch, CachyOS, EndeavourOS, …). Installs a package, not a distro. Never touches your bootloader or display manager.

When it's done you have:

- **a daemon** — `synaps daemon`, socket-activated, idle-exits, comes back on demand
- **a brain** — persistent memory with provenance, one writer, every session reads it
- **a crew** — planner / implementer / reviewer / tester agents with a build discipline that measures before it designs
- **hooks** — your desktop, filesystem, notifications, and clock all feed an always-on session that costs 2 MB while nothing is happening
- **an identity** — yours, from a template. Tell it your name and what you do.

## Why a daemon

Every agent CLI you've used spawns a full engine, its own memory, and its own sidecar processes per terminal. On a real machine that's 40–260 MB *per open terminal*, and it all dies when the terminal does.

| | per additional terminal |
|---|---:|
| engine-per-terminal | 40–260 MB |
| OpenJAWZ (`synaps --attach --new`) | **~2 MB** |

Measured, reproducible — the scripts are in `tests/memprof/`. The numbers come from the Synaps daemon-mode work: sessions that park when nobody's watching, an extension host that runs once, a client with the engine removed.

## The spectrum

| where | what runs there |
|---|---|
| desktop | daemon + everything, desktop hooks, bar widget |
| laptop | same, sessions park on lid-close |
| cyberdeck | **client only** — 2 MB, daemon on your desktop over Tailscale |
| VM / server | the daemon *is* the machine's agent; a browser is a client |

Same binary. Same brain. Two windows into one mind.

## Layout

```
packages/   PKGBUILDs — the product; everything else is source for these
daemon/     systemd user unit, socket activation, profiles (desktop/laptop/deck/vm)
hooks/      desktop / fs / notify / chronos / net → `synaps send` → the ambient session
crew/       agents, the subagent preamble, playbooks
ops/        skills, tools, and the SOUL / OP / AGENTS templates
brain/      memory config and policy
ui/         hotkey, bar widget, themes
deck/       the client-only profile and aarch64 notes
migrations/ timestamped, run in order by `openjawz update` — from commit one
docs/       architecture, spectrum, memory budget
tests/      install-smoke (fresh container → 10 minutes → attached), hooks, memprof gates
```

No Rust here. If the runtime needs to change, that's a PR to Synaps.

## Status

Skeleton. The daemon, parking, attach, thin client, and memory numbers exist and are measured in the Synaps repo. This repo is where they become an install.

## License

MIT.
