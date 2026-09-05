#!/usr/bin/env bash
# ops/lib/compat.sh — minimal stand-ins for lib/openjawz.sh (A.1) so ops verbs run
# before openjawz-core is installed (tests, dev trees). Sourced only when the real lib is absent.
# shellcheck disable=SC2034
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
  export SYNAPS_RUN="$SYNAPS_BASE_DIR/run"
  local f
  for f in "$OPENJAWZ_CONFIG/identity.env" "$OPENJAWZ_CONFIG/profile.env"; do
    [ -r "$f" ] || continue
    while IFS='=' read -r k v; do
      [[ "$k" =~ ^[A-Z_][A-Z0-9_]*$ ]] || continue
      [ -n "${!k+x}" ] || export "$k=$v"
    done < "$f"
  done
}
oj::log() {
  local lvl=$1; shift
  local c='' r=''
  if [ -t 2 ] && [ -z "${NO_COLOR:-}" ]; then
    case $lvl in ok) c=$'\e[32m';; warn) c=$'\e[33m';; err) c=$'\e[31m';; *) c=$'\e[36m';; esac; r=$'\e[0m'
  fi
  printf '%s[%s]%s %s\n' "$c" "$lvl" "$r" "$*" >&2
  mkdir -p "${OPENJAWZ_STATE:-/tmp}" 2>/dev/null && printf '%s %s %s: %s\n' "$(date -Is)" "${OJ_CMD:-openjawz}" "$lvl" "$*" >> "${OPENJAWZ_STATE:-/tmp}/openjawz.log" 2>/dev/null || true
}
oj::die()  { oj::log err "$1"; exit "${2:-1}"; }
oj::have() { command -v "$1" >/dev/null 2>&1; }
oj::yes()  { [ "${OPENJAWZ_YES:-0}" = 1 ]; }
oj::tty()  { oj::yes && return 1; [ -r /dev/tty ] && [ -w /dev/tty ] || return 1; ( : < /dev/tty ) 2>/dev/null || return 1; echo /dev/tty; }
oj::run()  { if [ "${OPENJAWZ_DRY_RUN:-0}" = 1 ]; then printf '+ %s\n' "$*"; else "$@"; fi; }
oj::daemon_alive() { synaps daemon status >/dev/null 2>&1; }
# oj::render TEMPLATE OUT — {{KEY}} → $KEY from identity.env; unknown key → die
oj::render() {
  local tpl=$1 out=$2 content key val
  content=$(<"$tpl")
  while read -r key; do
    [ -n "${!key+x}" ] || oj::die "render: no value for {{$key}} in $tpl"
    val=${!key}
    content=${content//"{{$key}}"/$val}
  done < <(grep -oE '\{\{[A-Z_][A-Z0-9_]*\}\}' "$tpl" | tr -d '{}' | sort -u)
  mkdir -p "$(dirname "$out")"
  printf '%s\n' "$content" > "$out"
  case $out in "${OPENJAWZ_CONFIG:-/nonexistent}"/*) chmod 0600 "$out";; *) chmod 0644 "$out";; esac
}
