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

# Do iNonius speedtest to the target URL using inonius_v3cli.
# do_speedtest <target_url>
function do_speedtest() {
  if [ $# -ne 1 ]; then
    echo "ERROR: do_speedtest <target_url>." 1>&2
    return 1
  fi
  ./bin/inonius_v3cli -e "$1" --json
  return $?
}

# Get data from the result of iNonius speedtest.
# require do_speedtest() data from STDIN.
function get_speedtest_data() {
  if [ $# -ne 2 ]; then
    echo "ERROR: get_speedtest_data <version> <type>." 1>&2
    return 1
  fi
  case $1 in
    "4" ) key="ipv4_available"; type="IPv4" ;;
    "6" ) key="ipv6_available"; type="IPv6" ;;
    * ) echo "ERROR: <version> must be 4 or 6." 1>&2; return 9 ;;
  esac
  case $2 in
    "d" ) field="download" ;;
    "u" ) field="upload" ;;
    "p" ) field="ping" ;;
    "j" ) field="jitter" ;;
    * ) echo "ERROR: <type> must be d, u, p or j." 1>&2; return 9 ;;
  esac
  jq -r --arg key "$key" --arg type "$type" --arg field "$field"	\
    'if .[$key] then (.result[]						|
     select(.speedtest_type == $type)					|
     .[$field]) else empty end'
  return $?
}

# Get session data from the result of iNonius speedtest.
# require do_speedtest() data from STDIN.
function get_speedtest_session_data() {
  if [ $# -ne 2 ]; then
    echo "ERROR: get_speedtest_session_data <version> <type>." 1>&2
    return 1
  fi
  case $1 in
    "4" ) key="ipv4_available"; type="ipv4_info" ;;
    "6" ) key="ipv6_available"; type="ipv6_info" ;;
    * ) echo "ERROR: <version> must be 4 or 6." 1>&2; return 9 ;;
  esac
  case $2 in
    "t" ) jq .timestamp; return $? ;;
    "i" ) field="ip" ;;
    "p" ) field="port" ;;
    "o" ) field="org" ;;
    "m" ) field="mss" ;;
    * ) echo "ERROR: <type> must be t, i, p, o or m." 1>&2; return 9 ;;
  esac
  jq -r --arg key "$key" --arg type "$type" --arg field "$field"		\
    'if .[$key] == true then .[$type].[$field] else empty end'
  return $?
}

# Check the state of iNonius speedtest result to the target URL.
# cmdset_speedtest <layer> <version> <target_type> \
#                  <target_url> <count>
function cmdset_speedtest() {
  if [ $# -ne 5 ]; then
      echo "ERROR: cmdset_speedtest <layer> <version> <target_type>"	\
           "<target_url> <count>." 1>&2
    return 1
  fi
  local layer=$1
  local ver=$2
  local type=$3
  local target=$4
  local count=$5
  local result=$FAIL
  local string=" speedtest to extarnal server: $target by $ver"
  local speedtest_ans
  local ipv4_rtt; local ipv4_jit; local ipv4_dl; local ipv4_ul
  local ipv6_rtt; local ipv6_jit; local ipv6_dl; local ipv6_ul

  if speedtest_ans=$(do_speedtest "$target"); then
    result=$SUCCESS
  else
    stat=$?
  fi
  if [ "$result" = "$SUCCESS" ]; then
    string="$string\n  status: ok"
    write_json "$layer" "$ver" speedtest "$result" "$target"		\
               "$speedtest_ans" "$count"
    # IPv4
    if ipv4_rtt=$(get_speedtest_data 4 p <<< "$speedtest_ans"); then
      write_json "$layer" IPv4 v4speedtest_rtt "$INFO" "$target"	\
                 "$ipv4_rtt" "$count"
      string="$string\n  IPv4 RTT: $ipv4_rtt ms"
    fi
    if ipv4_jit=$(get_speedtest_data 4 j <<< "$speedtest_ans"); then
      write_json "$layer" IPv4 v4speedtest_jitter "$INFO" "$target"	\
                 "$ipv4_jit" "$count"
      string="$string\n  IPv4 Jitter: $ipv4_jit ms"
    fi
    if ipv4_dl=$(get_speedtest_data 4 d <<< "$speedtest_ans"); then
      write_json "$layer" IPv4 v4speedtest_download "$INFO" "$target"	\
                 "$ipv4_dl" "$count"
      string="$string\n  IPv4 Download Speed: $ipv4_dl Mbps"
    fi
    if ipv4_ul=$(get_speedtest_data 4 u <<< "$speedtest_ans"); then
      write_json "$layer" IPv4 v4speedtest_upload "$INFO" "$target"	\
                 "$ipv4_ul" "$count"
      string="$string\n  IPv4 Upload Speed: $ipv4_ul Mbps"
    fi
    if ipv4_ts=$(get_speedtest_sess 4 t <<< "$speedtest_ans"); then
      write_json "$layer" IPv4 v4speedtest_time "$INFO" "$target"	\
                 "$ipv4_ts" "$count"
      string="$string\n  IPv4 Session Timestamp: $ipv4_ts"
    fi
    if ipv4_ip=$(get_speedtest_sess 4 i <<< "$speedtest_ans"); then
      write_json "$layer" IPv4 v4speedtest_ip "$INFO" "$target"		\
                 "$ipv4_ip" "$count"
      string="$string\n  IPv4 IP address: $ipv4_ip"
    fi
    if ipv4_pt=$(get_speedtest_sess 4 p <<< "$speedtest_ans"); then
      write_json "$layer" IPv4 v4speedtest_port "$INFO" "$target"	\
                 "$ipv4_pt" "$count"
      string="$string\n  IPv4 Port number: $ipv4_pt"
    fi
    if ipv4_org=$(get_speedtest_sess 4 o <<< "$speedtest_ans"); then
      write_json "$layer" IPv4 v4speedtest_org "$INFO" "$target"	\
                 "$ipv4_org" "$count"
      string="$string\n  IPv4 ISP: $ipv4_org"
    fi
    if ipv4_mss=$(get_speedtest_sess 4 m <<< "$speedtest_ans"); then
      write_json "$layer" IPv4 v4speedtest_mss "$INFO" "$target"	\
                 "$ipv4_mss" "$count"
      string="$string\n  IPv4 MSS: $ipv4_mss"
    fi
    # IPv6
    if ipv6_rtt=$(get_speedtest_data 6 p <<< "$speedtest_ans"); then
      write_json "$layer" IPv6 v6speedtest_rtt "$INFO" "$target"	\
                 "$ipv6_rtt" "$count"
      string="$string\n  IPv6 RTT: $ipv6_rtt ms"
    fi
    if ipv6_jit=$(get_speedtest_data 6 j <<< "$speedtest_ans"); then
      write_json "$layer" IPv6 v6speedtest_jitter "$INFO" "$target"	\
                 "$ipv6_jit" "$count"
      string="$string\n  IPv6 Jitter: $ipv6_jit ms"
    fi
    if ipv6_dl=$(get_speedtest_data 6 d <<< "$speedtest_ans"); then
      write_json "$layer" IPv6 v6speedtest_download "$INFO" "$target"	\
                 "$ipv6_dl" "$count"
      string="$string\n  IPv6 Download Speed: $ipv6_dl Mbps"
    fi
    if ipv6_ul=$(get_speedtest_data 6 u <<< "$speedtest_ans"); then
      write_json "$layer" IPv6 v6speedtest_upload "$INFO" "$target"	\
                 "$ipv6_ul" "$count"
      string="$string\n  IPv6 Upload Speed: $ipv6_ul Mbps"
    fi
    if ipv6_ts=$(get_speedtest_sess 6 t <<< "$speedtest_ans"); then
      write_json "$layer" IPv6 v6speedtest_time "$INFO" "$target"	\
                 "$ipv6_ts" "$count"
      string="$string\n  IPv6 Session Timestamp: $ipv6_ts"
    fi
    if ipv6_ip=$(get_speedtest_sess 6 i <<< "$speedtest_ans"); then
      write_json "$layer" IPv6 v6speedtest_ip "$INFO" "$target"		\
                 "$ipv6_ip" "$count"
      string="$string\n  IPv6 IP address: $ipv6_ip"
    fi
    if ipv6_pt=$(get_speedtest_sess 6 p <<< "$speedtest_ans"); then
      write_json "$layer" IPv6 v6speedtest_port "$INFO" "$target"	\
                 "$ipv6_pt" "$count"
      string="$string\n  IPv6 Port number: $ipv6_pt"
    fi
    if ipv6_org=$(get_speedtest_sess 6 o <<< "$speedtest_ans"); then
      write_json "$layer" IPv6 v6speedtest_org "$INFO" "$target"	\
                 "$ipv6_org" "$count"
      string="$string\n  IPv6 ISP: $ipv6_org"
    fi
    if ipv6_mss=$(get_speedtest_sess 6 m <<< "$speedtest_ans"); then
      write_json "$layer" IPv6 v6speedtest_mss "$INFO" "$target"	\
                 "$ipv6_mss" "$count"
      string="$string\n  IPv6 MSS: $ipv6_mss"
    fi
  else
    string="$string\n  status: ng ($stat)"
  fi
  if [ "$VERBOSE" = "yes" ]; then
    echo -e "$string"
  fi
}

