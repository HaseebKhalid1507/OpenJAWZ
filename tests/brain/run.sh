#!/usr/bin/env bash
# ci: fast
# brain: the secret scan really runs — a seeded secret-shaped memory is DELETED and logged; a benign one survives;
# every pattern in secret-patterns.txt compiles (grep -E and python re); `brain purge --yes` removes the files;
# `brain init` wires the axel MCP server into mcp.json. Needs sqlite3 + python3, else 77.
set -uo pipefail
cd "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)" || exit 1
v() { [ "${OPENJAWZ_TEST_VERBOSE:-0}" = 1 ] && echo "$@" >&2; return 0; }
command -v sqlite3 >/dev/null && command -v python3 >/dev/null || { echo "brain: needs sqlite3 + python3"; exit 77; }
fail=0
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp" XDG_CONFIG_HOME="$tmp/.config" OPENJAWZ_HOME="$tmp/oj" OPENJAWZ_STATE="$tmp/state" \
       SYNAPS_BASE_DIR="$tmp/.synaps-cli" OPENJAWZ_SHARE="$tmp/nonexistent" NO_COLOR=1 AGENT_NAME=test
pats=brain/secret-patterns.txt

# 0. every pattern compiles under grep -E and python re
grep -E -f "$pats" /dev/null; [ $? = 2 ] && { echo "FAIL a pattern in $pats does not compile under grep -E"; fail=1; }
python3 -c 'import re,sys; [re.compile(l.rstrip("\n")) for l in open(sys.argv[1]) if l.strip() and not l.startswith("#")]' "$pats" \
  || { echo "FAIL a pattern in $pats does not compile under python re"; fail=1; }

# 1. stub axel: no consolidate, no forget → the plain-DELETE branch
mkdir -p "$tmp/bin"; cat > "$tmp/bin/axel" <<'SH'
#!/usr/bin/env bash
case ${1:-} in consolidate|forget) exit 2;; init) : > "${3:?}";; *) exit 0;; esac
SH
chmod +x "$tmp/bin/axel"; export PATH="$tmp/bin:$PATH"
mkdir -p "$XDG_CONFIG_HOME/axel"; brain="$XDG_CONFIG_HOME/axel/test.r8"
secret="ghp_$(head -c 36 /dev/zero | tr '\0' a)"   # built at runtime so grep-guard never sees a token in the tree
sqlite3 "$brain" "CREATE TABLE memories(id TEXT PRIMARY KEY, content TEXT NOT NULL, title TEXT);
  INSERT INTO memories VALUES('mem_secret','my token is $secret','t'),('mem_ok','the build passed on the second try','t');"
out=$(bin/openjawz-brain consolidate 2>&1); rc=$?
[ "$rc" = 0 ] || { echo "FAIL consolidate rc=$rc: $out"; fail=1; }
printf '%s' "$out" | grep -q 'secret-shaped content in 1 memor' || { echo "FAIL scan did not report 1 hit: $out"; fail=1; }
[ "$(sqlite3 "$brain" "SELECT count(*) FROM memories WHERE id='mem_secret'")" = 0 ] || { echo "FAIL secret row not deleted"; fail=1; }
[ "$(sqlite3 "$brain" "SELECT count(*) FROM memories")" = 1 ] || { echo "FAIL benign row did not survive"; fail=1; }
[ "$(grep -c 'mem_secret pattern-[0-9]* deleted' "$OPENJAWZ_STATE/brain-scrub.log" 2>/dev/null)" = 1 ] || { echo "FAIL brain-scrub.log missing the deletion line"; fail=1; }
[ "$(stat -c %a "$OPENJAWZ_STATE/brain-scrub.log")" = 600 ] || { echo "FAIL brain-scrub.log not 0600"; fail=1; }
# second run: nothing left, log unchanged
bin/openjawz-brain scan >/dev/null 2>&1; [ "$(wc -l < "$OPENJAWZ_STATE/brain-scrub.log")" = 1 ] || { echo "FAIL rescan appended to the log"; fail=1; }

# 2. axel with forget → the axel branch deletes (stub deletes via sqlite, records the call)
cat > "$tmp/bin/axel" <<'SH'
#!/usr/bin/env bash
case ${1:-} in
  forget) [ "${2:-}" = --help ] && exit 0; echo "forget $4" >> "$FORGET_LOG"; sqlite3 "$3" "DELETE FROM memories WHERE id='$4'";;
  consolidate) exit 2;; init) : > "${3:?}";; *) exit 0;; esac
SH
export FORGET_LOG="$tmp/forget.log"
sqlite3 "$brain" "INSERT INTO memories VALUES('mem_aws','key AKIA$(head -c 16 /dev/zero | tr '\0' A)','t');"
bin/openjawz-brain scan >/dev/null 2>&1
grep -q 'forget mem_aws' "$FORGET_LOG" 2>/dev/null || { echo "FAIL axel forget was not used when available"; fail=1; }
[ "$(sqlite3 "$brain" "SELECT count(*) FROM memories")" = 1 ] || { echo "FAIL forget branch left the row"; fail=1; }

# 3. backup is private
bin/openjawz-brain backup --quick >/dev/null 2>&1 || { echo "FAIL backup --quick"; fail=1; }
b=$(ls "$OPENJAWZ_STATE"/brain-backups/*.tar.zst 2>/dev/null | head -1)
[ -n "$b" ] && [ "$(stat -c %a "$b")" = 600 ] || { echo "FAIL backup not 0600 ($b)"; fail=1; }
[ "$(stat -c %a "$OPENJAWZ_STATE/brain-backups")" = 700 ] || { echo "FAIL brain-backups dir not 0700"; fail=1; }

# 4. init wires mcp.json (merge, idempotent, keeps other servers)
mkdir -p "$SYNAPS_BASE_DIR"; echo '{"mcpServers":{"other":{"command":"x"}}}' > "$SYNAPS_BASE_DIR/mcp.json"
rm -f "$brain"; OPENJAWZ_MCP_DEFAULT="$PWD/daemon/mcp.json.default" bin/openjawz-brain init >/dev/null 2>&1 || { echo "FAIL brain init"; fail=1; }
[ "$(jq -r '.mcpServers.axel.command' "$SYNAPS_BASE_DIR/mcp.json" 2>/dev/null)" = axel ] || { echo "FAIL mcp.json has no axel server after init"; fail=1; }
[ "$(jq -r '.mcpServers.other.command' "$SYNAPS_BASE_DIR/mcp.json" 2>/dev/null)" = x ] || { echo "FAIL init clobbered mcp.json"; fail=1; }
[ "$(stat -c %a "$XDG_CONFIG_HOME/axel")" = 700 ] || { echo "FAIL ~/.config/axel not 0700"; fail=1; }

# 5. purge asks (non-tty → refuses) and --yes removes
OPENJAWZ_YES=0 setsid -w bin/openjawz-brain purge </dev/null >/dev/null 2>&1 && { echo "FAIL purge without --yes and no tty did not refuse"; fail=1; }
[ -f "$brain" ] || { echo "FAIL purge refusal still removed the brain"; fail=1; }
bin/openjawz-brain purge --yes >/dev/null 2>&1 || { echo "FAIL purge --yes"; fail=1; }
[ -e "$brain" ] && { echo "FAIL purge left $brain"; fail=1; }
[ -e "$XDG_CONFIG_HOME/axel/sources.toml" ] && { echo "FAIL purge left sources.toml"; fail=1; }

[ "$fail" = 0 ] && v "brain: scan deletes + logs, backup 0600, init wires mcp.json, purge ok"
exit "$fail"
