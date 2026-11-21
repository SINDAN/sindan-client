#!/bin/bash
# Tests for do_sshkeyscan and cmdset_ssh.
#
# A stray line continuation after the usage message used to turn the
# following "return 1" into arguments of echo, so the argument check never
# returned and ssh-keyscan was executed with garbage arguments.

. "$(dirname "$0")/lib.sh"

# Install an ssh-keyscan shim. SSHKEYSCAN_RC (default 0) is its exit status.
setup_sshkeyscan() {
  load_funcs funcb func6
  make_shim ssh-keyscan 'printf "%s\n" "$*" >> "$T/calls.ssh-keyscan"
echo "host.example ssh-ed25519 AAAAC3NzaC1lZDI1NTE5"
exit "${SSHKEYSCAN_RC:-0}"'
}

test_wrong_argument_count_returns_an_error() {
  setup_sshkeyscan
  for args in "" "4" "4 host.example"; do
    # shellcheck disable=SC2086
    err=$(do_sshkeyscan $args 2>&1 > /dev/null)
    rc=$?
    assert_eq 1 "$rc" "return status for args [$args]"
    assert_eq "ERROR: do_sshkeyscan <version> <target> <key_type>." "$err" \
              "error message for args [$args]"
  done
}

test_wrong_argument_count_does_not_run_ssh_keyscan() {
  setup_sshkeyscan
  do_sshkeyscan 4 host.example > /dev/null 2>&1
  assert_no_call ssh-keyscan
}

test_arguments_are_passed_to_ssh_keyscan() {
  setup_sshkeyscan
  out=$(do_sshkeyscan 6 host.example ed25519)
  assert_eq 0 $? "return status"
  assert_eq "host.example ssh-ed25519 AAAAC3NzaC1lZDI1NTE5" "$out"
  assert_eq "-6 -T 5 -t ed25519 host.example" "$(cat "$T/calls.ssh-keyscan")"
}

test_failure_status_is_propagated() {
  setup_sshkeyscan
  export SSHKEYSCAN_RC=1
  do_sshkeyscan 4 host.example ed25519 > /dev/null
  assert_eq 1 $? "return status"
}

test_cmdset_ssh_records_success() {
  require_json_tool
  setup_sshkeyscan
  cmdset_ssh app 4 sshsrv host.example_ed25519 0
  assert_eq "-4 -T 5 -t ed25519 host.example" "$(cat "$T/calls.ssh-keyscan")"
  f=$(log_file app v4ssh_sshsrv 0) || fail "log not written"
  assert_eq 1 "$(json_get "$f" result)"
  assert_eq host.example "$(json_get "$f" target)"
}

test_cmdset_ssh_records_failure() {
  require_json_tool
  setup_sshkeyscan
  export SSHKEYSCAN_RC=1
  cmdset_ssh app 4 sshsrv host.example_ed25519 0
  f=$(log_file app v4ssh_sshsrv 0) || fail "log not written"
  assert_eq 0 "$(json_get "$f" result)"
}

run_tests
