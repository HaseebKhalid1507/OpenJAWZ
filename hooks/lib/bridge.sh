# shellcheck shell=bash
# /usr/lib/openjawz/hooks/bridge.sh — sourced by every OpenJAWZ bridge.
#
# One delivery path. A bridge shapes an OS event into ONE line and calls
# bridge::event; delivery is `oj::send` (lib/openjawz.sh) — the only `synaps send` in the tree.
# The hook pipeline is a GOVERNED INGRESS: every line passes bridge::redact before anything else.
#
#   bridge::init NAME              # source lib, paths, traps, OJ_CMD; NAME = source (desktop|fs|notify|system|chronos|ui|test)
#   bridge::event CT SEV k=v …     # "focus: class=foot title=nvim" → bridge::emit
#   bridge::emit  CT SEV TEXT      # redact + coalesce + rate-limit + paused-flag + oj::send (+ re-ensure on inbox)
#   bridge::redact TEXT [CT]       # secret-shaped → "[redacted: secret-shaped] (…)"; prints the (possibly replaced) text
#   bridge::secret_shaped TEXT     # 0 when TEXT matches secret-patterns.txt / redact.list / the OTP built-ins
#   bridge::listed FILE VALUE      # 0 when VALUE matches a line of FILE (case-insensitive, glob or plain)
#   bridge::share_file NAME        # $OPENJAWZ_SHARE/hooks/NAME, or the dev-tree copy
#   bridge::cfg KEY [DEFAULT]      # flat "key = value" from $SYNAPS_BASE_DIR/config
#   bridge::paused                 # 0 when $OPENJAWZ_RUN/hooks.paused exists and has not expired
#   bridge::json_escape STR        # → oj::json_escape
#   bridge::skip MSG               # precondition absent: log + exit 0 (the unit stays "inactive", not "failed")
#
# Tunables (env, all optional):
#   OPENJAWZ_HOOK_COALESCE_MS   drop identical (ct,text) within this window   (300)
#   OPENJAWZ_HOOK_RATE          max events per minute per bridge, rest dropped (60)
#   OPENJAWZ_HOOK_MAX_BYTES     text cap                                        (512)
#   OPENJAWZ_HOOK_REDACT_LIST   extra grep -E patterns, one per line            (hooks/redact.list)
#   OPENJAWZ_HOOK_REDACT=0      kill-switch for the content filter (NOT recommended)
#   OPENJAWZ_HOOK_DRY=1         print instead of send (tests, memprof)
#   OPENJAWZ_HOOK_BYPASS_PAUSE=1  a human command (`ambient send`) is not a hook: ignore hooks.paused

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

_bridge_tree=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)   # dev tree: hooks/
BRIDGE_NAME=${BRIDGE_NAME:-}
_bridge_last_key=
_bridge_last_ms=0
_bridge_min_start=0
_bridge_min_count=0
_bridge_dropped=0
_bridge_paused=0
_bridge_redacted=0
_bridge_reensured_ms=0
_bridge_secret_re=

bridge::now_ms() { local t=${EPOCHREALTIME/./}; printf '%s' "${t:0:-3}"; }

bridge::init() {
  BRIDGE_NAME=$1
  export OJ_CMD="hook-$BRIDGE_NAME"
  mkdir -p "$OPENJAWZ_RUN" 2>/dev/null || true
  trap 'bridge::_exit' EXIT
  trap 'exit 0' TERM INT
}

bridge::_exit() {
  [ "$_bridge_dropped" -gt 0 ] && oj::log info "$BRIDGE_NAME: dropped $_bridge_dropped events (coalesced/rate-limited/undeliverable)"
  [ "$_bridge_paused" -gt 0 ] && oj::log info "$BRIDGE_NAME: dropped $_bridge_paused events (paused)"
  [ "$_bridge_redacted" -gt 0 ] && oj::log info "$BRIDGE_NAME: redacted $_bridge_redacted events"
  return 0
}

bridge::skip() { oj::log info "$BRIDGE_NAME: $*; nothing to do"; exit 0; }

bridge::json_escape() { oj::json_escape "$1"; }

# $OPENJAWZ_SHARE/hooks/NAME (installed) or hooks/**/NAME (dev tree); empty when neither exists
bridge::share_file() {
  local n=$1 f
  for f in "$OPENJAWZ_SHARE/hooks/$n" "$_bridge_tree/$n" "$_bridge_tree/notify/$n" "$_bridge_tree/desktop/$n"; do
    [ -r "$f" ] && { printf '%s\n' "$f"; return 0; }
  done
  return 1
}

# flat `key = value` config (~/.synaps-cli/config); env wins nowhere here — callers check env first
bridge::cfg() {
  local key=$1 def=${2:-} f=$SYNAPS_BASE_DIR/config v
  if [ -r "$f" ]; then
    v=$(sed -nE "s/^[[:space:]]*${key//./\\.}[[:space:]]*=[[:space:]]*//p" "$f" | tail -1)
    v=${v%%[[:space:]]#*}; v=${v%"${v##*[![:space:]]}"}
    [ -n "$v" ] && { printf '%s\n' "$v"; return 0; }
  fi
  printf '%s\n' "$def"
}

# bridge::listed FILE VALUE — VALUE matches a non-comment line (case-insensitive; a line may be a glob)
bridge::listed() {
  local f=$1 val=$2 line
  [ -r "$f" ] && [ -n "$val" ] || return 1
  shopt -s nocasematch
  while IFS= read -r line || [ -n "$line" ]; do
    line=${line%%#*}; line=${line%"${line##*[![:space:]]}"}; line=${line#"${line%%[![:space:]]*}"}
    [ -n "$line" ] || continue
    # shellcheck disable=SC2254
    case $val in $line) shopt -u nocasematch; return 0 ;; esac
  done < "$f"
  shopt -u nocasematch
  return 1
}

# the secret shapes: the brain's list (== tests/grep-guard/secrets.txt) + hooks/redact.list + built-ins
bridge::_secret_re() {
  local f re='' line
  for f in "$OPENJAWZ_SHARE/brain/secret-patterns.txt" "$_bridge_tree/../brain/secret-patterns.txt" \
           "${OPENJAWZ_HOOK_REDACT_LIST:-$(bridge::share_file redact.list || true)}"; do
    [ -r "$f" ] || continue
    while IFS= read -r line || [ -n "$line" ]; do
      case $line in ''|'#'*) continue ;; esac
      re+="|($line)"
    done < "$f"
  done
  # built-ins: an OTP-shaped number and the words that travel with one
  re+='|(\b[0-9]{6,8}\b)|(\b[0-9]{3}[ -][0-9]{3}\b)'
  re+='|((verification|security|one-time|login|auth(entication)?|2fa|confirmation) code)|(\bOTP\b)|(\bpasscode\b)'
  printf '%s' "${re#|}"
}

# bridge::secret_shaped TEXT → 0 when the line must not reach the model
bridge::secret_shaped() {
  [ "${OPENJAWZ_HOOK_REDACT:-1}" = 0 ] && return 1
  [ -n "$_bridge_secret_re" ] || _bridge_secret_re=$(bridge::_secret_re)
  printf '%s' "$1" | grep -qiE -- "$_bridge_secret_re" 2>/dev/null
}
bridge::placeholder() { printf '[redacted: secret-shaped] (%s from %s)' "${1:-event}" "${BRIDGE_NAME:-hook}"; }
# bridge::redact TEXT [CT] → stdout: TEXT, or the placeholder when it is secret-shaped
bridge::redact() {
  if bridge::secret_shaped "$1"; then bridge::placeholder "${2:-event}"; else printf '%s' "$1"; fi
}

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

  # 1. content policy — before coalescing, before anything sees the line
  if bridge::secret_shaped "$text"; then
    text=$(bridge::placeholder "$ct")
    _bridge_redacted=$((_bridge_redacted + 1)); oj::log info "$BRIDGE_NAME: redacted 1 event ($ct)"
  fi

  # 2. the kill-switch (a human command bypasses it: OPENJAWZ_HOOK_BYPASS_PAUSE=1)
  if [ "${OPENJAWZ_HOOK_BYPASS_PAUSE:-0}" != 1 ] && bridge::paused; then
    _bridge_paused=$((_bridge_paused + 1)); return 0
  fi

  # 3. coalesce + rate cap
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

  # 4. deliver — daemon dead → ensure first (never let `send` auto-spawn an unmanaged daemon)
  if ! oj::daemon_alive; then bridge::_reensure || { _bridge_dropped=$((_bridge_dropped + 1)); return 0; }; fi
  if oj::send "$BRIDGE_NAME" "$ct" "$sev" "$text"; then return 0; fi
  # inbox / no session = the ambient session is gone (cold start, daemon restart). Re-ensure, retry once.
  if bridge::_reensure && oj::send "$BRIDGE_NAME" "$ct" "$sev" "$text"; then return 0; fi
  _bridge_dropped=$((_bridge_dropped + 1))
  return 0
}

# one `openjawz ambient ensure` per 60 s window, whatever its outcome (a stuck failure must not stick forever)
bridge::_reensure() {
  local now; now=$(bridge::now_ms)
  [ $((now - _bridge_reensured_ms)) -ge 60000 ] || return 1
  _bridge_reensured_ms=$now
  oj::have openjawz || return 1
  oj::log warn "$BRIDGE_NAME: delivery fell to inbox; re-ensuring the ambient session"
  openjawz ambient ensure >/dev/null 2>&1
}
