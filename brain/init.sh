#!/usr/bin/env bash
# brain/init.sh — thin entry kept for the install stage and for people reading the tree:
# the implementation is bin/openjawz-brain (init | status | backup | consolidate).
exec "$(dirname "$(readlink -f "$0")")/../bin/openjawz-brain" init "$@"
