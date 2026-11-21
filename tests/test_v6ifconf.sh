#!/bin/bash
# Tests for get_v6ifconf.
#
# Linux: the function read $2 to detect a WWAN interface, but it required
# exactly one argument and the caller passed one, so the WWAN branch was
# unreachable. macOS: the "linklocal" branch redirected to /dev/nul (typo).

# shellcheck disable=SC2034
. "$(dirname "$0")/lib.sh"

is_linux() { grep -q nmcli "$SINDAN_DIR/sindan_func2.sh"; }

test_main_script_passes_the_interface_type() {
  if is_linux; then
    grep -q 'get_v6ifconf "\$ifname" "\$IFTYPE"' "$SINDAN_DIR/sindan.sh" ||
      fail "sindan.sh does not pass IFTYPE to get_v6ifconf"
  else
    grep -q 'get_v6ifconf "\$IFTYPE"' "$SINDAN_DIR/sindan.sh" ||
      fail "sindan.sh does not pass IFTYPE to get_v6ifconf"
  fi
}

test_linux_wwan_uses_the_wwan_port() {
  is_linux || skip "Linux only"
  load_funcs funcb func2
  make_shim nmcli 'echo "$*" >> "$T/calls.nmcli"
case "$*" in
  networking) echo enabled ;;
  "-g general.con-path device show ttyUSB2") echo /con/wwan ;;
  "-g general.con-path device show wwan0") echo /con/wrong ;;
  "-g ipv6.method connection show /con/wwan") echo auto ;;
  *) echo "unexpected: $*" >&2; exit 1 ;;
esac'
  get_wwan_port() { echo ttyUSB2; }
  assert_eq auto "$(get_v6ifconf wwan0 WWAN)"
}

test_linux_other_types_use_the_interface_directly() {
  is_linux || skip "Linux only"
  load_funcs funcb func2
  make_shim nmcli 'case "$*" in
  networking) echo enabled ;;
  "-g general.con-path device show eth0") echo /con/eth ;;
  "-g ipv6.method connection show /con/eth") echo manual ;;
  *) echo "unexpected: $*" >&2; exit 1 ;;
esac'
  assert_eq manual "$(get_v6ifconf eth0 Wired)"
}

test_linux_wrong_argument_count_is_rejected() {
  is_linux || skip "Linux only"
  load_funcs funcb func2
  get_v6ifconf eth0 2> /dev/null
  assert_eq 1 $? "return status"
}

test_macos_linklocal_branch_does_not_use_a_typo_device() {
  is_linux && skip "macOS only"
  assert_eq 0 "$(grep -c '/dev/nul\b' "$SINDAN_DIR/sindan_func2.sh")" "typo count"
  load_funcs funcb func2
  make_shim networksetup 'echo "IPv6: Off"; echo "IPv6 IP address: none"'
  assert_eq linklocal "$(get_v6ifconf Wi-Fi)"
}

run_tests
