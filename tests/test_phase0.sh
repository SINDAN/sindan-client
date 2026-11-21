#!/bin/bash
# Tests for is_available and the handling of unimplemented Phase 0 probes.
#
# Several probes print the placeholder "TBD". It used to be recorded as if it
# were a measurement, and clock_state ("synchronized=" + value) was never
# empty, so even a failed probe produced a record.

# shellcheck disable=SC2034
. "$(dirname "$0")/lib.sh"

test_is_available() {
  load_funcs funcb
  is_available "Intel Core" || fail "a value was rejected"
  is_available "0" || fail "zero was rejected"
  is_available "" && fail "an empty value was accepted"
  is_available "TBD" && fail "the TBD placeholder was accepted"
  return 0
}

test_phase0_records_use_is_available() {
  local s="$SINDAN_DIR/sindan.sh" v
  for v in hw_info clock_state clock_src; do
    grep -q "^if is_available \"\\\$$v\"; then" "$s" || fail "$v is not checked with is_available"
  done
  # The probes of the active (not commented out) records must not be tested
  # with a bare -n any more.
  if sed -n '/^layer="hardware"/,/^echo " done."/p' "$s" |
     grep -E '^if \[ -n "\$(hw_info|clock_state|clock_src|cpu_freq|cpu_volt|cpu_temp)" \]'; then
    fail "a Phase 0 value is still tested with [ -n ]"
  fi
}

test_clock_state_is_not_built_from_an_empty_value() {
  # "synchronized=" must be added only after the probe succeeded.
  if grep -n 'clock_state="synchronized=\$(get_clock_state)"' "$SINDAN_DIR/sindan.sh"; then
    fail "clock_state is built before it is checked"
  fi
  grep -q 'clock_state="synchronized=\$clock_state"' "$SINDAN_DIR/sindan.sh" ||
    fail "synchronized= prefix not found"
}

run_tests
