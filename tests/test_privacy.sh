#!/bin/bash
# Tests for the privacy settings (LOCAL_NETWORK_PRIVACY / CLIENT_PRIVACY).
#
# write_json passes the log_type to hash_result. For Wi-Fi records the
# log_type is prefixed with "wlan_" (wlan_ssid, wlan_bssid and
# wlan_environment), so these names must be handled too. Otherwise the
# privacy setting silently has no effect on the per-measurement records.

# The parameters set here are read by the sourced scripts under test.
# shellcheck disable=SC2034
. "$(dirname "$0")/lib.sh"

# The expected value is computed in the same way as the implementation:
# the hash of the value followed by a newline (echo), plus a ":SHA1" suffix.
expected_hash() {
  printf '%s\n' "$1" | $CMD_HASH | cut -d' ' -f1
}

# Write a record and print its decoded detail field.
# detail_of <log_type> <detail>
detail_of() {
  write_json datalink Wi-Fi "$1" "$INFO" self "$2" 0 || return 1
  json_get "$(log_file datalink "$1" 0)" detail
}

test_ssid_and_bssid_records_are_hashed() {
  require_json_tool
  load_funcs funcb
  LOCAL_NETWORK_PRIVACY=yes
  for type in wlan_ssid wlan_bssid; do
    value=SecretSSID
    [ "$type" = wlan_bssid ] && value=aa:bb:cc:dd:ee:ff
    detail=$(detail_of "$type" "$value")
    assert_eq "$(expected_hash "$value"):SHA1" "$detail" "$type"
    assert_match '^[0-9a-f]{40}:SHA1$' "$detail" "$type"
    assert_not_contains "$detail" "$value" "$type leaks the original value"
  done
}

test_wlan_environment_is_masked() {
  require_json_tool
  load_funcs funcb
  LOCAL_NETWORK_PRIVACY=yes
  detail=$(detail_of wlan_environment $'BSSID,SSID\naa:bb:cc:dd:ee:ff,NeighborAP')
  assert_eq XXX "$detail"
}

test_unprefixed_names_are_still_hashed() {
  # hash_result is also called directly with the short names.
  load_funcs funcb
  LOCAL_NETWORK_PRIVACY=yes
  assert_eq "$(expected_hash SecretSSID):SHA1" "$(hash_result ssid SecretSSID)"
  assert_eq "$(expected_hash aa:bb:cc:dd:ee:ff):SHA1" "$(hash_result bssid aa:bb:cc:dd:ee:ff)"
  assert_eq XXX "$(hash_result environment anything)"
}

test_values_are_kept_when_privacy_is_off() {
  require_json_tool
  load_funcs funcb
  LOCAL_NETWORK_PRIVACY=no
  assert_eq SecretSSID "$(detail_of wlan_ssid SecretSSID)"
  assert_eq aa:bb:cc:dd:ee:ff "$(detail_of wlan_bssid aa:bb:cc:dd:ee:ff)"
  assert_eq NeighborAP "$(detail_of wlan_environment NeighborAP)"
}

test_other_records_are_never_touched() {
  require_json_tool
  load_funcs funcb
  LOCAL_NETWORK_PRIVACY=yes
  CLIENT_PRIVACY=no
  for type in wlan_rssi wlan_channel wlan_mode ifstatus v4addr; do
    assert_eq 5 "$(detail_of "$type" 5)" "$type"
  done
}

test_client_privacy_does_not_hash_network_names() {
  require_json_tool
  load_funcs funcb
  LOCAL_NETWORK_PRIVACY=no
  CLIENT_PRIVACY=yes
  assert_eq SecretSSID "$(detail_of wlan_ssid SecretSSID)"
}

test_campaign_log_is_still_hashed() {
  require_json_tool
  load_funcs funcb
  LOCAL_NETWORK_PRIVACY=yes
  CLIENT_PRIVACY=yes
  write_json_campaign uuid-1 aa:bb:cc:dd:ee:ff Ubuntu Wi-Fi SecretSSID myhost || fail "write failed"
  f=$(ls log/campaign_*.json | head -n 1)
  assert_eq "$(expected_hash aa:bb:cc:dd:ee:ff):SHA1" "$(json_get "$f" mac_addr)"
  assert_eq "$(expected_hash SecretSSID):SHA1" "$(json_get "$f" ssid)"
}

run_tests
