#!/usr/bin/env bash
# /usr/lib/openjawz/openjawz.sh — the one shared library.
# Sourced by every openjawz-* script:   . /usr/lib/openjawz/openjawz.sh
# bash >= 5. No side effects except oj::paths (exports). Never overrides env that is already set.
# shellcheck disable=SC2034

[ -n "${OJ_LIB_LOADED:-}" ] && return 0
OJ_LIB_LOADED=1

# ── paths ────────────────────────────────────────────────────────────────────
oj::paths() {
  export OPENJAWZ_SHARE="${OPENJAWZ_SHARE:-/usr/share/openjawz}"
  export OPENJAWZ_LIB="${OPENJAWZ_LIB:-/usr/lib/openjawz}"
  export OPENJAWZ_TOOLS="${OPENJAWZ_TOOLS:-$OPENJAWZ_LIB/tools}"
  export OPENJAWZ_CONFIG="${OPENJAWZ_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/openjawz}"
  export OPENJAWZ_STATE="${OPENJAWZ_STATE:-${XDG_STATE_HOME:-$HOME/.local/state}/openjawz}"
  export OPENJAWZ_HOME="${OPENJAWZ_HOME:-$HOME/.local/share/openjawz}"
  export OPENJAWZ_DATA="${OPENJAWZ_DATA:-$OPENJAWZ_HOME/data}"
  export OPENJAWZ_RUN="${OPENJAWZ_RUN:-${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/openjawz}"
  export SYNAPS_BASE_DIR="${SYNAPS_BASE_DIR:-$HOME/.synaps-cli}"
  export SYNAPS_RUN="${SYNAPS_RUNTIME_DIR:-$SYNAPS_BASE_DIR/run}"
  export OJ_CMD="${OJ_CMD:-$(basename "${BASH_SOURCE[-1]:-openjawz}")}"
  local f
  for f in "$OPENJAWZ_CONFIG/identity.env" "$OPENJAWZ_CONFIG/profile.env"; do
    [ -r "$f" ] && oj::_load_env "$f"
  done
  return 0
}

# load KEY=VALUE lines; existing env wins
oj::_load_env() {
  local line key val
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in ''|'#'*) continue ;; esac
    key="${line%%=*}"; val="${line#*=}"
    key="${key#export }"; key="${key// /}"
    [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue
    val="${val#\"}"; val="${val%\"}"
    [ -z "${!key+x}" ] && export "$key=$val"
  done < "$1"
  return 0
}

# ── logging ──────────────────────────────────────────────────────────────────
oj::_color() { [ -t 2 ] && [ -z "${NO_COLOR:-}" ]; }
oj::log() {
  local level="$1"; shift
  local msg="$*" c="" r=""
  if oj::_color; then
    r=$'\e[0m'
    case "$level" in info) c=$'\e[34m' ;; ok) c=$'\e[32m' ;; warn) c=$'\e[33m' ;; err) c=$'\e[31m' ;; esac
  fi
  printf '%s%-4s%s %s\n' "$c" "$level" "$r" "$msg" >&2
  if [ -n "${OPENJAWZ_STATE:-}" ]; then
    mkdir -p "$OPENJAWZ_STATE" 2>/dev/null &&
      printf '%s %s [%s] %s\n' "$(date -Is)" "${OJ_CMD:-openjawz}" "$level" "$msg" >> "$OPENJAWZ_STATE/openjawz.log" 2>/dev/null
  fi
  return 0
}
oj::die() { oj::log err "$1"; exit "${2:-1}"; }

# ── predicates ───────────────────────────────────────────────────────────────
oj::have() { command -v "$1" >/dev/null 2>&1; }
oj::is_arch() {
  [ -r /etc/os-release ] || return 1
  local ID="" ID_LIKE=""
  # shellcheck disable=SC1091
  . /etc/os-release
  case " $ID $ID_LIKE " in *arch*) return 0 ;; esac
  return 1
}
oj::is_root() { [ "$(id -u)" -eq 0 ]; }
oj::sudo() {
  if oj::is_root; then echo ""; return 0; fi
  if oj::have sudo; then echo sudo; elif oj::have doas; then echo doas; else oj::die "need sudo or doas"; fi
}
oj::yes() { [ "${OPENJAWZ_YES:-0}" = 1 ]; }
# every prompt does:  read -r x < "$(oj::tty)" || x=default
oj::tty() {
  oj::yes && return 1
  [ -r /dev/tty ] && [ -w /dev/tty ] && { true < /dev/tty; } 2>/dev/null || return 1
  echo /dev/tty
}
oj::version() { cat "${OPENJAWZ_SHARE:-/usr/share/openjawz}/VERSION" 2>/dev/null || echo unknown; }

# ── execution ────────────────────────────────────────────────────────────────
oj::run() {
  if [ "${OPENJAWZ_DRY_RUN:-0}" = 1 ]; then printf '+ %s\n' "$*"; return 0; fi
  oj::log info "+ $*" >/dev/null 2>&1
  "$@"
}
# oj::lock NAME — one instance of NAME per user. The fd is inherited by children (bash has no close-on-exec), so:
#   * call it AFTER any `exec` re-exec of the script (script/sudo), never before — the child would block on itself;
#   * idempotent per NAME within one process tree: a re-exec of the same verb keeps the lock it holds; a child verb takes its own.
oj::lock() {
  local name="$1" held="OJ_LOCK_HELD_${1//[^A-Za-z0-9_]/_}" fd
  # per-NAME guard: a re-exec of the same verb (update under `script`) does not double-lock,
  # but a child verb (migrate under update) still takes ITS OWN lock — previously one exported
  # fd made every child skip locking.
  [ -n "${!held:-}" ] && return 0
  mkdir -p "$OPENJAWZ_RUN"
  exec {fd}>"$OPENJAWZ_RUN/$name.lock"
  flock -n "$fd" || oj::die "openjawz $name: already running"
  export "$held=$fd"
}

# {{KEY}} → $KEY from identity.env (+ env). Unknown key → die. 0644, or 0600 under $OPENJAWZ_CONFIG.
oj::render() {
  local tpl="$1" out="$2" content key val
  [ -r "$tpl" ] || oj::die "render: no such template $tpl"
  if [ -r "$OPENJAWZ_CONFIG/identity.env" ]; then oj::_load_env "$OPENJAWZ_CONFIG/identity.env"; fi
  content="$(cat "$tpl")"
  while [[ "$content" =~ \{\{([A-Z_][A-Z0-9_]*)\}\} ]]; do
    key="${BASH_REMATCH[1]}"
    [ -n "${!key+x}" ] || oj::die "render: $tpl needs {{$key}} but it is not set (identity.env)"
    val="${!key}"
    content="${content//"{{$key}}"/$val}"
  done
  mkdir -p "$(dirname "$out")"
  printf '%s\n' "$content" > "$out"
  case "$out" in "$OPENJAWZ_CONFIG"/*) chmod 0600 "$out" ;; *) chmod 0644 "$out" ;; esac
  return 0
}

# ── daemon / events ──────────────────────────────────────────────────────────
oj::daemon_alive() { synaps daemon status >/dev/null 2>&1; }
oj::ambient_id() { cat "$OPENJAWZ_STATE/ambient.id" 2>/dev/null || return 1; }
# the ambient session is addressed by NAME (runtime names at create); the id cache is the fallback
oj::ambient_target() { printf '%s\n' "${OPENJAWZ_AMBIENT:-ambient}"; }
# oj::send SOURCE CONTENT_TYPE SEVERITY TEXT — THE hooks delivery leg (the only `synaps send` in the
# hooks/bridge pipeline; the heartbeat plugin fires its own session-addressed keepalive, see plugins/heartbeat).
# Targets the session by NAME (--session ambient); the cached id (ambient.id) is the fallback.
# Exit 0 from `send` also covers the inbox fallback — stderr is the truth: returns 1 (and logs) on
# inbox / No session / no daemon / daemon unavailable, so the caller can re-ensure and retry.
oj::send() {
  local src="$1" ct="$2" sev="$3" text="$4" target err id
  target="$(oj::ambient_target)"
  if id="$(oj::ambient_id)" && [ "$id" != "$target" ]; then target="$target $id"; fi
  for id in $target; do
    if err="$(synaps send --session "$id" --source "$src" --content-type "$ct" --severity "$sev" -- "$text" 2>&1 >/dev/null)"; then
      case "$err" in
        *inbox*|*"No session"*|*"no daemon"*|*"daemon unavailable"*) ;;   # rc 0 but undelivered: try the next target
        *) return 0 ;;
      esac
    fi
  done
  oj::log warn "send: undelivered: ${err:-no answer}"
  return 1
}
oj::json_escape() { printf '%s' "$1" | jq -Rr @json; }

# oj::stage NAME CMD… — prints "[NAME] ok|skip|FAIL"; exit 2 = skip; 127 = not installed
oj::stage() {
  local name="$1"; shift
  local rc=0 out
  out="$("$@" 2>&1)" || rc=$?
  case "$rc" in
    0)   printf '[%s] ok\n' "$name" ;;
    2)   printf '[%s] skip%s\n' "$name" "${out:+ ($(printf '%s' "$out" | tail -1))}" ;;
    127) printf '[%s] skip (not installed)\n' "$name" ;;
    *)   printf '[%s] FAIL (exit %s)\n' "$name" "$rc"; [ -n "$out" ] && printf '%s\n' "$out" | tail -5 ;;
  esac
  oj::log info "stage $name rc=$rc" >/dev/null 2>&1
  [ "$rc" = 0 ] || [ "$rc" = 2 ] || [ "$rc" = 127 ] || return "$rc"
  return 0
}
