#!/bin/bash
# Tests for linux/sindan-config (the whiptail tool that edits sindan.conf)
# and linux/setup_watchdog.sh.
#
# sindan-config looked for "KEY=" at the start of a line, so it did not find
# the "readonly KEY=" lines of sindan.conf.example and appended a second,
# plain assignment that failed with "readonly variable". It also replaced the
# configuration file with an empty one when lua failed.

# shellcheck disable=SC2034
. "$(dirname "$0")/lib.sh"

linux_only() { [ -f "$SINDAN_DIR/sindan-config" ] || skip "Linux only"; }

# Put a "lua" command in PATH. sindan-config needs it; texlua (of TeX Live)
# is a Lua interpreter too. Skip the test if there is none.
setup_lua() {
  linux_only
  local real
  for real in lua lua5.4 lua5.3 texlua; do
    real=$(command -v "$real") && break
    real=
  done
  [ -n "$real" ] || skip "no Lua interpreter"
  # "lua -" reads the script from the standard input; texlua does not know
  # "-", so the shim saves the script to a file first.
  make_shim lua "f=\$(mktemp \"\$T/lua.XXXXXX\"); cat > \"\$f\"; shift; \"$real\" \"\$f\" \"\$@\"; s=\$?; rm -f \"\$f\"; exit \$s"
}

# Read the functions of sindan-config (everything before the main part).
load_config_tool() {
  sed '/^# MAIN$/,$d' "$SINDAN_DIR/sindan-config" > "$T/sindan-config.funcs"
  # shellcheck disable=SC1091
  . "$T/sindan-config.funcs"
}

write_conf() {
  CONFIG="$T/sindan.conf"
  cat > "$CONFIG" <<'CONF'
# SINDAN Configuration file
readonly MODE=client
# maximum retry count
readonly MAX_RETRY=10
VERBOSE=yes
#RECONNECT=no
readonly PING4_SRVS="8.8.8.8,1.1.1.1"
CONF
}

test_get_config_var_reads_plain_and_readonly_lines() {
  setup_lua; load_config_tool; write_conf
  assert_eq client "$(get_config_var MODE "$CONFIG")" "readonly line"
  assert_eq yes "$(get_config_var VERBOSE "$CONFIG")" "plain line"
  assert_eq '"8.8.8.8,1.1.1.1"' "$(get_config_var PING4_SRVS "$CONFIG")" "quoted value"
  assert_eq "" "$(get_config_var DEVNAME "$CONFIG")" "missing key"
}

test_set_config_var_keeps_the_readonly_prefix() {
  setup_lua; load_config_tool; write_conf
  set_config_var MAX_RETRY 5 "$CONFIG"
  assert_eq 0 $? "return status"
  assert_eq 1 "$(grep -c 'MAX_RETRY' "$CONFIG")" "number of MAX_RETRY lines"
  assert_contains "$(cat "$CONFIG")" "readonly MAX_RETRY=5"
  # The other lines are kept.
  assert_contains "$(cat "$CONFIG")" "# maximum retry count"
  assert_contains "$(cat "$CONFIG")" "readonly MODE=client"
  # The result can be read by sindan.sh.
  out=$(bash -c ". \"$CONFIG\"; echo \"\$MAX_RETRY\"" 2>&1)
  assert_eq 5 "$out" "value read by the shell"
}

test_set_config_var_handles_plain_commented_and_missing_keys() {
  setup_lua; load_config_tool; write_conf
  set_config_var VERBOSE no "$CONFIG"
  set_config_var RECONNECT yes "$CONFIG"
  set_config_var DEVNAME wlan0 "$CONFIG"
  assert_contains "$(cat "$CONFIG")" "
VERBOSE=no
"
  assert_contains "$(cat "$CONFIG")" "
RECONNECT=yes
"
  assert_not_contains "$(cat "$CONFIG")" "#RECONNECT"
  assert_eq DEVNAME=wlan0 "$(tail -n 1 "$CONFIG")" "a new key is appended"
}

test_a_value_with_spaces_and_quotes_is_stored_as_given() {
  setup_lua; load_config_tool; write_conf
  set_config_var PING4_SRVS '"1.1.1.1,9.9.9.9"' "$CONFIG"
  assert_contains "$(cat "$CONFIG")" 'readonly PING4_SRVS="1.1.1.1,9.9.9.9"'
}

test_the_configuration_is_kept_when_lua_fails() {
  setup_lua; load_config_tool; write_conf
  cp "$CONFIG" "$T/before"
  make_shim lua 'exit 1'
  set_config_var MAX_RETRY 5 "$CONFIG" 2> /dev/null
  assert_eq 1 $? "return status"
  assert_eq "$(cat "$T/before")" "$(cat "$CONFIG")" "configuration file"
  [ ! -e "$CONFIG.bak" ] || fail "the temporary file was left"
}

test_the_file_mode_is_kept() {
  setup_lua; load_config_tool; write_conf
  chmod 600 "$CONFIG"
  set_config_var MAX_RETRY 5 "$CONFIG"
  # shellcheck disable=SC2012
  assert_eq "-rw-------" "$(ls -l "$CONFIG" | cut -c1-10)" "file mode"
}

# The whiptail shim prints WHIPTAIL_ANSWER (the text of an input box) like
# the real one, to the standard error output.
setup_whiptail() {
  make_shim whiptail 'case "$1" in --inputbox) printf "%s" "$WHIPTAIL_ANSWER" >&2 ;; esac'
}

test_retry_count_is_set_from_the_input_box() {
  setup_lua; setup_whiptail; load_config_tool; write_conf
  INTERACTIVE=True WHIPTAIL_ANSWER=7 do_set_retry
  assert_contains "$(cat "$CONFIG")" "readonly MAX_RETRY=7"
}

test_retry_count_must_be_a_number() {
  setup_lua; setup_whiptail; load_config_tool; write_conf
  cp "$CONFIG" "$T/before"
  for v in abc "" "-1" "1 2"; do
    INTERACTIVE=True WHIPTAIL_ANSWER=$v do_set_retry
    assert_eq 1 $? "return status for [$v]"
  done
  assert_eq "$(cat "$T/before")" "$(cat "$CONFIG")" "configuration file"
}

test_device_name_must_not_be_empty() {
  setup_lua; setup_whiptail; load_config_tool; write_conf
  INTERACTIVE=True WHIPTAIL_ANSWER="" do_set_devname
  assert_eq 1 $? "return status"
  assert_eq "" "$(get_config_var DEVNAME "$CONFIG")"
  INTERACTIVE=True WHIPTAIL_ANSWER=eth0 do_set_devname
  assert_eq eth0 "$(get_config_var DEVNAME "$CONFIG")"
}

test_target_servers_are_stored_in_quotes() {
  setup_lua; setup_whiptail; load_config_tool; write_conf
  INTERACTIVE=True WHIPTAIL_ANSWER="192.0.2.1,192.0.2.2" do_set_pingv4
  assert_contains "$(cat "$CONFIG")" 'readonly PING4_SRVS="192.0.2.1,192.0.2.2"'
}

test_the_tool_reports_a_missing_command() {
  linux_only
  mkdir -p "$T/emptybin"
  out=$(cd "$T" && PATH="$T/emptybin" /bin/sh "$SINDAN_DIR/sindan-config" 2>&1)
  assert_eq 1 $? "return status"
  assert_contains "$out" "ERROR: lua is not found."
  [ ! -e "$T/sindan.conf" ] || fail "the configuration file was created"
}

####################
## setup_watchdog.sh

# Run setup_watchdog.sh with files in $T instead of the system files.
run_watchdog() {
  linux_only
  SUDO="" \
  MODEL_FILE="$T/model" \
  BOOT_CONFIG="$T/config.txt" \
  MODPROBE_CONF="$T/bcm2835-wdt.conf" \
  SYSTEM_CONF="$T/system.conf" \
  bash "$SINDAN_DIR/setup_watchdog.sh" 2>&1
}

setup_pi() {
  linux_only
  printf 'Raspberry Pi 4 Model B Rev 1.4\0' > "$T/model"
  printf 'arm_64bit=1\n' > "$T/config.txt"
  printf '[Manager]\n#RuntimeWatchdogSec=0\n#ShutdownWatchdogSec=10min\n' > "$T/system.conf"
}

test_watchdog_is_set_up() {
  setup_pi
  out=$(run_watchdog)
  assert_eq 0 $? "return status: $out"
  assert_eq 1 "$(grep -c '^dtparam=watchdog=on$' "$T/config.txt")" "dtparam line"
  assert_contains "$(cat "$T/config.txt")" "arm_64bit=1" "the old line is kept"
  assert_eq "options bcm2835_wdt heartbeat=14 nowayout=0" "$(cat "$T/bcm2835-wdt.conf")"
  assert_contains "$(cat "$T/system.conf")" "
RuntimeWatchdogSec=14
"
  assert_contains "$(cat "$T/system.conf")" "#ShutdownWatchdogSec=10min" "other lines are kept"
}

test_watchdog_setup_can_run_twice() {
  setup_pi
  run_watchdog > /dev/null
  cp "$T/config.txt" "$T/config.1"; cp "$T/system.conf" "$T/system.1"
  out=$(run_watchdog)
  assert_eq 0 $? "return status: $out"
  assert_eq "$(cat "$T/config.1")" "$(cat "$T/config.txt")" "config.txt"
  assert_eq "$(cat "$T/system.1")" "$(cat "$T/system.conf")" "system.conf"
}

test_watchdog_replaces_another_value() {
  setup_pi
  printf '[Manager]\nRuntimeWatchdogSec=30\n' > "$T/system.conf"
  run_watchdog > /dev/null
  assert_eq 1 "$(grep -c 'RuntimeWatchdogSec' "$T/system.conf")" "number of lines"
  assert_contains "$(cat "$T/system.conf")" "RuntimeWatchdogSec=14"
}

test_watchdog_reports_a_missing_systemd_line() {
  setup_pi
  printf '[Manager]\n' > "$T/system.conf"
  out=$(run_watchdog)
  assert_eq 1 $? "return status"
  assert_contains "$out" "has no RuntimeWatchdogSec line"
}

test_watchdog_refuses_other_boards() {
  setup_pi
  printf 'Some Other Board\0' > "$T/model"
  cp "$T/config.txt" "$T/config.before"
  out=$(run_watchdog)
  assert_eq 1 $? "return status"
  assert_contains "$out" "this is not a Raspberry Pi"
  assert_eq "$(cat "$T/config.before")" "$(cat "$T/config.txt")" "config.txt"
  [ ! -e "$T/bcm2835-wdt.conf" ] || fail "the module option file was written"
}

run_tests
