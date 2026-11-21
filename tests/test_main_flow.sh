#!/bin/bash
# Static checks of sindan.sh.
#
# sindan.sh runs the measurement phases one after another at the top level,
# so it cannot be sourced and tested function by function. The checks below
# look for specific mistakes in the script text that were fixed once, so that
# they do not come back. Logic that can be isolated lives in functions with
# their own tests.

. "$(dirname "$0")/lib.sh"

main_script() {
  echo "$SINDAN_DIR/sindan.sh"
}

test_manual_ipv6_branch_tests_the_v6addrs_variable() {
  # "$v6addr" (without the trailing s) is never assigned, so the test was
  # always false and the addresses of a manual configuration were not logged.
  if grep -nE '\$\{?v6addr([^A-Za-z0-9_]|$)' "$(main_script)"; then
    fail "sindan.sh uses the unassigned variable v6addr"
  fi
}

run_tests
