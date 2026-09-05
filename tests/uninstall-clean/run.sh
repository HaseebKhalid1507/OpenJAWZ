#!/usr/bin/env bash
# ci: container
# uninstall-clean: runs install-smoke with KEEP=1, which executes uninstall-clean.sh inside the same container afterwards.
set -uo pipefail
cd "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)" || exit 1
KEEP=1 tests/install-smoke/run.sh "${1:-desktop}" | tee /tmp/oj-uninstall-clean.log
grep -q 'uninstall-clean: fail=0' /tmp/oj-uninstall-clean.log
