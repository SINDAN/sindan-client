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
function get_speedtest_sess() {
  if [ $# -ne 2 ]; then
    echo "ERROR: get_speedtest_sess <version> <type>." 1>&2
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
  jq -r --arg key "$key" --arg type "$type" --arg field "$field"	\
    'if .[$key] == true then .[$type][$field] else empty end'
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
  local pver=$2
  local type=$3
  local target=$4
  local count=$5
  local result=$FAIL
  local string=" speedtest to extarnal server: $target by $ver"
  local speedtest_ans stat

  if speedtest_ans=$(do_speedtest "$target"); then
    result=$SUCCESS
  else
    stat=$?
  fi
  if [ "$result" = "$SUCCESS" ]; then
    string="$string\n  status: ok"
    write_json "$layer" "$pver" speedtest "$result" "$target"		\
               "$speedtest_ans" "$count"
    for ver in 4 6; do
      local prefix="v${ver}speedtest"
      local ipv="IPv${ver}"

      for code in "p rtt ms" "j jitter ms" "d download Mbps" "u upload Mbps"; do
        IFS=" " read -r key suffix unit <<< "$code"
        value=$(get_speedtest_data "$ver" "$key" <<< "$speedtest_ans") && {
          write_json "$layer" "$ipv" "${prefix}_${suffix}" "$INFO"	\
                     "$target" "$value" "$count"
          case "$key" in
            p) name="RTT" ;;
            j) name="Jitter" ;;
            d) name="Download" ;;
            u) name="Upload" ;;
          esac
          string="$string\n  $ipv $name: $value $unit"
        }
      done

      for code in "t time" "i ip" "p port" "o org" "m mss"; do
        IFS=" " read -r key suffix <<< "$code"
        value=$(get_speedtest_sess "$ver" "$key" <<< "$speedtest_ans") && {
          write_json "$layer" "$ipv" "${prefix}_${suffix}" "$INFO"	\
                     "$target" "$value" "$count"
          case "$key" in
            t) name="Timestamp" ;;
            i) name="IP address" ;;
            p) name="Port number" ;;
            o) name="ISP" ;;
            m) name="MSS" ;;
          esac
          string="$string\n  $ipv $name: $value"
        }
      done
    done
  else
    string="$string\n  status: ng ($stat)"
  fi
  if [ "$VERBOSE" = "yes" ]; then
    echo -e "$string"
  fi
}

