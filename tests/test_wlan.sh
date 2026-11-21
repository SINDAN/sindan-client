#!/bin/bash
# Tests for get_wlan_info and get_wlan_bssid (Linux, iw based).
#
# get_wlan_bssid used to take the "addr" line of "iw dev <if> info", which is
# the MAC address of the own interface, not the access point. get_wlan_info
# used "exit" inside a function and global variables, and always slept after
# the last attempt.

# shellcheck disable=SC2034
. "$(dirname "$0")/lib.sh"

linux_only() { grep -q 'iw dev' "$SINDAN_DIR/sindan_func1.sh" || skip "Linux only"; }

IW_INFO='Interface wlan0
       ifindex 3
       addr 00:11:22:33:44:55
       ssid TestNet
       type managed'
IW_LINK_FULL='Connected to AA:BB:CC:DD:EE:FF (on wlan0)
       SSID: TestNet
       freq: 5180
       signal: -50 dBm
       tx bitrate: 866.7 MBit/s'
IW_LINK_NOBITRATE='Connected to AA:BB:CC:DD:EE:FF (on wlan0)
       SSID: TestNet
       signal: -50 dBm'

# The iw shim answers "info" and "link" and counts the link queries.
setup_iw() {
  linux_only
  load_funcs funcb func1
  export IW_INFO IW_LINK
  make_shim iw 'case "$3" in
  info) echo "$IW_INFO" ;;
  link) echo x >> "$T/calls.iw_link"; echo "$IW_LINK" ;;
esac'
  make_shim sleep 'echo "$*" >> "$T/calls.sleep"'
}

test_bssid_is_the_access_point_not_the_own_mac() {
  linux_only
  load_funcs funcb func1
  out=$(printf '%s\n%s\n' "$IW_INFO" "$IW_LINK_FULL" | get_wlan_bssid)
  assert_eq aa:bb:cc:dd:ee:ff "$out"
}

test_bssid_is_empty_when_not_connected() {
  linux_only
  load_funcs funcb func1
  out=$(printf '%s\nNot connected.\n' "$IW_INFO" | get_wlan_bssid)
  assert_eq "" "$out"
}

test_ssid_is_still_found() {
  linux_only
  load_funcs funcb func1
  out=$(printf '%s\n%s\n' "$IW_INFO" "$IW_LINK_FULL" | get_wlan_ssid | head -1)
  assert_eq "TestNet" "$out"
}

test_get_wlan_info_returns_when_the_bitrate_is_available() {
  setup_iw
  IW_LINK=$IW_LINK_FULL
  out=$(get_wlan_info wlan0)
  assert_eq 0 $? "return status"
  assert_contains "$out" "addr 00:11:22:33:44:55"
  assert_contains "$out" "tx bitrate:"
  assert_eq 1 "$(wc -l < "$T/calls.iw_link" | tr -d ' ')" "link queries"
  assert_no_call sleep
}

test_get_wlan_info_does_not_exit_the_caller() {
  setup_iw
  IW_LINK=$IW_LINK_FULL
  # Without a command substitution, "exit" would end this shell.
  get_wlan_info wlan0 > /dev/null
  echo reached > "$T/after"
  assert_eq reached "$(cat "$T/after")"
}

test_get_wlan_info_gives_up_but_keeps_the_last_output() {
  setup_iw
  IW_LINK=$IW_LINK_NOBITRATE
  WLAN_MAX_RETRIES=3
  out=$(get_wlan_info wlan0)
  assert_eq 1 $? "return status"
  assert_contains "$out" "Connected to AA:BB:CC:DD:EE:FF"
  assert_eq 3 "$(wc -l < "$T/calls.iw_link" | tr -d ' ')" "link queries"
  # No sleep after the last attempt.
  assert_eq 2 "$(wc -l < "$T/calls.sleep" | tr -d ' ')" "sleeps"
}

test_get_wlan_info_does_not_leak_variables() {
  setup_iw
  IW_LINK=$IW_LINK_FULL
  get_wlan_info wlan0 > /dev/null
  assert_eq "" "${i:-}${output:-}${MAX_RETRIES:-}${RETRY_INTERVAL:-}" "leaked variables"
}

test_wrong_argument_count_is_rejected() {
  setup_iw
  get_wlan_info 2> /dev/null
  assert_eq 1 $? "return status"
}

run_tests
