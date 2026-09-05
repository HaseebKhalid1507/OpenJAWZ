#!/usr/bin/env bash
# ci: fast
# hook content filter: secret-shaped text never leaves a bridge, and a BROKEN filter fails CLOSED (round-2 auditor).
set -uo pipefail
cd "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)" || exit 1
fail=0
run() { # $1 = redact list file (or empty), $2 = text → prints bridge::redact output
  OPENJAWZ_HOOK_DRY=1 OPENJAWZ_HOOK_REDACT_LIST="${1:-/dev/null}" OPENJAWZ_LIB="$PWD/lib" OPENJAWZ_SHARE="$PWD" BRIDGE_NAME=test \
    bash -c 'source hooks/lib/bridge.sh >/dev/null 2>&1; bridge::redact "$1" notify' _ "$2" 2>/dev/null
}
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
# 1. good list: OTP + key + password manager all redacted; plain text passes
printf '\\b(1password|bitwarden)\\b\n' > "$t/good.list"
fake_key="sk-$(printf ant)-$(printf "%032d" 0 | tr 0 a)"   # built at runtime so no key-shaped literal lives in the tree
for s in "Your code is 123456" "token $fake_key" "1Password wants to fill"; do
  o=$(run "$t/good.list" "$s"); case "$o" in *'[redacted'*) echo "ok   redacted: $s";; *) echo "FAIL forwarded: $s → $o"; fail=1;; esac
done
o=$(run "$t/good.list" "focus: firefox"); case "$o" in 'focus: firefox') echo "ok   plain text passes";; *) echo "FAIL plain text mangled: $o"; fail=1;; esac
# 2. malformed list: the filter must FAIL CLOSED (redact), never forward
printf 'foo(\n' > "$t/bad.list"
o=$(run "$t/bad.list" "Your code is 123456"); case "$o" in *'[redacted'*) echo "ok   malformed pattern → fails CLOSED";; *) echo "FAIL malformed pattern → fails OPEN: $o"; fail=1;; esac
o=$(run "$t/bad.list" "focus: firefox"); case "$o" in *'[redacted'*) echo "ok   (and even plain text is held while the filter is broken)";; *) echo "FAIL broken filter forwarded plain text: $o"; fail=1;; esac
[ $fail = 0 ] && echo "hook-filter: ok"; exit $fail
