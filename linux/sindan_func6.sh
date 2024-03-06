#!/bin/bash
# sindan_func6.sh

## Application Layer functions

# Do curl command to the target URL.
# do_curl <version> <target_url>
function do_curl() {
  if [ $# -ne 2 ]; then
    echo "ERROR: do_curl <version> <target_url>." 1>&2
    return 1
  fi
  if [ "$1" != 4 ] && [ "$1" != 6 ]; then
    echo "ERROR: <version> must be 4 or 6." 1>&2
    return 9
  fi
  curl -"$1" -L --connect-timeout 5 --write-out %{http_code} --silent	\
       --output /dev/null "$2"
  return $?
}

# Check HTTP process to the target URL.
# cmdset_http <layer> <version> <target_type> <target_url> <count>
function cmdset_http() {
  if [ $# -ne 5 ]; then
    echo "ERROR: cmdset_http <layer> <version> <target_type>"		\
         "<target_url> <count>." 1>&2
    return 1
  fi
  local layer=$1
  local ver=$2
  local ipv=IPv${ver}
  local type=$3
  local target=$4
  local count=$5
  local result=$FAIL
  local string=" curl to extarnal server: $target by $ipv"
  local http_ans

  if http_ans=$(do_curl "$ver" "$target"); then
    result=$SUCCESS
  else
    stat=$?
  fi
  write_json "$layer" "$ipv" "v${ver}http_${type}" "$result" "$target"	\
             "$http_ans" "$count"
  if [ "$result" = "$SUCCESS" ]; then
    string="$string\n  status: ok, http status code: $http_ans"
  else
    string="$string\n  status: ng ($stat)"
  fi
  if [ "$VERBOSE" = "yes" ]; then
    echo -e "$string"
  fi
}

# Do ssh-keyscan to the target server.
# do_sshkeyscan <version> <target> <key_type>
function do_sshkeyscan() {
  if [ $# -ne 3 ]; then
    echo "ERROR: do_sshkeyscan <version> <target> <key_type>." 1>&2	\
    return 1
  fi
  ssh-keyscan -"$1" -T 5 -t "$3" "$2" 2>/dev/null
  return $?
}

# Check the state of the ssh key on the target server.
# cmdset_ssh <layer> <version> <target_type> <target_str> <count>
function cmdset_ssh() {
  if [ $# -ne 5 ]; then
    echo "ERROR: cmdset_ssh <layer> <version> <target_type>"		\
         "<target_str> <count>." 1>&2
    return 1
  fi
  local layer=$1
  local ver=$2
  local ipv=IPv${ver}
  local type=$3
  local target; local key_type
  target=$(echo "$4" | awk -F_ '{print $1}')
  key_type=$(echo "$4" | awk -F_ '{print $2}')
  local count=$5
  local result=$FAIL
  local string=" sshkeyscan to extarnal server: $target by $ipv"
  local ssh_ans

  if ssh_ans=$(do_sshkeyscan "$ver" "$target" "$key_type"); then
    result=$SUCCESS
  else
    stat=$?
  fi
  write_json "$layer" "$ipv" "v${ver}ssh_${type}" "$result" "$target"  \
             "$ssh_ans" "$count"
  if [ "$result" = "$SUCCESS" ]; then
    string="$string\n  status: ok"
  else
    string="$string\n  status: ng ($stat)"
  fi
  if [ "$VERBOSE" = "yes" ]; then
    echo -e "$string"
  fi
}

# Do port scan to the target server.
# do_portscan <verson> <target> <port>
function do_portscan() {
  if [ $# -ne 3 ]; then
    echo "ERROR: do_portscan <verson> <target> <port>." 1>&2
    return 1
  fi
  case $1 in
    "4" ) nc -zv4 -w1 "$2" "$3" 2>&1 ; return $? ;;
    "6" ) nc -zv6 -w1 "$2" "$3" 2>&1 ; return $? ;;
    "*" ) echo "ERROR: <version> must be 4 or 6." 1>&2; return 9 ;;
  esac
}

# Check the state of the port scan result to the target server.
# cmdset_portscan <layer> <version> <target_type> <target_addr> \
#                 <target_port> <count>
function cmdset_portscan() {
  if [ $# -ne 6 ]; then
    echo "ERROR: cmdset_portscan <layer> <version> <target_type>"	\
         "<target_addr> <target_port> <count>." 1>&2
    return 1
  fi
  local layer=$1
  local ver=$2
  local ipv="IPv${ver}"
  local type=$3
  local target=$4
  local port=$5
  local count=$6
  local result=$FAIL
  local string=" portscan to extarnal server: $target:$port by $ipv"
  local ps_ans

  if ps_ans=$(do_portscan "$ver" "$target" "$port"); then
    result=$SUCCESS
  else
    stat=$?
  fi
  write_json "$layer" "$ipv" "v${ver}portscan_${port}" "$result"	\
             "$target" "$ps_ans" "$count"
  if [ "$result" = "$SUCCESS" ]; then
    string="$string\n  status: ok"
  else
    string="$string\n  status: ng ($stat)"
  fi
  if [ "$VERBOSE" = "yes" ]; then
    echo -e "$string"
  fi
}

# Do iNonius speedtest to the target server.
# do_speedtest <version> <server_id>
function do_speedtest() {
  if [ $# -ne 2 ]; then
    echo "ERROR: do_speedtest <version> <server_id>." 1>&2
    return 1
  fi

  ./librespeed-cli --local-json server-inonius.json --csv	\
                   --server "$2" --ipv"$1" --concurrent 6
  return $?
}

# Get RTT from the result of iNonius speedtest.
# require do_speedtest() data from STDIN.
function get_speedtest_rtt() {
  awk -F, '{print $4}'
  return $?
}

# Get jitter from the result of iNonius speedtest.
# require do_speedtest() data from STDIN.
function get_speedtest_jitter() {
  awk -F, '{print $5}'
  return $?
}

# Get download speed from the result of iNonius speedtest.
# require do_speedtest() data from STDIN.
function get_speedtest_download() {
  awk -F, '{print $6}'
  return $?
}

# Get upload speed from the result of iNonius speedtest.
# require do_speedtest() data from STDIN.
function get_speedtest_upload() {
  awk -F, '{print $7}'
  return $?
}

# Check the state of iNonius speedtest result to the target server.
# cmdset_speedtest <layer> <version> <target_type> \
#                  <server_id> <target> <count>
function cmdset_speedtest() {
  if [ $# -ne 6 ]; then
      echo "ERROR: cmdset_speedtest <layer> <version> <target_type>"	\
           "<server_id> <target> <count>." 1>&2
    return 1
  fi
  local layer=$1
  local ver=$2
  local ipv=IPv${ver}
  local type=$3
  local srv_id=$4
  local target=$5
  local count=$6
  local result=$FAIL
  local string=" speedtest to extarnal server: $target by $ipv"
  local speedtest_ans
  local rtt; local jitter; local download; local upload

  if speedtest_ans=$(do_speedtest "$ver" "$srv_id"); then
    result=$SUCCESS
  else
    stat=$?
  fi
  if [ "$result" = "$SUCCESS" ]; then
    string="$string\n  status: ok"
    write_json "$layer" "$ipv" speedtest "$result" "$target" "$speedtest_ans"	\
               "$count"
    if rtt=$(echo "$speedtest_ans" | get_speedtest_rtt); then
      write_json "$layer" "$ipv" "v${ver}speedtest_rtt" "$INFO" "$target"	\
                 "$rtt" "$count"
      string="$string\n  $ipv RTT: $rtt ms"
    fi
    if jitter=$(echo "$speedtest_ans" | get_speedtest_jitter); then
      write_json "$layer" "$ipv" "v${ver}speedtest_jitter" "$INFO" "$target"	\
                 "$jitter" "$count"
      string="$string\n  $ipv Jitter: $jitter ms"
    fi
    if download=$(echo "$speedtest_ans" | get_speedtest_download); then
      write_json "$layer" "$ipv" "v${ver}speedtest_download" "$INFO" "$target"	\
                 "$download" "$count"
      string="$string\n  $ipv Download Speed: $download Mbps"
    fi
    if upload=$(echo "$speedtest_ans" | get_speedtest_upload); then
      write_json "$layer" "$ipv" "v${ver}speedtest_upload" "$INFO" "$target"	\
                 "$upload" "$count"
      string="$string\n  $ipv Upload Speed: $upload Mbps"
    fi
  else
    string="$string\n  status: ng ($stat)"
  fi
  if [ "$VERBOSE" = "yes" ]; then
    echo -e "$string"
  fi
}

