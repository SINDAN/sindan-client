#!/bin/bash
# Tests for check_v4autoconf and check_v6autoconf (common/sindan_func2.sh)
# and the platform hooks they use (sindan_func2_os.sh).

# shellcheck disable=SC2034
. "$(dirname "$0")/lib.sh"

is_linux() { grep -q nmcli "$SINDAN_DIR/sindan_func2_os.sh"; }

# Stub the functions that read the system. The DHCPv4 lease says
# $LEASE4, the DHCPv6 lease says $LEASE6 (both are matched by the stubs of
# the platform independent tests below).
setup_stubs() {
  load_funcs funcb func2
  get_v4addr() { echo "$V4ADDR"; }
  get_dhcp4_data() { echo "$LEASE4"; }
  get_dhcp4_addr() { sed -n 's/^lease=//p'; }
  is_dhcp4_conf() { [ "$1" = "dhcp" ]; }
  get_v6addrs() { echo "$V6ADDRS"; }
  get_dhcp6_data() { echo "$LEASE6"; }
  has_dhcp6_addr() { grep -q "^lease6=$1\$"; }
  is_auto6_conf() { [ "$1" = "automatic" ]; }
  print_ra_state() { :; }
}

test_v4_dhcp_address_matches_the_interface_address() {
  setup_stubs
  V4ADDR=192.168.1.10 LEASE4="lease=192.168.1.10"
  check_v4autoconf eth0 dhcp > /dev/null
  assert_eq 0 $? "return status"
}

test_v4_dhcp_address_differs_from_the_interface_address() {
  setup_stubs
  V4ADDR=192.168.1.10 LEASE4="lease=192.168.1.99"
  check_v4autoconf eth0 dhcp > /dev/null
  assert_eq 1 $? "return status"
}

test_v4_missing_lease_or_address_is_a_failure() {
  setup_stubs
  V4ADDR=192.168.1.10 LEASE4="nothing"
  check_v4autoconf eth0 dhcp > /dev/null
  assert_eq 1 $? "no lease"
  V4ADDR="" LEASE4="lease=192.168.1.10"
  check_v4autoconf eth0 dhcp > /dev/null
  assert_eq 1 $? "no address"
}

test_v4_linklocal_and_clat_addresses_are_not_checked() {
  setup_stubs
  LEASE4="nothing"
  for a in 169.254.3.4 192.0.0.2; do
    V4ADDR=$a
    check_v4autoconf eth0 dhcp > /dev/null
    assert_eq 0 $? "return status for $a"
  done
}

test_v4_manual_configuration_is_reported() {
  setup_stubs
  out=$(check_v4autoconf eth0 manual)
  assert_eq 0 $? "return status"
  assert_eq "v4conf is manual" "$out"
}

test_v4_diagnostic_line_is_printed() {
  setup_stubs
  V4ADDR=192.168.1.10 LEASE4="lease=192.168.1.10"
  out=$(check_v4autoconf eth0 dhcp)
  assert_contains "$out" "v4addr=192.168.1.10, dhcpv4addr=192.168.1.10"
}

test_v6_slaac_only() {
  setup_stubs
  V6ADDRS=2001:db8::10
  check_v6autoconf eth0 automatic "" 2001:db8:: "LA" > /dev/null
  assert_eq 0 $? "address found"
  V6ADDRS=""
  check_v6autoconf eth0 automatic "" 2001:db8:: "LA" > /dev/null
  assert_eq 1 $? "no address"
  V6ADDRS=2001:db8::10
  check_v6autoconf eth0 automatic "" 2001:db8:: "L" > /dev/null
  assert_eq 1 $? "no A flag"
}

test_v6_managed_flag_needs_a_dhcpv6_address() {
  setup_stubs
  V6ADDRS=2001:db8::10,2001:db8::20
  LEASE6="lease6=2001:db8::20"
  check_v6autoconf eth0 automatic "M" 2001:db8:: "LA" > /dev/null
  assert_eq 0 $? "DHCPv6 address of the second entry found"
  LEASE6="lease6=2001:db8::99"
  check_v6autoconf eth0 automatic "M" 2001:db8:: "LA" > /dev/null
  assert_eq 2 $? "SLAAC ok, DHCPv6 address missing"
  V6ADDRS=""
  check_v6autoconf eth0 automatic "M" 2001:db8:: "LA" > /dev/null
  assert_eq 3 $? "nothing found"
}

test_v6_other_flag_reads_the_lease_without_a_status_change() {
  setup_stubs
  V6ADDRS=2001:db8::10 LEASE6="lease6=x"
  out=$(check_v6autoconf eth0 automatic "O" 2001:db8:: "LA")
  assert_eq 0 $? "return status"
  assert_contains "$out" "lease6=x"
}

test_v6_non_automatic_configuration_is_reported() {
  setup_stubs
  out=$(check_v6autoconf eth0 manual "" "" "")
  assert_eq "v6conf is manual" "$out"
}

test_v6_ra_state_is_printed_for_the_interface() {
  setup_stubs
  print_ra_state() { echo "RA STATE of $1"; }
  V6ADDRS=2001:db8::10
  out=$(check_v6autoconf eth0 automatic "" 2001:db8:: "LA")
  assert_contains "$out" "RA STATE of eth0"
  out=$(check_v6autoconf eth0 manual "" "" "")
  assert_not_contains "$out" "RA STATE"
}

test_wrong_argument_counts_are_rejected() {
  setup_stubs
  check_v4autoconf eth0 2> /dev/null
  assert_eq 1 $? "v4"
  check_v6autoconf eth0 automatic 2> /dev/null
  assert_eq 1 $? "v6"
}

# The platform hooks.

test_hook_dhcp4_conf_names() {
  load_funcs funcb func2
  is_dhcp4_conf dhcp || fail "dhcp rejected"
  is_dhcp4_conf manual && fail "manual accepted"
  if is_linux; then
    is_dhcp4_conf auto || fail "auto rejected"
    is_dhcp4_conf bootp && fail "bootp accepted"
  else
    is_dhcp4_conf bootp || fail "bootp rejected"
    is_dhcp4_conf auto && fail "auto accepted"
  fi
  return 0
}

test_hook_auto6_conf_names() {
  load_funcs funcb func2
  is_auto6_conf automatic || fail "automatic rejected"
  is_auto6_conf manual && fail "manual accepted"
  is_auto6_conf linklocal && fail "linklocal accepted"
  if is_linux; then
    is_auto6_conf auto || fail "auto rejected"
  else
    is_auto6_conf auto && fail "auto accepted"
  fi
  return 0
}

test_hook_dhcp4_addr_is_read_from_the_lease() {
  load_funcs funcb func2
  if is_linux; then
    # NetworkManager is not running: the dhclient/dhcpcd format is used.
    make_shim nmcli 'echo disabled'
    out=$(printf 'foo\nip_address=192.0.2.7\nbar\n' | get_dhcp4_addr)
    assert_eq 192.0.2.7 "$out" "plain format"
    make_shim nmcli 'echo enabled'
    out=$(printf 'foo\nip_address = 192.0.2.8\nbar\n' | get_dhcp4_addr)
    assert_eq 192.0.2.8 "$out" "NetworkManager format"
  else
    out=$(printf 'op = BOOTREPLY\nyiaddr = 192.0.2.9\n' | get_dhcp4_addr)
    assert_eq 192.0.2.9 "$out"
  fi
}

test_hook_dhcp6_addr_is_found_in_the_lease() {
  load_funcs funcb func2
  if is_linux; then
    echo 'dhcp6_ia_na1_ia_addr1=2001:db8::5' | has_dhcp6_addr 2001:db8::5 || fail "plain format"
    echo 'ip_address = 2001:db8::6' | has_dhcp6_addr 2001:db8::6 || fail "NM format"
  else
    echo '  IAADDR 2001:db8::7 pltime=1' | has_dhcp6_addr 2001:db8::7 || fail "macOS format"
  fi
  echo 'nothing' | has_dhcp6_addr 2001:db8::5 && fail "matched an unrelated lease"
  return 0
}

run_tests
