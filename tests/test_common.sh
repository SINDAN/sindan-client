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
  assert_contains "$out" "is null in configration file" "the script did not reach the parameter check"
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

run_tests
