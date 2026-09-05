# chronos

A tiny [SynapsCLI](https://github.com/HaseebKhalid1507/SynapsCLI) extension that
injects the **current time** into the model's context before every user message.

No more *"I don't have access to the current date."* The model always knows when it is.

```
[🕐 Current time: 2026-06-15 23:46 EDT — Monday night]
```

## What it does

`chronos` subscribes to the `before_message` lifecycle hook. On every turn, it
returns an `inject` action carrying a clean, timezone-aware timestamp plus a
natural period-of-day tag (`morning` / `afternoon` / `evening` / `night` /
`late night`). The line is prepended to the model's context for that turn.

It speaks JSON-RPC 2.0 over stdio (LSP-style `Content-Length` framing) — the
standard SynapsCLI extension protocol. ~100 lines of dependency-free Python 3.

## Install

Clone and symlink into your plugins directory:

```bash
git clone https://github.com/HaseebKhalid1507/synaps-chronos synaps-chronos
ln -s synaps-chronos ~/.synaps-cli/plugins/chronos
```

It loads on the next SynapsCLI boot. Requires `python3` (no third-party deps).

## How it works

| JSON-RPC method | chronos response |
|---|---|
| `initialize` | `{"protocol_version": 1, "capabilities": {}}` |
| `hook.handle` (`kind: before_message`) | `{"action": "inject", "content": "[🕐 …]"}` |
| `shutdown` | `null` |

The manifest at `.synaps-plugin/plugin.json` declares a `process` runtime, the
`privacy.llm_content` permission (it writes into LLM context), and a single
`before_message` hook subscription.

## Customize

The injected string is built in `time_line()` — extend it to add anything the
`before_message` hook can compute: git branch, uptime, system load, days since
last session. The hook can run arbitrary logic; the clock is just the simplest
useful thing to inject.

## License

MIT
