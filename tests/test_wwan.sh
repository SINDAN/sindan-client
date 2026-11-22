#!/bin/bash
# Tests for the ModemManager (mmcli) based WWAN functions of the Linux
# scripts: get_ifstatus (WWAN), get_wwan_port, get_wwan_info and
# get_wwan_environment.
#
# The variables were not quoted: the modem information was passed to
# "echo $modem_info | grep", so a "*" in it was expanded to the file names of
# the current directory.

# shellcheck disable=SC2034
. "$(dirname "$0")/lib.sh"

linux_only() { grep -q 'mmcli' "$SINDAN_DIR/sindan_func1.sh" || skip "Linux only"; }

MODEM_PATH=/org/freedesktop/ModemManager1/Modem/0

# The mmcli shim prints fixed texts and records its arguments in
# $T/calls.mmcli. MMCLI_EXTRA is added to the modem information.
setup_mmcli() {
  linux_only
  export MODEM_PATH
  make_shim mmcli '
echo "$*" >> "$T/calls.mmcli"
case "$1 $3" in
  "-L ") echo "$MODEM_PATH [Quectel] EC25" ;;
  "-m ")
    cat <<INFO
  --------------------------------
  General  |                 path: $MODEM_PATH
  --------------------------------
  System   |               device: /sys/devices/test
           |              drivers: qmi_wwan
           |         primary port: cdc-wdm0
           |                ports: cdc-wdm0 (qmi), wwan0 (net)
  Status   |                 lock: sim-pin2
           |                state: connected
  3GPP     |  bearers: /org/freedesktop/ModemManager1/Bearer/1
${MMCLI_EXTRA:-}
INFO
    ;;
  "-m --signal-get") echo "  LTE | rssi: -70.00 dBm | refresh rate: 10 seconds" ;;
  "-m --location-get") echo "  3GPP | operator code: 44010" ;;
  "-m --3gpp-scan=x") ;;
  "-b ") echo "  Properties |  interface: wwan0  apn: internet" ;;
esac'
}

test_ifstatus_of_a_wwan_interface() {
  setup_mmcli
  load_funcs funcb func1
  out=$(get_ifstatus wwan0 WWAN)
  assert_eq 0 $? "return status"
  assert_eq connected "$out"
}

test_wwan_port_is_found_by_the_interface_name() {
  setup_mmcli
  load_funcs funcb func1
  assert_eq cdc-wdm0 "$(get_wwan_port wwan0)"
}

test_wwan_info_collects_the_modem_signal_and_location() {
  setup_mmcli
  load_funcs funcb func1
  out=$(get_wwan_info wwan0)
  assert_contains "$out" "MODEM INFO:"
  assert_contains "$out" "primary port: cdc-wdm0"
  assert_contains "$out" "BEARER INFO:"
  assert_contains "$out" "SIGNAL INFO:"
  assert_contains "$out" "rssi: -70.00 dBm"
  assert_contains "$out" "3GPP INFO:"
  assert_contains "$out" "operator code: 44010"
  # The modem and the bearer are given as separate arguments.
  assert_contains "$(cat "$T/calls.mmcli")" "-m $MODEM_PATH --signal-get"
  assert_contains "$(cat "$T/calls.mmcli")" "-b 1"
}

test_other_interface_is_not_matched() {
  setup_mmcli
  load_funcs funcb func1
  assert_eq "" "$(get_wwan_port wwan9)"
  assert_eq "" "$(get_wwan_info wwan9)"
}

# A "*" in the information must not be expanded to the files of the
# current directory.
test_a_star_in_the_modem_information_is_not_expanded() {
  MMCLI_EXTRA='  Note     |  a * b'
  export MMCLI_EXTRA
  setup_mmcli
  load_funcs funcb func1
  : > wwan9
  assert_eq "" "$(get_wwan_port wwan9)" "get_wwan_port"
  assert_eq "" "$(get_wwan_info wwan9)" "get_wwan_info"
  get_ifstatus wwan9 WWAN > /dev/null
  assert_eq "" "$(get_ifstatus wwan9 WWAN)" "get_ifstatus"
}

run_tests
