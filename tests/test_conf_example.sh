#!/bin/bash
# Tests for sindan.conf.example of the platform directories.
# 
# The files are kept in each platform directory because they are copied to
# sindan.conf next to sindan.sh. They must not drift apart: the only
# intended difference is DEVNAME, the Wi-Fi device name that only the Linux
# scripts need.
    
# shellcheck disable=SC2034
. "$(dirname "$0")/lib.sh"

test_platform_examples_differ_only_in_devname() { 
  local other
  for other in linux macos; do
    [ "$other" = "$(basename "$SINDAN_DIR")" ] && continue
    out=$(diff <(grep -v '^readonly DEVNAME=' "$SINDAN_DIR/sindan.conf.example") \
               <(grep -v '^readonly DEVNAME=' "$SINDAN_DIR/../$other/sindan.conf.example"))
    assert_eq "" "$out" "differences to $other/sindan.conf.example"
  done
} 

test_every_required_parameter_is_in_the_example() {
  # The parameters that sindan.sh refuses to start without.
  # The shared list of sindan_prepare.sh (without the platform part) and the
  # platform part OS_REQUIRED_PARAMS of sindan.sh.
  params=$(sed -n 's/^for param in \(.*\) \$OS_REQUIRED_PARAMS; do$/\1/p' \
           "$SINDAN_DIR/../common/sindan_prepare.sh")
  [ -n "$params" ] || fail "parameter list not found in sindan_prepare.sh"
  params="$params $(sed -n 's/^OS_REQUIRED_PARAMS="\(.*\)"$/\1/p' "$SINDAN_DIR/sindan.sh")"
  local p
  for p in $params LOCKFILE_SENDLOG URL_CAMPAIGN URL_SINDAN PROXY_URL; do
    grep -q "^readonly $p=" "$SINDAN_DIR/sindan.conf.example" || 
      fail "$p is not set in sindan.conf.example"
  done
}

run_tests
