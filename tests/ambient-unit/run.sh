#!/usr/bin/env bash
# ci: fast
# ambient-unit: the daemon's Upholds= re-starts openjawz-ambient.service after every daemon restart; `ambient ensure`
#   calls the model, so an always-failing ensure must NOT be retried forever. round-3 added a StartLimit cap (Operator
#   round-4 verified the unit structurally — a live crash-loop needs systemd PID-1, unreachable without --privileged).
#   This test asserts the retry cap is present, in [Unit] (systemd only honours StartLimit* there, not [Service]),
#   and numeric — and that the matching TimeoutStartSec covers ensure's stated 110 s worst case.
set -uo pipefail
cd "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)" || exit 1
u=daemon/openjawz-ambient.service
fail=0; ok() { echo "  ok   $*"; }; bad() { echo "  FAIL $*"; fail=1; }
[ -f "$u" ] || { echo "FAIL $u missing"; exit 1; }

# StartLimit* must sit in [Unit], not [Service] — systemd silently ignores them elsewhere
unit_section="$(awk '/^\[Unit\]/{f=1;next} /^\[/{f=0} f' "$u")"
svc_section="$(awk '/^\[Service\]/{f=1;next} /^\[/{f=0} f' "$u")"

iv="$(grep -oE '^StartLimitIntervalSec=[0-9]+' <<<"$unit_section" | cut -d= -f2)"
bu="$(grep -oE '^StartLimitBurst=[0-9]+' <<<"$unit_section" | cut -d= -f2)"
[ -n "$iv" ] && ok "StartLimitIntervalSec=$iv present in [Unit]" || bad "no numeric StartLimitIntervalSec in [Unit]"
[ -n "$bu" ] && ok "StartLimitBurst=$bu present in [Unit]" || bad "no numeric StartLimitBurst in [Unit]"
{ [ -n "$iv" ] && [ "$iv" -gt 0 ]; } && ok "interval is a real window (>0), so the burst cap actually bites" || bad "StartLimitIntervalSec must be >0 for the cap to engage"
{ [ -n "$bu" ] && [ "$bu" -ge 1 ]; } && ok "burst is a finite cap (>=1)" || bad "StartLimitBurst must be a finite retry cap"
grep -q 'StartLimit' <<<"$svc_section" && bad "StartLimit* found in [Service] (systemd ignores it there)" || ok "no misplaced StartLimit* in [Service]"

# the re-ensure chain the cap protects must exist (BindsTo/PartOf), else the cap guards nothing
grep -q '^BindsTo=synaps-daemon.service' <<<"$unit_section" && ok "BindsTo=synaps-daemon.service (dies with the daemon)" || bad "no BindsTo= — the Upholds re-ensure chain is broken"
grep -q '^PartOf=synaps-daemon.service' <<<"$unit_section" && ok "PartOf=synaps-daemon.service" || bad "no PartOf="

# TimeoutStartSec must cover ensure's declared 110 s worst case, or the cap fires on false timeouts
ts="$(grep -oE '^TimeoutStartSec=[0-9]+' "$u" | cut -d= -f2)"
{ [ -n "$ts" ] && [ "$ts" -ge 110 ]; } && ok "TimeoutStartSec=$ts covers ensure's 110 s worst case" || bad "TimeoutStartSec ($ts) < 110 s ensure worst case"

[ "$fail" = 0 ] && echo "ambient-unit: ok"
exit "$fail"
