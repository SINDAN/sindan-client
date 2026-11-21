#!/bin/bash
# Tests for cmdset_trace.
#
# do_traceroute output is piped through sed. Without pipefail the status of
# the pipeline is the status of sed, so a failing traceroute was always
# reported as a success.

# The parameters set here are read by the sourced scripts under test.
# shellcheck disable=SC2034
. "$(dirname "$0")/lib.sh"

# Install traceroute/traceroute6 shims. TRACEROUTE_RC (default 0) is the
# exit status of the shim.
setup_traceroute() {
  # The Linux implementation wraps traceroute with timeout(1).
  if grep -q 'timeout -s' "$SINDAN_DIR/sindan_func4_os.sh" &&
     ! command -v timeout > /dev/null 2>&1; then
    skip "timeout(1) is not installed"
  fi
  require_json_tool
  load_funcs funcb func4
  VERBOSE=yes
  local body='printf "%s\n" "$*" >> "$T/calls.$(basename "$0")"
echo "traceroute to 192.0.2.1 (192.0.2.1), 20 hops max, 60 byte packets"
echo " 1  192.0.2.254  0.512 ms"
echo " 2  *"
exit "${TRACEROUTE_RC:-0}"'
  make_shim traceroute "$body"
  make_shim traceroute6 "$body"
}

test_successful_trace_records_the_path() {
  setup_traceroute
  out=$(cmdset_trace globalnet 4 srv 192.0.2.1 0)
  assert_contains "$out" "path: 192.0.2.254,-"
  f=$(log_file globalnet v4path_srv 0) || fail "v4path_srv was not written"
  assert_eq 192.0.2.254,- "$(json_get "$f" detail)"
}

test_asterisks_are_replaced_in_the_raw_output() {
  setup_traceroute
  cmdset_trace globalnet 4 srv 192.0.2.1 0 > /dev/null
  f=$(log_file globalnet v4path_detail_srv 0) || fail "v4path_detail_srv was not written"
  detail=$(json_get "$f" detail)
  assert_contains "$detail" " 2  -"
  assert_not_contains "$detail" "*"
}

test_failing_traceroute_is_reported_as_ng() {
  setup_traceroute
  export TRACEROUTE_RC=1
  out=$(cmdset_trace globalnet 4 srv 192.0.2.1 0)
  assert_contains "$out" "status: ng"
  assert_not_contains "$out" "path:"
  assert_no_log globalnet v4path_srv 0
  # The raw output is still kept for diagnosis.
  assert_log_exists globalnet v4path_detail_srv 0
}

test_traceroute_killed_by_timeout_is_reported_as_ng() {
  setup_traceroute
  export TRACEROUTE_RC=137
  out=$(cmdset_trace globalnet 4 srv 192.0.2.1 0)
  assert_contains "$out" "status: ng"
  assert_no_log globalnet v4path_srv 0
}

test_ipv6_uses_traceroute6() {
  setup_traceroute
  cmdset_trace globalnet 6 srv 2001:db8::1 0 > /dev/null
  assert_contains "$(cat "$T/calls.traceroute6")" "2001:db8::1"
  assert_no_call traceroute
  assert_log_exists globalnet v6path_srv 0
}

test_failing_ipv6_traceroute_is_reported_as_ng() {
  setup_traceroute
  export TRACEROUTE_RC=1
  out=$(cmdset_trace globalnet 6 srv 2001:db8::1 0)
  assert_contains "$out" "status: ng"
  assert_no_log globalnet v6path_srv 0
}

run_tests
