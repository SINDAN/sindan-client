#!/bin/bash
# Tests for check_v6autoconf.
#
# The function used to run "rdisc6 -n" on its own. That sent a Router
# Solicitation as a side effect of a pure evaluation of data that the caller
# already collected, and its output leaked into the result of the function.

# shellcheck disable=SC2034
. "$(dirname "$0")/lib.sh"

setup() {
  load_funcs funcb func2
  make_shim rdisc6 'echo "$*" >> "$T/calls.rdisc6"; echo "RA from fe80::1"'
}

test_check_v6autoconf_does_not_send_router_solicitations() {
  setup
  get_v6addrs() { echo 2001:db8::10; }
  out=$(check_v6autoconf eth0 automatic "" 2001:db8:: "LA")
  assert_eq 0 $? "return status"
  assert_no_call rdisc6
  assert_not_contains "$out" "RA from"
}

test_slaac_with_a_prefix_address_succeeds() {
  setup
  get_v6addrs() { echo 2001:db8::10; }
  check_v6autoconf eth0 automatic "" 2001:db8:: "LA" > /dev/null
  assert_eq 0 $? "return status"
}

test_slaac_without_an_address_fails() {
  setup
  get_v6addrs() { echo ""; }
  check_v6autoconf eth0 automatic "" 2001:db8:: "LA" > /dev/null
  assert_eq 1 $? "return status"
}

test_manual_configuration_is_reported() {
  setup
  out=$(check_v6autoconf eth0 manual "" "" "")
  assert_eq 0 $? "return status"
  assert_eq "v6conf is manual" "$out"
}

run_tests
