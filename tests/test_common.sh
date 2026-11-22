#!/bin/bash
# Tests for the files shared by all platforms (common/) and how sindan.sh
# loads them.

# shellcheck disable=SC2034
. "$(dirname "$0")/lib.sh"

# Run a copy of the platform directory next to common/ from another working
# directory and report the first error about a missing file. The empty
# sindan.conf makes the script stop at the parameter check, which is after
# all function files have been read.
test_sindan_sh_finds_the_function_files_from_any_directory() {
  local root="$T/repo" plat
  plat=$(basename "$SINDAN_DIR")
  mkdir -p "$root" "$T/elsewhere"
  cp -R "$SINDAN_DIR" "$root/$plat"
  cp -R "$SINDAN_DIR/../common" "$root/common"
  : > "$root/$plat/sindan.conf"
  cd "$T/elsewhere" || fail "cannot cd"
  out=$(bash "$root/$plat/sindan.sh" 2>&1 < /dev/null)
  assert_not_contains "$out" "No such file"
  assert_not_contains "$out" "cannot open"
  # A mistyped line in the list of the sourced files shows up as an unknown
  # command (a stray "+" from a patch once did).
  assert_not_contains "$out" "command not found"
  assert_contains "$out" "is null in configuration file" "the script did not reach the parameter check"
}

# The script changes to its own directory. It must also work when it is
# started with a relative path, and it must not try to change the directory
# a second time (that cd used to be relative to the new directory).
test_sindan_sh_works_when_started_with_a_relative_path() {
  local root="$T/repo" plat
  plat=$(basename "$SINDAN_DIR")
  mkdir -p "$root"
  cp -R "$SINDAN_DIR" "$root/$plat"
  cp -R "$SINDAN_DIR/../common" "$root/common"
  : > "$root/$plat/sindan.conf"
  cd "$root" || fail "cannot cd"
  out=$(bash "$plat/sindan.sh" 2>&1 < /dev/null)
  assert_not_contains "$out" "No such file"
  assert_not_contains "$out" "command not found"
  assert_contains "$out" "is null in configuration file" "the script did not reach the parameter check"
}

test_get_rtt_reads_the_linux_format() {
  load_funcs funcb func3
  out=$(echo "rtt min/avg/max/mdev = 1.100/2.200/3.300/0.400 ms" | get_rtt)
  assert_eq "1.100 2.200 3.300 0.400" "$out"
}

test_get_rtt_reads_the_macos_format() {
  load_funcs funcb func3
  out=$(echo "round-trip min/avg/max/stddev = 1.100/2.200/3.300/0.400 ms" | get_rtt)
  assert_eq "1.100 2.200 3.300 0.400" "$out"
}

test_no_function_file_is_duplicated_between_platforms() {
  local f name
  for f in "$SINDAN_DIR/../common"/sindan_*.sh; do
    name=$(basename "$f")
    [ ! -e "$SINDAN_DIR/$name" ] || fail "$name exists in both the platform directory and common/"
  done
}

test_phase_0_lives_only_in_common() {
  assert_eq 0 "$(grep -c '^echo "Phase 0:' "$SINDAN_DIR/sindan.sh")" "phase 0 in sindan.sh"
  assert_eq 1 "$(grep -c '^echo "Phase 0:' "$SINDAN_DIR/../common/sindan_phase0.sh")" \
            "phase 0 in common/sindan_phase0.sh"
  grep -q '^\. "\$COMMON_DIR"/sindan_phase0.sh$' "$SINDAN_DIR/sindan.sh" ||
    fail "sindan.sh does not read sindan_phase0.sh"
}

test_phases_3_to_7_live_only_in_common() {
  assert_eq 0 "$(grep -c '^echo "Phase [3-7]:' "$SINDAN_DIR/sindan.sh")" "phases in sindan.sh"
  assert_eq 5 "$(grep -c '^echo "Phase [3-7]:' "$SINDAN_DIR/../common/sindan_phase3_7.sh")" \
            "phases in common/sindan_phase3_7.sh"
  grep -q '^\. "\$COMMON_DIR"/sindan_phase3_7.sh$' "$SINDAN_DIR/sindan.sh" ||
    fail "sindan.sh does not read sindan_phase3_7.sh"
}

# Copy the tree, write a configuration (the arguments, one assignment per
# argument), run sindan.sh of the copy from another directory and print its
# output. SINDAN_EDIT, if set, is a sed script applied to the copy of sindan.sh.
run_sindan() {
  local root="$T/repo" plat
  plat=$(basename "$SINDAN_DIR")
  mkdir -p "$root" "$T/elsewhere"
  cp -R "$SINDAN_DIR" "$root/$plat"
  cp -R "$SINDAN_DIR/../common" "$root/common"
  printf '%s\n' "$@" > "$root/$plat/sindan.conf"
  [ -z "${SINDAN_EDIT:-}" ] || sed -i.bak "$SINDAN_EDIT" "$root/$plat/sindan.sh"
  cd "$T/elsewhere" || fail "cannot cd"
  bash "$root/$plat/sindan.sh" 2>&1 < /dev/null
}

# The parameters that every platform needs.
BASE_CONF="PIDFILE=/tmp/sindan-test.pid MAX_RETRY=1 IFTYPE=Ethernet PING4_SRVS=a
PING6_SRVS=a FQDNS=a PDNS4_SRVS=a PDNS6_SRVS=a WEB4_SRVS=a WEB6_SRVS=a
SSH4_SRVS=a SSH6_SRVS=a"

test_preparation_reports_a_missing_shared_parameter() {
  out=$(run_sindan PIDFILE=/tmp/x)
  assert_contains "$out" "ERROR: MAX_RETRY is null in configuration file."
}

test_preparation_reports_a_missing_platform_parameter() {
  local params
  params=$(sed -n 's/^OS_REQUIRED_PARAMS="\(.*\)"$/\1/p' "$SINDAN_DIR/sindan.sh")
  [ -n "$params" ] || skip "no platform parameter on this platform"
  # shellcheck disable=SC2086
  out=$(run_sindan $BASE_CONF)
  assert_contains "$out" "ERROR: ${params%% *} is null in configuration file."
}

# A value with a space must not break the test of the parameter.
test_preparation_accepts_a_parameter_value_with_spaces() {
  # shellcheck disable=SC2086
  out=$(run_sindan $BASE_CONF 'FQDNS="a b"')
  assert_not_contains "$out" "[:"
  assert_not_contains "$out" "ERROR: FQDNS"
}

test_preparation_reports_a_missing_command() {
  # shellcheck disable=SC2086
  SINDAN_EDIT='s/^OS_REQUIRED_PARAMS=.*/OS_REQUIRED_PARAMS=""/; s/^OS_REQUIRED_CMDS=.*/OS_REQUIRED_CMDS="sindan-no-such-command"/'
  export SINDAN_EDIT
  # shellcheck disable=SC2086
  out=$(run_sindan $BASE_CONF)
  assert_contains "$out" "ERROR: sindan-no-such-command is not found."
}

run_tests
