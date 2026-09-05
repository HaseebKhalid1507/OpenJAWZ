# shellcheck shell=bash
# /usr/lib/openjawz/hooks/bridge.sh — sourced by every OpenJAWZ bridge.
#
# One delivery path. A bridge shapes an OS event into ONE line and calls
# bridge::event; nothing else in hooks/ talks to `synaps send`.
#
#   bridge::init NAME              # source lib, paths, traps, OJ_CMD; NAME = source (desktop|fs|notify|system|chronos|ui|test)
#   bridge::event CT SEV k=v …     # "focus: class=foot title=nvim" → bridge::emit
#   bridge::emit  CT SEV TEXT      # coalesce + rate-limit + paused-flag + synaps send --session ambient (+ one re-ensure on inbox)
#   bridge::paused                 # 0 when $OPENJAWZ_RUN/hooks.paused exists and has not expired
#   bridge::json_escape STR        # → oj::json_escape
#   bridge::skip MSG               # precondition absent: log + exit 0 (the unit stays "inactive", not "failed")
#
# Tunables (env, all optional):
#   OPENJAWZ_HOOK_COALESCE_MS   drop identical (ct,text) within this window   (300)
#   OPENJAWZ_HOOK_RATE          max events per minute per bridge, rest dropped (60)
#   OPENJAWZ_HOOK_MAX_BYTES     text cap                                        (512)
#   OPENJAWZ_HOOK_DRY=1         print instead of send (tests, memprof)

# shellcheck disable=SC2034  # exported state read by bridges
set -euo pipefail

_bridge_lib=${OPENJAWZ_LIB:-/usr/lib/openjawz}/openjawz.sh
if [ ! -r "$_bridge_lib" ]; then
  # dev tree: hooks/lib/bridge.sh → ../../lib/openjawz.sh
  _bridge_lib=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/lib/openjawz.sh
fi
# shellcheck source=/dev/null
. "$_bridge_lib"
oj::paths

BRIDGE_NAME=${BRIDGE_NAME:-}
_bridge_last_key=
_bridge_last_ms=0
_bridge_min_start=0
_bridge_min_count=0
_bridge_dropped=0
_bridge_reensured=0

bridge::now_ms() { local t=${EPOCHREALTIME/./}; printf '%s' "${t:0:-3}"; }

bridge::init() {
  BRIDGE_NAME=$1
  export OJ_CMD="hook-$BRIDGE_NAME"
  mkdir -p "$OPENJAWZ_RUN" 2>/dev/null || true
  trap 'bridge::_exit' EXIT
  trap 'exit 0' TERM INT
}

bridge::_exit() {
  [ "$_bridge_dropped" -gt 0 ] && oj::log info "$BRIDGE_NAME: dropped $_bridge_dropped events (coalesced/rate-limited)"
  return 0
}

bridge::skip() { oj::log info "$BRIDGE_NAME: $*; nothing to do"; exit 0; }

bridge::json_escape() { oj::json_escape "$1"; }

bridge::paused() {
  local f=$OPENJAWZ_RUN/hooks.paused until
  [ -e "$f" ] || return 1
  until=$(cat "$f" 2>/dev/null || echo 0)
  if [ "${until:-0}" -gt 0 ] 2>/dev/null && [ "$until" -le "$(date +%s)" ]; then
    rm -f "$f"; return 1
  fi
  return 0
}

# bridge::event CT SEV key=val …  → text "CT: key=val key=val"
bridge::event() {
  local ct=$1 sev=$2; shift 2
  local text="$ct:" kv
  for kv in "$@"; do
    kv=${kv//$'\n'/ }; kv=${kv//$'\r'/}
    text+=" $kv"
  done
  bridge::emit "$ct" "$sev" "$text"
}

bridge::emit() {
  local ct=$1 sev=$2 text=$3 now key max=${OPENJAWZ_HOOK_MAX_BYTES:-512}
  text=${text//$'\n'/ }; text=${text//$'\r'/}
  [ "${#text}" -gt "$max" ] && text=${text:0:$max}
  case $sev in low|medium|high) ;; *) sev=low ;; esac   # never critical from a hook

  bridge::paused && { _bridge_dropped=$((_bridge_dropped + 1)); return 0; }

  now=$(bridge::now_ms)
  key="$ct|$text"
  if [ "$key" = "$_bridge_last_key" ] && [ $((now - _bridge_last_ms)) -lt "${OPENJAWZ_HOOK_COALESCE_MS:-300}" ]; then
    _bridge_last_ms=$now; _bridge_dropped=$((_bridge_dropped + 1)); return 0
  fi
  _bridge_last_key=$key; _bridge_last_ms=$now

  if [ $((now - _bridge_min_start)) -ge 60000 ]; then _bridge_min_start=$now; _bridge_min_count=0; fi
  _bridge_min_count=$((_bridge_min_count + 1))
  if [ "$_bridge_min_count" -gt "${OPENJAWZ_HOOK_RATE:-60}" ]; then
    [ "$_bridge_min_count" -eq $(( ${OPENJAWZ_HOOK_RATE:-60} + 1 )) ] && oj::log warn "$BRIDGE_NAME: rate limit hit (${OPENJAWZ_HOOK_RATE:-60}/min); dropping until the window resets"
    _bridge_dropped=$((_bridge_dropped + 1)); return 0
  fi

  if [ "${OPENJAWZ_HOOK_DRY:-0}" = 1 ]; then
    printf '%s %s %s %s\n' "$BRIDGE_NAME" "$ct" "$sev" "$text"; return 0
  fi

  if bridge::_send "$ct" "$sev" "$text"; then return 0; fi
  # inbox fallback = the ambient session is gone (cold start). Re-ensure once, retry once.
  if [ "$_bridge_reensured" -eq 0 ] && oj::have openjawz; then
    _bridge_reensured=1
    oj::log warn "$BRIDGE_NAME: delivery fell to inbox; re-ensuring the ambient session"
    if openjawz ambient ensure >/dev/null 2>&1 && bridge::_send "$ct" "$sev" "$text"; then
      _bridge_reensured=0; return 0
    fi
  fi
  _bridge_dropped=$((_bridge_dropped + 1))
  return 0
}

# THE delivery leg. Target is the session NAME (runtime resolves names at create since
# integration@07007af7); OPENJAWZ_AMBIENT overrides (tests). Never --broadcast, never omit --session.
# Exit 0 from `send` also covers the inbox fallback — stderr is the truth.
bridge::_send() {
  local ct=$1 sev=$2 text=$3 err
  err=$(synaps send --session "${OPENJAWZ_AMBIENT:-ambient}" --source "$BRIDGE_NAME" \
          --content-type "$ct" --severity "$sev" -- "$text" 2>&1 >/dev/null) || true
  case $err in
    *inbox*|*"No session"*|*"no daemon"*|*"daemon unavailable"*) oj::log warn "$BRIDGE_NAME: $err"; return 1 ;;
  esac
  return 0
}

