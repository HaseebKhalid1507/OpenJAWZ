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
