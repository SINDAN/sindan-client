#!/bin/bash
# Tests for log file collisions and cmdset_ping_routers.
#
# sindan.sh pinged the routers once per target server in the same layer.
# The repeated runs wrote the same log file name (layer, type, count and
# epoch second), so records were overwritten or duplicated. The routers are
# now checked once per layer and write_json refuses to overwrite a file.

# shellcheck disable=SC2034
. "$(dirname "$0")/lib.sh"

test_write_json_does_not_overwrite_a_log_of_the_same_second() {
  load_funcs funcb
  date() { if [ "$1" = "-u" ] && [ "$2" = "+%s" ]; then echo 1700000000; else command date "$@"; fi; }
  write_json globalnet Ping v4alive_router 1 192.0.2.1 first 0
  write_json globalnet Ping v4alive_router 0 192.0.2.1 second 0
  write_json globalnet Ping v4alive_router 0 192.0.2.1 third 0
  assert_eq 3 "$(find log -name 'sindan_*.json' | wc -l | tr -d ' ')" "number of logs"
  assert_contains "$(cat log/sindan_globalnet_v4alive_router_0_1700000000.json)" first
  assert_contains "$(cat log/sindan_globalnet_v4alive_router_0_1700000000_1.json)" second
  assert_contains "$(cat log/sindan_globalnet_v4alive_router_0_1700000000_2.json)" third
}

test_write_json_keeps_the_legacy_name_without_a_collision() {
  load_funcs funcb
  date() { if [ "$1" = "-u" ] && [ "$2" = "+%s" ]; then echo 1700000000; else command date "$@"; fi; }
  write_json app Ping v4alive_websrv 1 192.0.2.1 x 3
  [ -f log/sindan_app_v4alive_websrv_3_1700000000.json ] || fail "legacy file name not used"
}

test_write_json_fails_when_the_log_directory_is_missing() {
  load_funcs funcb
  rmdir log
  write_json app Ping v4alive_websrv 1 192.0.2.1 x 3 2> /dev/null
  assert_eq 1 $? "return status"
}

test_cmdset_ping_routers_checks_every_router_with_its_own_count() {
  load_funcs funcb func3
  cmdset_ping() { echo "$*" >> "$T/calls.cmdset_ping"; }
  cmdset_ping_routers globalnet 4 192.0.2.1,192.0.2.2
  wait
  sort "$T/calls.cmdset_ping" > "$T/sorted"
  assert_eq "globalnet 4 router 192.0.2.1 0
globalnet 4 router 192.0.2.2 1" "$(cat "$T/sorted")"
}

test_cmdset_ping_routers_with_no_router_does_nothing() {
  load_funcs funcb func3
  cmdset_ping() { echo "$*" >> "$T/calls.cmdset_ping"; }
  cmdset_ping_routers app 6 ''
  wait
  [ ! -e "$T/calls.cmdset_ping" ] || fail "cmdset_ping was called"
}

test_cmdset_ping_routers_rejects_a_wrong_argument_count() {
  load_funcs funcb func3
  cmdset_ping_routers app 6 2> /dev/null
  assert_eq 1 $? "return status"
}

test_main_script_checks_routers_once_per_layer_and_version() {
  # No loop over the routers may be left in sindan.sh.
  assert_eq 0 "$(main_text | grep -c 'for target_r in')" "inline router loops"
  # globalnet v4/v6, dns v4/v6, app v4/v6 (the DNS64 block reuses the last).
  assert_eq 6 "$(main_text | grep -c 'cmdset_ping_routers')" "call sites"
  assert_eq 6 "$(main_text | grep -c 'if \[ "\$count" -eq 0 \]; then')" "first-iteration guards"
}

run_tests
