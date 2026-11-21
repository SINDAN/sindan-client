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

test_ipv4_layer_checks_use_the_usable_type_helper() {
  # The shared address space (100.64.0.0/10) must not be excluded, so the
  # conditions must not compare the type with "private"/"global" directly.
  if grep -nE '"\$v4addr_type" = "(private|global)"' "$(main_script)"; then
    fail "sindan.sh compares v4addr_type directly"
  fi
  local n
  n=$(grep -c 'is_usable_v4addr_type "\$v4addr_type"' "$(main_script)")
  assert_eq 4 "$n" "number of call sites of is_usable_v4addr_type"
}

run_tests
