#!/bin/bash
# Tests for do_pmtud and do_traceroute, which share their logic between the
# platforms (common/sindan_func4.sh) and take the commands and options from
# the platform file (sindan_func4_os.sh).

# shellcheck disable=SC2034
. "$(dirname "$0")/lib.sh"

is_linux() { grep -q 'timeout -sKILL 30' "$SINDAN_DIR/sindan_func4_os.sh"; }

# Ping shim: the largest payload that passes is $MAX_PAYLOAD (default 1372,
# i.e. an MTU of 1400 for IPv4). It records its arguments.
setup_ping() {
  load_funcs funcb func4_os func4
  local body='printf "%s\n" "$*" >> "$T/calls.$(basename "$0")"
size=0
prev=""
for a in "$@"; do
  [ "$prev" = "-s" ] && size=$a
  prev=$a
done
[ "$size" -le "${MAX_PAYLOAD:-1372}" ]'
  make_shim ping "$body"
  make_shim ping6 "$body"
  # macOS wraps ping6 with gtimeout <signal option> <seconds> <command>...
  make_shim gtimeout 'shift 2; exec "$@"'
}

test_ipv4_path_mtu_is_found() {
  setup_ping
  out=$(do_pmtud 4 192.0.2.1 56 1500 192.0.2.2)
  assert_eq 0 $? "return status"
  assert_eq 1400 "$out"
}

test_ipv6_path_mtu_is_found() {
  setup_ping
  export MAX_PAYLOAD=1232
  out=$(do_pmtud 6 2001:db8::1 56 1500 2001:db8::2)
  assert_eq 0 $? "return status"
  # 1232 + 48 (IPv6 + ICMPv6 headers)
  assert_eq 1280 "$out"
}

test_source_address_option_is_platform_specific() {
  setup_ping
  do_pmtud 4 192.0.2.1 56 1500 192.0.2.2 > /dev/null
  if is_linux; then
    assert_contains "$(head -1 "$T/calls.ping")" "-I 192.0.2.2 192.0.2.1"
    assert_contains "$(tail -1 "$T/calls.ping")" "-M do"
  else
    assert_contains "$(head -1 "$T/calls.ping")" "-S 192.0.2.2 192.0.2.1"
    assert_contains "$(tail -1 "$T/calls.ping")" "-D"
  fi
}

test_unreachable_target_is_unmeasurable() {
  setup_ping
  export MAX_PAYLOAD=-1
  out=$(do_pmtud 4 192.0.2.1 56 1500 192.0.2.2)
  assert_eq 1 $? "return status"
  assert_eq 0 "$out"
}

test_invalid_version_is_rejected() {
  setup_ping
  for v in 5 '' '*'; do
    do_pmtud "$v" 192.0.2.1 56 1500 192.0.2.2 > /dev/null 2>&1
    assert_eq 9 $? "pmtud status for version [$v]"
    do_traceroute "$v" 192.0.2.1 > /dev/null 2>&1
    assert_eq 9 $? "traceroute status for version [$v]"
  done
  assert_no_call ping
  assert_no_call ping6
}

test_wrong_argument_counts_are_rejected() {
  setup_ping
  do_pmtud 4 192.0.2.1 2> /dev/null
  assert_eq 1 $? "pmtud status"
  do_traceroute 4 2> /dev/null
  assert_eq 1 $? "traceroute status"
}

run_tests
