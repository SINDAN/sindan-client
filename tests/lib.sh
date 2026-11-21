#!/bin/bash
# lib.sh - Minimal, dependency-free test helpers (compatible with bash 3.2).
#
# Usage in a test file:
#
#   . "$(dirname "$0")/lib.sh"
#   test_something() {
#     load_funcs funcb
#     ...
#     assert_eq expected actual
#   }
#   run_tests
#
# Every test_* function runs in its own subshell inside a fresh temporary
# directory, because the scripts under test write to a relative "log/"
# directory. External commands such as nc, traceroute or ssh-keyscan are
# replaced by shims placed first in PATH (see make_shim), so the tests never
# touch the network.
#
# SINDAN_DIR selects the platform directory under test (linux or macos).

# The parameters set in setup_env() are read by the scripts under test, which
# are sourced at run time, so shellcheck cannot see where they are used.
# shellcheck disable=SC2034
SINDAN_DIR=${SINDAN_DIR:-$(cd "$(dirname "$0")/../linux" && pwd)}

# Exit status used by skip() and understood by run_tests().
SKIP_STATUS=77

####################
## Assertions

fail() {
  echo "    FAIL: $*" >&2
  exit 1
}

skip() {
  echo "    SKIP: $*" >&2
  exit "$SKIP_STATUS"
}

# assert_eq <expected> <actual> [message]
assert_eq() {
  [ "$1" = "$2" ] || fail "${3:-values differ}: expected [$1], got [$2]"
}

# assert_contains <haystack> <needle> [message]
assert_contains() {
  case $1 in
    *"$2"*) ;;
    *) fail "${3:-text not found}: [$2] is not in [$1]" ;;
  esac
}

# assert_not_contains <haystack> <needle> [message]
assert_not_contains() {
  case $1 in
    *"$2"*) fail "${3:-unexpected text}: [$2] is in [$1]" ;;
  esac
}

# assert_match <extended-regex> <value> [message]
assert_match() {
  [[ $2 =~ $1 ]] || fail "${3:-no match}: [$2] does not match /$1/"
}

# assert_log_exists <layer> <log_type> <count>
assert_log_exists() {
  log_file "$@" > /dev/null || fail "log file not written for: $*"
}

# assert_no_log <layer> <log_type> <count>
assert_no_log() {
  ! log_file "$@" > /dev/null || fail "unexpected log file written for: $*"
}

# assert_no_call <command>
# Fails if the shim of <command> has been executed.
assert_no_call() {
  [ ! -e "$T/calls.$1" ] || fail "$1 must not be called, but was: $(cat "$T/calls.$1")"
}

####################
## JSON helpers (python3 or jq, whichever is installed)

require_json_tool() {
  command -v python3 > /dev/null 2>&1 && return 0
  command -v jq > /dev/null 2>&1 && return 0
  skip "python3 or jq is required to validate JSON"
}

# assert_json_valid <file>
assert_json_valid() {
  if command -v python3 > /dev/null 2>&1; then
    python3 -I -c 'import json, sys; json.load(open(sys.argv[1], encoding="utf-8"))' "$1" 2> /dev/null
  else
    jq -e . "$1" > /dev/null 2>&1
  fi || fail "not valid JSON: $1: $(cat "$1")"
}

# json_get <file> <key>
# Print the decoded value of a top-level string key.
json_get() {
  local rc
  if command -v python3 > /dev/null 2>&1; then
    python3 -I -c '
import json, sys
value = json.load(open(sys.argv[1], encoding="utf-8"))[sys.argv[2]]
sys.stdout.buffer.write(value.encode("utf-8"))' "$1" "$2" 2> /dev/null
  else
    jq -j --arg k "$2" '.[$k]' "$1" 2> /dev/null
  fi
  rc=$?
  [ "$rc" -eq 0 ] || echo "json_get: cannot read [$2] from invalid JSON: $1" >&2
  return "$rc"
}

####################
## Environment

# Print the name of an installed UTF-8 locale (empty if there is none).
utf8_locale() {
  locale -a 2> /dev/null | grep -i -m1 'utf-\{0,1\}8'
}

# Print the path of the first log file written by write_json for the record.
# log_file <layer> <log_type> <count>
log_file() {
  local f
  for f in log/sindan_"$1"_"$2"_"$3"_*.json; do
    if [ -e "$f" ]; then
      echo "$f"
      return 0
    fi
  done
  return 1
}

# Create an executable shim for <name> in the directory first in PATH.
# The snippet is run by bash. $T is exported, so a snippet can record its
# arguments in "$T/calls.<name>" (see assert_no_call).
# make_shim <name> <shell-snippet>
make_shim() {
  printf '#!/bin/bash\n%s\n' "$2" > "$T/bin/$1"
  chmod +x "$T/bin/$1"
}

# Source the given function files of the platform under test.
# load_funcs <name>... (e.g. funcb func4)
load_funcs() {
  local name file
  for name in "$@"; do
    # The platform directory has priority over the shared directory.
    file="$SINDAN_DIR/sindan_$name.sh"
    [ -f "$file" ] || file="$SINDAN_DIR/../common/sindan_$name.sh"
    # shellcheck disable=SC1090
    . "$file" || fail "cannot source sindan_$name.sh"
  done
}

# Prepare an isolated working directory and the parameters that sindan.sh
# normally gets from sindan.conf. Called by run_tests() for each test.
setup_env() {
  T=$(mktemp -d "${TMPDIR:-/tmp}/sindan-test.XXXXXX") || return 1
  export T
  mkdir -p "$T/log" "$T/bin"
  cd "$T" || return 1
  PATH="$T/bin:$PATH"
  export PATH
  trap 'cd /; rm -rf "$T"' EXIT

  FAIL=0
  SUCCESS=1
  INFO=10
  VERBOSE=no
  UUID=00000000-test
  VERSION="test"
  LOCAL_NETWORK_PRIVACY=no
  CLIENT_PRIVACY=no
  # The real configuration uses /usr/bin/shasum (SHA-1).
  CMD_HASH=$(command -v shasum || command -v sha1sum)
}

####################
## Runner

# Run every function whose name starts with "test_".
# Returns non-zero if any test failed.
run_tests() {
  local fn rc passed=0 failed=0 skipped=0
  for fn in $(declare -F | awk '{print $3}' | grep '^test_'); do
    ( setup_env && "$fn" )
    rc=$?
    case $rc in
      0)
        passed=$(( passed + 1 ))
        echo "  ok    $fn"
        ;;
      "$SKIP_STATUS")
        skipped=$(( skipped + 1 ))
        echo "  skip  $fn"
        ;;
      *)
        failed=$(( failed + 1 ))
        echo "  FAIL  $fn"
        ;;
    esac
  done
  echo "  -> $passed passed, $failed failed, $skipped skipped"
  [ "$failed" -eq 0 ]
}
