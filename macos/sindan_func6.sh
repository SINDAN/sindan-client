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
         "<target_addr> <count>." 1>&2
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
  :
  #TBD
}

# Check the state of the port scan result to the target server.
# cmdset_portscan <layer> <version> <target_type> <target_addr> \
#                 <target_port> <count>
function cmdset_portscan() {
  :
  #TBD
}

# Do measure speed index to the target URL.
# do_speedindex <target_url>
function do_speedindex() {
  if [ $# -ne 1 ]; then
    echo "ERROR: do_speedindex <target_url>." 1>&2
    return 1
  fi

  tracejson=trace-json/$(echo "$1" | sed 's/[.:/]/_/g').json
  node speedindex.js "$1" ${tracejson}
  return $?
}

# Check the state of the speed index to the target URL.
# cmdset_speedindex <layer> <version> <target_type> \
#                   <target_url> <count>
function cmdset_speedindex() {
  if [ $# -ne 5 ]; then
    echo "ERROR: cmdset_speedindex <layer> <version> <target_type>"	\
         "<target_addr> <count>." 1>&2
    return 1
  fi
  local layer=$1
  local ver=$2
  local type=$3
  local target=$4
  local count=$5
  local result=$FAIL
  local string=" speedindex to extarnal server: $target by $ver"
  local speedindex_ans

  if speedindex_ans=$(do_speedindex ${target}); then
    result=$SUCCESS
  else
    stat=$?
  fi
  write_json "$layer" "$ver" speedindex "$result" "$target"	\
             "$speedindex_ans" "$count"
  if [ "$result" = "$SUCCESS" ]; then
    string="$string\n  status: ok, speed index value: $speedindex_ans"
  else
    string="$string\n  status: ng ($stat)"
  fi
  if [ "$VERBOSE" = "yes" ]; then
    echo -e "$string"
  fi
}

# Do iNonius speedtest to the target URL.
# do_speedtest <target_url>
function do_speedtest() {
  if [ $# -ne 1 ]; then
    echo "ERROR: do_speedtest <target_url>." 1>&2
    return 1
  fi

  node speedtest.js "$1"
  return $?
}

# Get IPv4 RTT from the result of iNonius speedtest.
# require do_speedtest() data from STDIN.
function get_speedtest_ipv4_rtt() {
  sed -n 's/IPv4_RTT://p'
  return $?
}

# Get IPv4 jitter from the result of iNonius speedtest.
# require do_speedtest() data from STDIN.
function get_speedtest_ipv4_jit() {
  sed -n 's/IPv4_JIT://p'
  return $?
}

# Get IPv4 download speed from the result of iNonius speedtest.
# require do_speedtest() data from STDIN.
function get_speedtest_ipv4_dl() {
  sed -n 's/IPv4_DL://p'
  return $?
}

# Get IPv4 upload speed from the result of iNonius speedtest.
# require do_speedtest() data from STDIN.
function get_speedtest_ipv4_ul() {
  # require do_speedtest() data from STDIN.
  sed -n 's/IPv4_UL://p'
  return $?
}

# Get IPv6 RTT from the result of iNonius speedtest.
# require do_speedtest() data from STDIN.
function get_speedtest_ipv6_rtt() {
  sed -n 's/IPv6_RTT://p'
  return $?
}

# Get IPv6 jitter from the result of iNonius speedtest.
# require do_speedtest() data from STDIN.
function get_speedtest_ipv6_jit() {
  sed -n 's/IPv6_JIT://p'
  return $?
}

# Get IPv6 download speed from the result of iNonius speedtest.
# require do_speedtest() data from STDIN.
function get_speedtest_ipv6_dl() {
  sed -n 's/IPv6_DL://p'
  return $?
}

# Get IPv6 upload speed from the result of iNonius speedtest.
# require do_speedtest() data from STDIN.
function get_speedtest_ipv6_ul() {
  sed -n 's/IPv6_UL://p'
  return $?
}

# Check the state of iNonius speedtest result to the target URL.
# cmdset_speedtest <layer> <version> <target_type> \
#                  <target_url> <count>
function cmdset_speedtest() {
  if [ $# -ne 5 ]; then
      echo "ERROR: cmdset_speedtest <layer> <version> <target_type>"	\
           "<target_addr> <count>." 1>&2
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
    write_json "$layer" "$ver" speedtest "$result" "$target"	\
               "$speedtest_ans" "$count"
    if ipv4_rtt=$(echo "$speedtest_ans" | get_speedtest_ipv4_rtt); then
      write_json "$layer" IPv4 v4speedtest_rtt "$INFO" "$target"	\
                 "$ipv4_rtt" "$count"
      string="$string\n  IPv4 RTT: $ipv4_rtt ms"
    fi
    if ipv4_jit=$(echo "$speedtest_ans" | get_speedtest_ipv4_jit); then
      write_json "$layer" IPv4 v4speedtest_jitter "$INFO" "$target"	\
                 "$ipv4_jit" "$count"
      string="$string\n  IPv4 Jitter: $ipv4_jit ms"
    fi
    if ipv4_dl=$(echo "$speedtest_ans" | get_speedtest_ipv4_dl); then
      write_json "$layer" IPv4 v4speedtest_download "$INFO" "$target"	\
                 "$ipv4_dl" "$count"
      string="$string\n  IPv4 Download Speed: $ipv4_dl Mbps"
    fi
    if ipv4_ul=$(echo "$speedtest_ans" | get_speedtest_ipv4_ul); then
      write_json "$layer" IPv4 v4speedtest_upload "$INFO" "$target"	\
                 "$ipv4_ul" "$count"
      string="$string\n  IPv4 Upload Speed: $ipv4_ul Mbps"
    fi
    if ipv6_rtt=$(echo "$speedtest_ans" | get_speedtest_ipv6_rtt); then
      write_json "$layer" IPv6 v6speedtest_rtt "$INFO" "$target"	\
                 "$ipv6_rtt" "$count"
      string="$string\n  IPv6 RTT: $ipv6_rtt ms"
    fi
    if ipv6_jit=$(echo "$speedtest_ans" | get_speedtest_ipv6_jit); then
      write_json "$layer" IPv6 v6speedtest_jitter "$INFO" "$target"	\
                 "$ipv6_jit" "$count"
      string="$string\n  IPv6 Jitter: $ipv6_jit ms"
    fi
    if ipv6_dl=$(echo "$speedtest_ans" | get_speedtest_ipv6_dl); then
      write_json "$layer" IPv6 v6speedtest_download "$INFO" "$target"	\
                 "$ipv6_dl" "$count"
      string="$string\n  IPv6 Download Speed: $ipv6_dl Mbps"
    fi
    if ipv6_ul=$(echo "$speedtest_ans" | get_speedtest_ipv6_ul); then
      write_json "$layer" IPv6 v6speedtest_upload "$INFO" "$target"	\
                 "$ipv6_ul" "$count"
      string="$string\n  IPv6 Upload Speed: $ipv6_ul Mbps"
    fi
  else
    string="$string\n  status: ng ($stat)"
  fi
  if [ "$VERBOSE" = "yes" ]; then
    echo -e "$string"
  fi
}

