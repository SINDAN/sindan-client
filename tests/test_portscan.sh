#!/bin/bash
# Tests for do_portscan and cmdset_portscan.
#
# The default branch of the version check used to be written as "*" (with
# quotes), which only matches a literal asterisk. Any other invalid version
# fell through the case statement and was reported as a success (status 0).

. "$(dirname "$0")/lib.sh"

# Install an nc shim. NC_RC (default 0) is its exit status.
setup_nc() {
  load_funcs funcb func6
  make_shim nc 'printf "%s\n" "$*" >> "$T/calls.nc"
echo "Connection to $3 $4 port [tcp/*] succeeded!" >&2
exit "${NC_RC:-0}"'
}

test_invalid_version_is_rejected() {
  setup_nc
  for v in 5 0 '*' 46 ''; do
    err=$(do_portscan "$v" host.example 22 2>&1 > /dev/null)
    rc=$?
    assert_eq 9 "$rc" "return status for version [$v]"
    assert_eq "ERROR: <version> must be 4 or 6." "$err" "error message for version [$v]"
  done
  assert_no_call nc
}

test_wrong_argument_count_is_rejected() {
  setup_nc
  do_portscan 4 host.example 2> /dev/null
  assert_eq 1 $? "return status"
  assert_no_call nc
}

test_ipv4_scan_runs_nc_with_the_ipv4_option() {
  setup_nc
  out=$(do_portscan 4 host.example 22)
  assert_eq 0 $? "return status"
  assert_eq "-zv4 -w1 host.example 22" "$(cat "$T/calls.nc")"
  assert_contains "$out" "succeeded"
}

test_ipv6_scan_runs_nc_with_the_ipv6_option() {
  setup_nc
  do_portscan 6 2001:db8::1 443 > /dev/null
  assert_eq "-zv6 -w1 2001:db8::1 443" "$(cat "$T/calls.nc")"
}

test_nc_failure_status_is_propagated() {
  setup_nc
  export NC_RC=1
  do_portscan 4 host.example 22 > /dev/null
  assert_eq 1 $? "return status"
}

test_cmdset_portscan_records_open_port() {
  require_json_tool
  setup_nc
  cmdset_portscan app 4 pssrv host.example 22 0
  f=$(log_file app v4portscan_22 0) || fail "log not written"
  assert_eq 1 "$(json_get "$f" result)"
  assert_eq host.example "$(json_get "$f" target)"
}

test_cmdset_portscan_records_closed_port() {
  require_json_tool
  setup_nc
  export NC_RC=1
  cmdset_portscan app 6 pssrv host.example 80 0
  f=$(log_file app v6portscan_80 0) || fail "log not written"
  assert_eq 0 "$(json_get "$f" result)"
}

test_cmdset_portscan_does_not_report_success_for_an_invalid_version() {
  require_json_tool
  setup_nc
  cmdset_portscan app 5 pssrv host.example 22 0
  assert_no_call nc
  f=$(log_file app v5portscan_22 0) || fail "log not written"
  assert_eq 0 "$(json_get "$f" result)"
}

run_tests
