#!/bin/bash
# sindan_func5.sh

## DNS Layer functions

# Do DNS lookup the target FQDN using the name server.
# do_dnslookup <nameserver> <query_type> <target_fqdn>
function do_dnslookup() {
  if [ $# -ne 3 ]; then
    echo "ERROR: do_dnslookup <nameserver> <query_type>"		\
         "<target_fqdn>." 1>&2
    return 1
  fi
  dig @"$1" "$3" "$2" +time=1
  # Dig return codes are:
  # 0: Everything went well, including things like NXDOMAIN
  # 1: Usage error
  # 8: Couldn't open batch file
  # 9: No reply from server
  # 10: Internal error
  return $?
}

# Get answer of the DNS request.
# require do_dnslookup() data from STDIN.
# get_dnsans <query_type>
function get_dnsans() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_dnsans <query_type>." 1>&2
    return 1
  fi
  grep -v -e '^$' -e '^;'						|
  grep "	$1" -m 1						|
  awk '{print $5}'
  return $?
}

# Get TTL of the DNS record.
# require do_dnslookup() data from STDIN.
# get_dnsttl <query_type>
function get_dnsttl() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_dnsttl <query_type>." 1>&2
    return 1
  fi
  grep -v -e '^$' -e '^;'						|
  grep "	$1" -m 1						|
  awk '{print $2}'
  return $?
}

# Get query time of the DNS request.
# require do_dnslookup() data from STDIN.
function get_dnsrtt() {
  sed -n 's/^;; Query time: \([0-9]*\) msec$/\1/p'
  return $?
}

# Check if the DNS64 function is working on the name server.
# check_dns64 <nameserver>
function check_dns64() {
  if [ $# -ne 1 ]; then
    echo "ERROR: check_dns64 <nameserver>." 1>&2
    return 1
  fi
  local dns_ans
  dns_ans=$(do_dnslookup "$1" AAAA ipv4only.arpa			|
          get_dnsans AAAA)
  if [ -n "$dns_ans" ]; then
    echo 'yes'
  else
    echo 'no'
  fi
}

# Check the state of DNS lookup command to the target address.
# cmdset_dnslookup <layer> <version> <target_type> <target_addr> <count>
function cmdset_dnslookup() {
  if [ $# -ne 5 ]; then
    echo "ERROR: cmdset_dnslookup <layer> <version> <target_type>"	\
         "<target_addr> <count>." 1>&2
    return 1
  fi
  local layer=$1
  local ver=$2
  local ipv=IPv${ver}
  local type=$3
  local target=$4
  local dns_result=""
  local string=" dns lookup for $type record by $ipv nameserver: $target"
  local dns_ans; local dns_ttl; local dns_rtt

  for fqdn in $(echo "$FQDNS" | sed 's/,/ /g'); do
    local result=$FAIL
    string="$string\n  resolve server: $fqdn"
    if dns_result=$(do_dnslookup "$target" "$type" "$fqdn"); then
      result=$SUCCESS
    else
      stat=$?
    fi
    write_json "$layer" "$ipv" "v${ver}dnsqry_${type}_${fqdn}"		\
               "$result" "$target" "$dns_result" "$count"
    if [ "$result" = "$SUCCESS" ]; then
      dns_ans=$(echo "$dns_result" | get_dnsans "$type")
      write_json "$layer" "$ipv" "v${ver}dnsans_${type}_${fqdn}"	\
                 "$INFO" "$target" "$dns_ans" "$count"
      dns_ttl=$(echo "$dns_result" | get_dnsttl "$type")
      write_json "$layer" "$ipv" "v${ver}dnsttl_${type}_${fqdn}"	\
                 "$INFO" "$target" "$dns_ttl" "$count"
      dns_rtt=$(echo "$dns_result" | get_dnsrtt)
      write_json "$layer" "$ipv" "v${ver}dnsrtt_${type}_${fqdn}"	\
                 "$INFO" "$target" "$dns_rtt" "$count"
      string="$string\n   status: ok, result(ttl): $dns_ans($dns_ttl s),"
      string="$string query time: $dns_rtt ms"
    else
      string="$string\n   status: ng ($stat)"
    fi
  done
  if [ "$VERBOSE" = "yes" ]; then
    echo -e "$string"
  fi
}

