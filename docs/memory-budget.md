# Memory budget

Numbers from the Synaps daemon-mode work, measured on a 24-core Linux box with `THP=[always]`, release builds, median of 3. Scripts to reproduce live in `tests/memprof/` (ported from the Synaps repo).

| | per additional session |
|---|---:|
| engine per terminal, lean plugin set | 40.8 MB |
| engine per terminal, real plugin set (9 sidecars) | ~260 MB |
| daemon + thin client | **~2–3 MB** |
| parked session (daemon-side) | ~2 MB |

Client: 2.3 MB idle, 3 threads, first frame under 10 ms, bounded against session length. One rendered code block costs ~11 MB of compiled syntax grammars until idle eviction (120 s) — stated, not hidden.

Gates are CI. If a change moves a number, the change carries the new number.

## Hooks — idle cost

The desktop profile runs five bridges (`docs/hooks.md`). Measured on the build box, bridge process
tree idle for 4 s after arming; PSS is the honest number (the bash/libc pages are shared with every
other shell on the box), RSS is the pessimistic sum.

| bridge | processes | idle RSS (sum) | idle PSS |
|---|---|---:|---:|
| desktop (Hyprland) | bash + socat | 10.6 MB | 1.8 MB |
| fs (2 586 dirs) | bash + inotifywait | 11.8 MB | 3.2 MB |
| notify | bash ×2 + dbus-monitor + awk | 18.7 MB | 2.4 MB |
| system | bash ×2 + dbus-monitor + awk | 18.7 MB | 2.2 MB |
| chronos | timer | 0 | 0 |
| **all five** | | 60 MB | **≈ 10 MB** |

Budget: **≤ 25 MB PSS** for the whole hook set. A bridge that needs more than 8 MB PSS on its own
does not ship. Wake cost is the runtime's: a parked session comes back in ~50 ms and one auto-turn
runs per event burst (`events.auto_turn_cap`).
