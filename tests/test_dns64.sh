#!/bin/bash
# Tests for check_dns64_any.
#
# sindan.sh used to call check_dns64 in the loop over the IPv6 name servers
# and keep only the last result, so a DNS64 server was missed unless it was
# the last one in the list.

. "$(dirname "$0")/lib.sh"

# check_dns64 is replaced by a stub: servers listed in DNS64_SERVERS answer yes.
setup_stub() {
  load_funcs funcb func5
  check_dns64() {
    echo "$1" >> "$T/calls.check_dns64"
    case " $DNS64_SERVERS " in
      *" $1 "*) echo yes ;;
      *) echo no ;;
    esac
  }
}

test_dns64_on_the_first_server_is_found() {
  setup_stub
  DNS64_SERVERS="2001:db8::1"
  assert_eq yes "$(check_dns64_any 2001:db8::1,2001:db8::2)"
}

test_dns64_on_the_last_server_is_found() {
  setup_stub
  DNS64_SERVERS="2001:db8::2"
  assert_eq yes "$(check_dns64_any 2001:db8::1,2001:db8::2)"
}

test_no_dns64_server_gives_no() {
  setup_stub
  DNS64_SERVERS=""
  assert_eq no "$(check_dns64_any 2001:db8::1,2001:db8::2)"
}

test_empty_list_gives_no() {
  setup_stub
  DNS64_SERVERS="2001:db8::1"
  assert_eq no "$(check_dns64_any '')"
}

test_wrong_argument_count_is_rejected() {
  setup_stub
  check_dns64_any 2> /dev/null
  assert_eq 1 $? "return status"
}

test_main_script_checks_dns64_once_for_all_servers() {
  # The result must not be assigned inside the loop over the name servers.
  assert_eq 0 "$(main_text | grep -c 'exist_dns64=\$(check_dns64 ')" \
            "per-server assignment"
  assert_eq 1 "$(main_text | grep -c 'exist_dns64=\$(check_dns64_any ')" \
            "check_dns64_any call"
}

run_tests
