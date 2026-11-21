#!/bin/bash
# Tests for sendlog.sh (the wrapper of the platform directory and the shared
# common/sendlog.sh). The macOS copy used to be an older version that
# ignored PROXY_URL.

# shellcheck disable=SC2034
. "$(dirname "$0")/lib.sh"

# Copy the platform directory and common/ to a fresh tree, write a
# configuration and put a curl shim in PATH. CURL_STATUS (default 200) is
# the HTTP status printed by the shim.
setup_tree() {
  PLAT=$(basename "$SINDAN_DIR")
  ROOT="$T/repo"
  mkdir -p "$ROOT"
  cp -R "$SINDAN_DIR" "$ROOT/$PLAT"
  cp -R "$SINDAN_DIR/../common" "$ROOT/common"
  rm -rf "$ROOT/$PLAT/log"
  mkdir -p "$ROOT/$PLAT/log"
  cat > "$ROOT/$PLAT/sindan.conf" <<CONF
LOCKFILE_SENDLOG=$T/sendlog.lock
URL_CAMPAIGN=http://campaign.example/log
URL_SINDAN=http://sindan.example/log
VERBOSE=no
${CONF_EXTRA:-}
CONF
  echo '{}' > "$ROOT/$PLAT/log/campaign_1.json"
  echo '{}' > "$ROOT/$PLAT/log/sindan_app_x_0_1.json"
  make_shim curl 'echo "$*" >> "$T/calls.curl"; printf "%s" "${CURL_STATUS:-200}"'
  # Run from a directory that is neither the platform directory nor common/.
  mkdir -p "$T/elsewhere"
  cd "$T/elsewhere" || fail "cannot cd"
}

run_sendlog() {
  sh "$ROOT/$PLAT/sendlog.sh"
}

test_logs_are_sent_to_their_urls_and_removed() {
  setup_tree
  run_sendlog
  assert_eq 0 $? "return status"
  assert_contains "$(cat "$T/calls.curl")" "json=@log/campaign_1.json http://campaign.example/log"
  assert_contains "$(cat "$T/calls.curl")" "json=@log/sindan_app_x_0_1.json http://sindan.example/log"
  [ ! -e "$ROOT/$PLAT/log/campaign_1.json" ] || fail "campaign log was not removed"
  [ ! -e "$ROOT/$PLAT/log/sindan_app_x_0_1.json" ] || fail "sindan log was not removed"
  [ ! -e "$T/sendlog.lock" ] || fail "lock file was not removed"
}

test_logs_are_kept_when_the_server_does_not_answer_200() {
  setup_tree
  export CURL_STATUS=500
  run_sendlog
  [ -e "$ROOT/$PLAT/log/campaign_1.json" ] || fail "campaign log was removed"
  [ -e "$ROOT/$PLAT/log/sindan_app_x_0_1.json" ] || fail "sindan log was removed"
}

test_proxy_is_used_when_configured() {
  CONF_EXTRA='PROXY_URL=http://proxy.example:3128'
  setup_tree
  run_sendlog
  assert_contains "$(cat "$T/calls.curl")" "--proxy http://proxy.example:3128"
}

test_no_proxy_option_without_configuration() {
  CONF_EXTRA='PROXY_URL=""'
  setup_tree
  run_sendlog
  assert_not_contains "$(cat "$T/calls.curl")" "--proxy"
}

test_running_instance_prevents_a_second_run() {
  setup_tree
  sleep 30 &
  echo $! > "$T/sendlog.lock"
  run_sendlog
  kill $! 2> /dev/null
  assert_eq 0 $? "return status"
  assert_no_call curl
  [ -e "$ROOT/$PLAT/log/campaign_1.json" ] || fail "log was removed"
}

test_stale_lock_file_is_replaced() {
  setup_tree
  echo 999999 > "$T/sendlog.lock"
  out=$(run_sendlog)
  assert_contains "$out" "previous check appears to have not finished"
  [ -e "$T/calls.curl" ] || fail "nothing was sent"
}

test_missing_lock_file_parameter_is_an_error() {
  setup_tree
  sed -i.bak '/LOCKFILE_SENDLOG/d' "$ROOT/$PLAT/sindan.conf"
  err=$(run_sendlog 2>&1)
  assert_eq 1 $? "return status"
  assert_contains "$err" "LOCKFILE_SENDLOG is null"
  assert_no_call curl
}

run_tests
