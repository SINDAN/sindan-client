#!/bin/bash
# Tests for check_v4addr and is_usable_v4addr_type.
#
# Phases 4 to 6 are skipped for IPv4 unless the address type is usable.
# The shared address space (100.64.0.0/10, carrier-grade NAT) is common on
# mobile networks and some ISPs, and it does reach the Internet, so it must
# not be excluded.

. "$(dirname "$0")/lib.sh"

# Check the type of the address and whether the type is usable.
# expect_type <address> <expected type> <usable: yes|no>
expect_type() {
  local type
  type=$(check_v4addr "$1")
  assert_eq "$2" "$type" "type of [$1]"
  if is_usable_v4addr_type "$type"; then
    assert_eq "$3" yes "[$1] ($type) is usable"
  else
    assert_eq "$3" no "[$1] ($type) is not usable"
  fi
}

test_private_addresses_are_usable() {
  load_funcs funcb func2
  expect_type 10.0.0.1 private yes
  expect_type 172.16.5.4 private yes
  expect_type 172.31.255.254 private yes
  expect_type 192.168.1.2 private yes
}

test_shared_address_space_is_usable() {
  load_funcs funcb func2
  expect_type 100.64.0.0 shared yes
  expect_type 100.100.100.100 shared yes
  expect_type 100.127.255.255 shared yes
}

test_global_addresses_are_usable() {
  load_funcs funcb func2
  expect_type 8.8.8.8 global yes
  # Just outside of 100.64.0.0/10.
  expect_type 100.63.255.255 global yes
  expect_type 100.128.0.0 global yes
}

test_special_purpose_addresses_are_not_usable() {
  load_funcs funcb func2
  expect_type 0.0.0.0 this-host no
  expect_type 127.0.0.1 loopback no
  expect_type 169.254.10.20 linklocal no
  # CLAT address of 464XLAT: there is no real IPv4 connectivity.
  expect_type 192.0.0.2 ipv4-service-continuity no
  expect_type 192.0.2.1 documentation no
  expect_type 224.0.0.1 multicast no
}

test_missing_or_invalid_addresses_are_not_usable() {
  load_funcs funcb func2
  # No address configured and a malformed address.
  assert_eq "not IPv4 address" "$(check_v4addr '')"
  is_usable_v4addr_type "$(check_v4addr '')" && fail "empty address is usable"
  is_usable_v4addr_type "$(check_v4addr 300.1.1.1)" && fail "malformed address is usable"
  # EXCL_IPv4=yes sets the type "linklocal".
  is_usable_v4addr_type linklocal && fail "linklocal is usable"
  is_usable_v4addr_type '' && fail "empty type is usable"
  return 0
}

test_wrong_argument_count_is_rejected() {
  load_funcs funcb func2
  is_usable_v4addr_type 2> /dev/null
  assert_eq 1 $? "return status without arguments"
  is_usable_v4addr_type private global 2> /dev/null
  assert_eq 1 $? "return status with two arguments"
}

run_tests
