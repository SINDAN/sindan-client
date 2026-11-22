#!/bin/bash
# Tests for the flow of the shared Phase 1 (common/sindan_phase1.sh) with
# stubbed platform functions: when the WLAN environment is taken and what
# happens for a platform that cannot get WWAN information.

# shellcheck disable=SC2034
. "$(dirname "$0")/lib.sh"

# Stub every function that Phase 1 calls. The events are appended to
# $T/events in the order of the calls.
setup_phase1() {
  SUCCESS=1 FAIL=0 INFO=2 MAX_RETRY=1 VERBOSE=no RECONNECT=yes
  ev() { echo "$*" >> "$T/events"; }
  sleep() { :; }
  write_json() { ev "write $3"; }
  get_ifname() { echo en0; }
  do_ifdown() { ev "ifdown $*"; }
  do_ifup() { ev "ifup $*"; }
  get_ifstatus() { echo up; }
  get_macaddr() { echo 00:11:22:33:44:55; }
  get_ifmtu() { echo 1500; }
  get_wlan_info() { ev "wlan_info $*"; echo "WLAN-INFO-DATA"; }
  for fn in ssid bssid rate mcs nss mode band channel chband rssi noise quality; do
    eval "get_wlan_$fn() { ev \"wlan_$fn \$*\"; echo v; }"
  done
  # Only the macOS style reads the WLAN information from STDIN; do not wait
  # for input in the Linux style.
  get_wlan_environment() {
    local data=""
    [ "$WLAN_ENVIRONMENT_FIRST" = "no" ] && data=$(cat)
    ev "wlan_environment $* [$data]"
    echo "env"
  }
  get_wwan_info() { :; }
  get_ether_mediatype() { echo 1000baseT; }
}

run_phase1() {
  # shellcheck disable=SC1091
  . "$SINDAN_DIR/../common/sindan_phase1.sh"
}

test_linux_style_takes_the_environment_before_the_restart() {
  setup_phase1
  IFTYPE=Wi-Fi WLAN_ENVIRONMENT_FIRST=yes
  run_phase1 > /dev/null
  first=$(grep -n . "$T/events" | grep -E "write wlan_environment|ifdown" | head -2 | cut -d: -f2-)
  assert_eq "write wlan_environment
ifdown en0 Wi-Fi" "$first"
  assert_eq 1 "$(grep -c '^write wlan_environment' "$T/events")" "environment records"
}

test_macos_style_takes_the_environment_from_the_wlan_info() {
  setup_phase1
  IFTYPE=Wi-Fi WLAN_ENVIRONMENT_FIRST=no
  run_phase1 > /dev/null
  grep -q '^wlan_environment en0 \[WLAN-INFO-DATA\]$' "$T/events" ||
    fail "environment was not read from the WLAN information: $(cat "$T/events")"
  assert_eq 1 "$(grep -c '^write wlan_environment' "$T/events")" "environment records"
  # It must come after the WLAN information, and after the restart.
  order=$(grep -nE "^ifdown|^wlan_info|^write wlan_environment" "$T/events" | cut -d: -f2 | tr '\n' ',')
  assert_eq "ifdown en0 Wi-Fi,wlan_info en0,write wlan_environment," "$order"
}

test_wlan_functions_get_the_ifname_and_the_wlan_info() {
  setup_phase1
  IFTYPE=Wi-Fi WLAN_ENVIRONMENT_FIRST=no
  run_phase1 > /dev/null
  for fn in ssid bssid rate mcs nss mode rssi noise quality; do
    grep -q "^wlan_$fn en0\$" "$T/events" || fail "get_wlan_$fn was not called with the ifname"
  done
}

test_no_environment_for_other_interface_types() {
  setup_phase1
  IFTYPE=Ethernet WLAN_ENVIRONMENT_FIRST=yes
  run_phase1 > /dev/null
  assert_eq 0 "$(grep -c 'environment' "$T/events")" "environment events"
  assert_eq 1 "$(grep -c '^write ether_media' "$T/events")" "media records"
}

test_wwan_without_information_is_reported() {
  setup_phase1
  IFTYPE=WWAN WLAN_ENVIRONMENT_FIRST=no VERBOSE=yes
  out=$(run_phase1)
  assert_contains "$out" "WWAN information is not available."
  assert_not_contains "$out" "apn:"
  assert_eq 0 "$(grep -c '^write wwan' "$T/events")" "WWAN records"
}

test_the_platform_script_sets_the_environment_timing() {
  grep -qE '^WLAN_ENVIRONMENT_FIRST="(yes|no)"$' "$SINDAN_DIR/sindan.sh" ||
    fail "sindan.sh does not set WLAN_ENVIRONMENT_FIRST to yes or no"
  # Phases 1 and 2 live only in common/.
  assert_eq 0 "$(grep -c '^echo "Phase [12]:' "$SINDAN_DIR/sindan.sh")" "phases in sindan.sh"
  assert_eq 2 "$(grep -hc '^echo "Phase [12]:' "$SINDAN_DIR"/../common/sindan_phase[12].sh | paste -sd+ - | bc)" \
            "phases in common/"
}

run_tests
