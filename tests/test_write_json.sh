#!/bin/bash
# Tests for write_json, write_json_campaign and json_escape.
#
# The detail field carries raw command output (ping, dig, iw, ...) and
# network names, so it may contain newlines, quotes and backslashes. The
# generated files must stay valid JSON and the decoded value must be the
# original text.

# The parameters set here are read by the sourced scripts under test.
# shellcheck disable=SC2034
. "$(dirname "$0")/lib.sh"

# Write one record and print the path of the generated log file.
# write_one <log_type> <detail>
write_one() {
  write_json datalink common "$1" "$INFO" self "$2" 0 || return 1
  log_file datalink "$1" 0
}

test_plain_values_keep_the_legacy_format() {
  load_funcs funcb
  write_json datalink Wi-Fi wlan_rssi "$INFO" self -52 0 || fail "write_json failed"
  f=$(log_file datalink wlan_rssi 0) || fail "no log file"
  # Only the timestamp is normalized. Everything else must stay
  # byte-for-byte identical, because the server parses these records.
  actual=$(sed 's/"occurred_at" : "[^"]*"/"occurred_at" : "T"/' "$f")
  expected='{ "layer" : "datalink", "log_group" : "Wi-Fi", "log_type" : "wlan_rssi", "log_campaign_uuid" : "00000000-test", "result" : "10", "target" : "self", "detail" : "-52", "occurred_at" : "T" }'
  assert_eq "$expected" "$actual"
}

test_multiline_command_output_is_valid_json() {
  require_json_tool
  load_funcs funcb
  detail=$(printf 'PING 192.0.2.1 56(84) bytes of data.\n64 bytes from 192.0.2.1: time=1.0 ms\n\n--- 192.0.2.1 ping statistics ---')
  f=$(write_one v4alive_router "$detail") || fail "write failed"
  assert_json_valid "$f"
  assert_eq "$detail" "$(json_get "$f" detail)" "detail did not round-trip"
}

test_quotes_and_backslashes_are_escaped() {
  require_json_tool
  load_funcs funcb
  detail='My "Cafe" \ C:\temp\new'
  f=$(write_one wlan_ssid "$detail") || fail "write failed"
  assert_json_valid "$f"
  assert_eq "$detail" "$(json_get "$f" detail)"
}

test_tab_and_carriage_return_are_escaped() {
  require_json_tool
  load_funcs funcb
  detail=$'col1\tcol2\r\nrow2'
  f=$(write_one v4alive_router "$detail") || fail "write failed"
  assert_json_valid "$f"
  assert_eq "$detail" "$(json_get "$f" detail)"
}

test_other_control_characters_are_escaped() {
  require_json_tool
  load_funcs funcb
  # ANSI color escape, BEL, SOH and DEL.
  detail=$'\033[31mred\033[0m bell\a soh\001 del\177'
  f=$(write_one wwan_info "$detail") || fail "write failed"
  assert_json_valid "$f"
  assert_eq "$detail" "$(json_get "$f" detail)"
}

test_every_control_character_round_trips() {
  require_json_tool
  load_funcs funcb
  # All of 0x01-0x1f and 0x7f, each twice so that repeated characters are
  # replaced as well (NUL cannot be stored in a shell variable).
  detail=""
  for code in $(seq 1 31) 127; do
    printf -v hex '%02x' "$code"
    printf -v ch "\\x$hex"
    detail="$detail<$ch$ch>"
  done
  f=$(write_one wwan_info "$detail") || fail "write failed"
  assert_json_valid "$f"
  assert_eq "$detail" "$(json_get "$f" detail)"
}

test_non_ascii_text_survives_in_any_locale() {
  require_json_tool
  load_funcs funcb
  detail=$'SSID: カフェ Wi-Fi 🍵\nline2: 日本語'
  for loc in C "$(utf8_locale)"; do
    [ -n "$loc" ] || continue
    rm -f log/*
    f=$(LC_ALL=$loc write_one wlan_ssid "$detail") || fail "write failed (LC_ALL=$loc)"
    assert_json_valid "$f"
    assert_eq "$detail" "$(json_get "$f" detail)" "round-trip failed (LC_ALL=$loc)"
  done
}

test_every_field_is_escaped_not_only_detail() {
  require_json_tool
  load_funcs funcb
  UUID='uu"id'
  write_json 'lay"er' 'gr\oup' 'ty"pe' 'res"ult' 'tar"get' 'det"ail' 0 || fail "write failed"
  # The type is part of the file name, so look the file up by wildcard.
  f=$(ls log/sindan_*.json | head -n 1)
  assert_json_valid "$f"
  assert_eq 'lay"er' "$(json_get "$f" layer)"
  assert_eq 'gr\oup' "$(json_get "$f" log_group)"
  assert_eq 'ty"pe' "$(json_get "$f" log_type)"
  assert_eq 'uu"id' "$(json_get "$f" log_campaign_uuid)"
  assert_eq 'res"ult' "$(json_get "$f" result)"
  assert_eq 'tar"get' "$(json_get "$f" target)"
  assert_eq 'det"ail' "$(json_get "$f" detail)"
}

test_wrong_argument_count_is_rejected() {
  load_funcs funcb
  write_json datalink common wlan_ssid 2> /dev/null
  assert_eq 1 $? "return status"
  [ -z "$(ls log)" ] || fail "no file may be written on error"
}

test_campaign_log_is_valid_json() {
  require_json_tool
  load_funcs funcb
  write_json_campaign uuid-1 aa:bb:cc:dd:ee:ff 'Ubuntu 22.04 "Jammy"' Wi-Fi \
                      'My "Cafe" \ 5G' 'host"name' || fail "write failed"
  f=$(ls log/campaign_*.json | head -n 1)
  assert_json_valid "$f"
  assert_eq 'Ubuntu 22.04 "Jammy"' "$(json_get "$f" os)"
  assert_eq 'My "Cafe" \ 5G' "$(json_get "$f" ssid)"
  assert_eq 'host"name' "$(json_get "$f" hostname)"
  assert_eq aa:bb:cc:dd:ee:ff "$(json_get "$f" mac_addr)"
}

test_json_escape_unit() {
  json_escape_check() { # <input> <expected>
    json_escape "$1"
    assert_eq "$2" "$REPLY" "json_escape of [$1]"
  }
  load_funcs funcb
  json_escape_check 'plain' 'plain'
  json_escape_check '' ''
  json_escape_check 'a"b' 'a\"b'
  json_escape_check 'a\b' 'a\\b'
  json_escape_check $'a\nb' 'a\nb'
  json_escape_check $'a\tb' 'a\tb'
  json_escape_check $'a\rb' 'a\rb'
  json_escape_check $'a\001b' 'a\u0001b'
  json_escape_check $'a\033b' 'a\u001bb'
  json_escape_check 'カフェ' 'カフェ'
}

run_tests
