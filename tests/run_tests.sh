#!/bin/bash
# run_tests.sh - Run all tests/test_*.sh files against the platform
# directories given as arguments (default: linux and macos).
#
# Usage: tests/run_tests.sh [linux] [macos]
#
# Requires bash, plus python3 or jq for the JSON checks.

here=$(cd "$(dirname "$0")" && pwd) || exit 2

if [ $# -eq 0 ]; then
  set -- linux macos
fi

status=0
for platform in "$@"; do
  if [ ! -d "$here/../$platform" ]; then
    echo "ERROR: no such platform directory: $platform" 1>&2
    exit 2
  fi
  for t in "$here"/test_*.sh; do
    echo "== $platform: $(basename "$t")"
    SINDAN_DIR="$(cd "$here/../$platform" && pwd)" "${BASH:-bash}" "$t" || status=1
  done
done

if [ "$status" -eq 0 ]; then
  echo "ALL TESTS PASSED"
else
  echo "SOME TESTS FAILED"
fi
exit "$status"
