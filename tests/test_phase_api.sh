#!/bin/bash
# Tests for the functions that the shared Phase 1 and Phase 2 call.
#
# The shared code calls the functions of sindan_func1.sh and
# sindan_func2_os.sh with the same arguments on every platform. A function
# takes the arguments it does not need and ignores them, and a function that
# a platform does not support prints nothing, so no record is written.

# shellcheck disable=SC2034
. "$(dirname "$0")/lib.sh"

is_linux() { grep -q nmcli "$SINDAN_DIR/sindan_func2_os.sh"; }

# Call a function with the wrong number of arguments and check that it
# reports the usage and returns 1.
# expect_usage_error <function> <argument count>
expect_usage_error() {
  local fn=$1 n=$2 args=() i out
  for ((i=0; i<n; i++)); do args+=(x); done
  out=$($fn "${args[@]}" 2>&1 > /dev/null)
  assert_eq 1 $? "return status of $fn with $n arguments"
  assert_contains "$out" "ERROR: $fn" "usage of $fn with $n arguments"
}

test_interface_control_functions_take_ifname_and_iftype() {
  load_funcs funcb func1
  for fn in do_ifdown do_ifup get_ifstatus; do
    expect_usage_error $fn 1
    expect_usage_error $fn 3
  done
}

test_interface_control_functions_accept_two_arguments() {
  load_funcs funcb func1
  # The platform commands are shimmed: nothing may be run for real.
  for c in nmcli ip rfkill; do
    make_shim $c 'echo up; exit 0'
  done
  make_shim networksetup 'echo "$*" >> "$T/calls.networksetup"'
  make_shim ifconfig 'echo "   status: active"'
  if is_linux; then
    # The Linux implementation reads the state from sysfs; a call with two
    # arguments must at least not be rejected as a usage error.
    out=$(get_ifstatus lo Ethernet 2>&1)
    assert_not_contains "$out" "ERROR: get_ifstatus"
  else
    out=$(get_ifstatus en0 Wi-Fi)
    assert_eq 0 $? "return status"
    assert_eq active "$out"
    do_ifdown en0 Wi-Fi
    assert_eq 0 $? "do_ifdown"
    assert_contains "$(cat "$T/calls.networksetup")" "-setairportpower en0 off"
  fi
}

test_ifconf_functions_take_ifname_and_iftype() {
  load_funcs funcb func2
  for fn in get_v4ifconf get_v6ifconf; do
    expect_usage_error $fn 1
    expect_usage_error $fn 3
  done
}

test_ra_prefix_functions_take_the_ifname_as_the_last_argument() {
  load_funcs funcb func2
  expect_usage_error get_ra_prefs 1
  expect_usage_error get_ra_prefs 3
  for fn in get_ra_pref_flags get_ra_pref_vltime get_ra_pref_pltime; do
    expect_usage_error $fn 2
    expect_usage_error $fn 4
  done
}

test_ra_prefix_functions_ignore_the_ifname_on_linux() {
  is_linux || skip "Linux only"
  load_funcs funcb func2
  ra='  from fe80::1
 Prefix : 2001:db8::/64
  On-link flag : Yes
  Autonomous address conf flag : Yes
  Valid time : 2592000 (seconds)
  Pref. time : 604800 (seconds)'
  # The same call with different interface names gives the same result.
  a=$(echo "$ra" | get_ra_prefs fe80::1 eth0)
  b=$(echo "$ra" | get_ra_prefs fe80::1 wlan0)
  assert_eq "$a" "$b"
}

test_unsupported_functions_on_macos_print_nothing() {
  is_linux && skip "macOS only"
  load_funcs funcb func1 func2
  for fn in get_wlan_nss get_wlan_quality get_wwan_info \
            get_ra_hlim get_ra_ltime get_ra_reach get_ra_retrans \
            get_ra_routes get_ra_route_flag get_ra_route_ltime \
            get_ra_rdnsses get_ra_rdnss_ltime; do
    out=$(echo "some data" | $fn en0 x y 2>&1)
    assert_eq 0 $? "return status of $fn"
    assert_eq "" "$out" "output of $fn"
  done
}

run_tests
