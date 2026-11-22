#!/bin/bash
# Tests for the release version: common/VERSION, read_version and the way
# sindan.sh gives the version to the campaign log.
#
# The server reads "version" of the campaign log and checks its MAJOR number
# to know the structure of the data, so the value must always be valid.

# shellcheck disable=SC2034
. "$(dirname "$0")/lib.sh"

# Absolute paths: the tests run in a temporary directory.
HERE=$(cd "$(dirname "$0")" && pwd)
VERSION_FILE="$HERE/../common/VERSION"

test_the_version_file_of_the_release_is_valid() {
  load_funcs funcb
  out=$(read_version "$VERSION_FILE")
  assert_eq 0 $? "return status: $out"
  [ -n "$out" ] || fail "empty version"
}

test_read_version_trims_white_space() {
  load_funcs funcb
  printf '  6.1.0 \r\n\n' > "$T/v"
  assert_eq 6.1.0 "$(read_version "$T/v")"
}

test_read_version_accepts_a_suffix() {
  load_funcs funcb
  printf '6.1.1-dev\n' > "$T/v"
  assert_eq 6.1.1-dev "$(read_version "$T/v")"
  printf '7.0.0-rc.1\n' > "$T/v"
  assert_eq 7.0.0-rc.1 "$(read_version "$T/v")"
}

test_read_version_rejects_a_wrong_format() {
  load_funcs funcb
  local v
  for v in "" 6 6.1 v6.1.0 6.1.0.0 "6.1.x" "6.1.0 beta" "6.1.0-" "six.one.zero"; do
    printf '%s\n' "$v" > "$T/v"
    out=$(read_version "$T/v" 2>&1)
    assert_eq 1 $? "return status for [$v]"
    assert_contains "$out" "invalid version" "message for [$v]"
  done
}

test_read_version_reports_a_missing_file() {
  load_funcs funcb
  out=$(read_version "$T/no-such-file" 2>&1)
  assert_eq 1 $? "return status"
  assert_contains "$out" "cannot read the version file"
}

test_read_version_needs_one_argument() {
  load_funcs funcb
  read_version 2> /dev/null
  assert_eq 1 $? "return status without arguments"
}

# sindan.sh stops before the measurement if the version is not valid, and it
# does not have its own copy of the version any more.
test_sindan_sh_stops_with_an_invalid_version() {
  local root="$T/repo" plat
  plat=$(basename "$SINDAN_DIR")
  mkdir -p "$root"
  cp -R "$SINDAN_DIR" "$root/$plat"
  cp -R "$SINDAN_DIR/../common" "$root/common"
  : > "$root/$plat/sindan.conf"
  echo "bad" > "$root/common/VERSION"
  out=$(cd "$root" && bash "$plat/sindan.sh" 2>&1 < /dev/null)
  assert_eq 1 $? "return status"
  assert_contains "$out" "invalid version [bad]"
  assert_not_contains "$out" "is null in configuration file" "the version is checked first"
}

test_platform_scripts_have_no_version_of_their_own() {
  ! grep -q '^VERSION=' "$SINDAN_DIR/sindan.sh" ||
    fail "sindan.sh sets VERSION; it is read from common/VERSION"
}

# The campaign log has the version that sindan_prepare.sh read.
test_the_campaign_log_has_the_release_version() {
  load_funcs funcb
  VERSION=$(read_version "$VERSION_FILE")
  mkdir -p log
  write_json_campaign uuid-1 00:11:22:33:44:55 Linux Ethernet net host
  assert_eq "$VERSION" "$(json_get log/campaign_*.json version)"
}

CHECK_RELEASE="$HERE/check_release.sh"

test_release_check_accepts_the_matching_tag() {
  echo 6.1.0 > "$T/v"
  out=$(bash "$CHECK_RELEASE" v6.1.0 "$T/v")
  assert_eq 0 $? "return status: $out"
}

test_release_check_rejects_another_tag() {
  echo 6.1.0 > "$T/v"
  for tag in v6.1.1 6.1.0 v6.1; do
    out=$(bash "$CHECK_RELEASE" "$tag" "$T/v" 2>&1)
    assert_eq 1 $? "return status for [$tag]"
    assert_contains "$out" "does not match common/VERSION" "message for [$tag]"
  done
}

test_release_check_rejects_a_development_version() {
  echo 6.1.1-dev > "$T/v"
  out=$(bash "$CHECK_RELEASE" v6.1.1-dev "$T/v" 2>&1)
  assert_eq 1 $? "return status"
  assert_contains "$out" "development version"
}

test_release_check_rejects_an_invalid_version_file() {
  echo nonsense > "$T/v"
  out=$(bash "$CHECK_RELEASE" v1.0.0 "$T/v" 2>&1)
  assert_eq 1 $? "return status"
  assert_contains "$out" "invalid version"
}

run_tests
