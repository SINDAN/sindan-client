#!/bin/bash
# sindan_func2.sh
#
# Interface Layer functions that are the same on all platforms. The functions
# that read the state of the system are in sindan_func2_os.sh of each platform
# directory, which must be read before this file. The platform file provides
# the following functions used here:
#   is_dhcp4_conf <v4ifconf>        true if the IPv4 configuration is DHCP
#   get_dhcp4_data <ifname>         print the DHCPv4 lease data
#   get_dhcp4_addr                  read the lease data from STDIN, print the
#                                   address assigned by DHCPv4
#   is_auto6_conf <v6ifconf>        true if the IPv6 configuration is automatic
#   print_ra_state <ifname>         print the RA state for the log (may do nothing)
#   get_dhcp6_data <ifname>         print the DHCPv6 lease data
#   has_dhcp6_addr <v6addr>         read the lease data from STDIN, true if it
#                                   contains the address

## Interface Layer functions

# Convert the IPv4 address to decimal value.
# ip2decimal <v4addr>
function ip2decimal() {
  if [ $# -ne 1 ]; then
    echo "ERROR: ip2decimal <v4addr>." 1>&2
    return 1
  fi
  local o=()
  o=($(echo "$1" | sed 's/\./ /g'))
  echo $(( (o[0] << 24) | (o[1] << 16) | (o[2] << 8) | o[3] ))
}

# Compare the IPv4 addresses.
# compare_v4addr <v4addr1> <v4addr2>
function compare_v4addr() {
  if [ $# -ne 2 ]; then
    echo "ERROR: compare_v4addr <v4addr1> <v4addr2>." 1>&2
    return 1
  fi
  local addr1 addr2
  addr1=$(ip2decimal "$1")
  addr2=$(ip2decimal "$2")
  if [ "$addr1" = "$addr2" ]; then
    echo 'same'
  else
    echo 'diff'
  fi
}

# Get type of the IPv4 address.
# check_v4addr <v4addr>
function check_v4addr() {
  if [ $# -ne 1 ]; then
    echo "ERROR: check_v4addr <v4addr>." 1>&2
    return 1
  fi
  local ip="$1"
  # IPv4 syntax validation
  if echo "$ip" |
   grep -vqE '^(([1-9]?[0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([1-9]?[0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$'; then
    echo "not IPv4 address"
    return 1
  fi
  case "$ip" in
    # 0.0.0.0/32 (This host on this network)
    0.0.0.0)
      echo "this-host"
      ;;
    # 0.0.0.0/8 (This network)
    0.*)
      echo "this-network"
      ;;
    # 10.0.0.0/8,172.16.0.0/12,192.168.0.0/16 (Private-Use)
    10.*|172.1[6-9].*|172.2[0-9].*|172.3[0-1].*|192.168.*)
      echo "private"
      ;;
    # 100.64.0.0/10 (Shared Address Space)
    100.6[4-9].*|100.[7-9][0-9].*|100.1[01][0-9].*|100.12[0-7].*)
      echo "shared"
      ;;
    # 127.0.0.0/8 (Loopback)
    127.*)
      echo "loopback"
      ;;
    # 169.254.0.0/16 (Link Local)
    169.254.*)
      echo "linklocal"
      ;;
    # 192.0.0.0/29 (IPv4 Service Continuity Prefix)
    192.0.0.[0-7])
      echo "ipv4-service-continuity"
      ;;
    # 192.0.0.8/32 (IPv4 dummy address)
    192.0.0.8)
      echo "ipv4-dummy"
      ;;
    # 192.0.0.9/32 (Port Control Protocol Anycast)
    192.0.0.9)
      echo "pcp-anycast"
      ;;
    # 192.0.0.10/32 (Traversal Using Relays around NAT Anycast)
    192.0.0.10)
      echo "turn-anycast"
      ;;
    # 192.0.0.170/32,192.0.0.171/32 (NAT64/DNS64 Discovery)
    192.0.0.170|192.0.0.171)
      echo "nat64-discovery"
      ;;
    # 192.0.0.0/24 (IETF Protocol Assignments)
    192.0.0.*)
      echo "ietf"
      ;;
    # 192.0.2.0/24,198.51.100.0/24,203.0.113.0/24 (Documentation)
    192.0.2.*|198.51.100.*|203.0.113.*)
      echo "documentation"
      ;;
    # 192.31.196.0/24 (AS112-v4)
    192.31.196.*)
      echo "as112"
      ;;
    # 192.52.193.0/24 (AMT)
    192.52.193.*)
      echo "amt"
      ;;
    # 192.88.99.2/32 (6a44-relay anycast address)
    192.88.99.2)
      echo "6a44-relay"
      ;;
    # 192.88.99.0/24 (6to4 Relay Anycast)
    192.88.99.*)
      echo "6to4-relay"
      ;;
    # 192.175.48.0/24 (Direct Delegation AS112 Service)
    192.175.48.*)
      echo "direct-delegation-as112"
      ;;
    # 198.18.0.0/15 (Benchmarking)
    198.18.*|198.19.*)
      echo "benchmarking"
      ;;
    # 224.0.0.0/4 (Multicast Addresses)
    22[4-9].*|23[0-9].*)
      echo "multicast"
      ;;
    # 240.0.0.0/4 (Reserved)
    24[0-9].*|25[0-4].*)
      echo "reserved"
      ;;
    # 255.255.255.255/32 (Limited Broadcast)
    255.255.255.255)
      echo "limited-broadcast"
      ;;
    *)
      echo "global"
      ;;
  esac
  return 0
}

# Check if the type of the IPv4 address (the output of check_v4addr) is one
# that can reach other networks, i.e. if the checks of the globalnet, dns and
# application layers make sense. Private, shared (100.64.0.0/10, used by
# carrier-grade NAT) and global addresses qualify. Link-local, loopback, IPv4
# service continuity (CLAT) and the other special-purpose addresses do not.
# is_usable_v4addr_type <v4addr_type>
function is_usable_v4addr_type() {
  if [ $# -ne 1 ]; then
    echo "ERROR: is_usable_v4addr_type <v4addr_type>." 1>&2
    return 1
  fi
  case "$1" in
    "private"|"shared"|"global" ) return 0 ;;
    * ) return 1 ;;
  esac
}

# Get IPv6 prefix length configured by the RA.
# get_prefixlen <ra_prefix>
function get_prefixlen() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_prefixlen <ra_prefix>." 1>&2
    return 1
  fi
  echo "$1" |
  awk -F/ '{print $2}'
  return $?
}

# Get type of the IPv6 address.
# check_v6addr <v6addr>
function check_v6addr() {
  if [ $# -ne 1 ]; then
    echo "ERROR: check_v6addr <v6addr>." 1>&2
    return 1
  fi
  local ip
  ip=$(printf '%s\n' "$1" | tr 'A-F' 'a-f')
  # IPv6 syntax validation
  if echo "$ip" |
   grep -vqE '^([0-9a-f]{0,4}:){1,7}[0-9a-f]{0,4}$|^([0-9a-f]{0,4}:)*:[0-9a-f:]*$'; then
    echo "not IPv6 address"
    return 1
  fi
  case "$ip" in
    # Multiple :: not allowed
    *::*::*)
      echo "not IPv6 address"
      return 1
      ;;
    # ::/128 (Unspecified Address)
    ::)
      echo "unspecified"
      ;;
    # ::1/128 (Loopback Address)
    ::1)
      echo "loopback"
      ;;
    # ::ffff:0:0/96 (IPv4-mapped Address)
    ::ffff:*)
      echo "ipv4-mapped"
      ;;
    # 64:ff9b::/96,64:ff9b:1::/48 (IPv4-IPv6 Translat)
    64:ff9b::*|64:ff9b:1:*)
      echo "46translat"
      ;;
    # 100::/64 (Discard-Only Address Block)
    100::*)
      echo "discard-only"
      ;;
    # 100:0:0:1::/64 (Dummy IPv6 Prefix)
    100:0:0:1:*)
      echo "dummy"
      ;;
    # 2001::/32 (TEREDO)
    2001::*)
      echo "teredo"
      ;;
    # 2001:1::1/128 (Port Control Protocol Anycast)
    2001:1::1)
      echo "pcp-anycast"
      ;;
    # 2001:1::2/128 (Traversal Using Relays around NAT Anycast)
    2001:1::2)
      echo "turn-anycast"
      ;;
    # 2001:1::3/128 (DNS-SD Service Registration Protocol Anycast)
    2001:1::3)
      echo "dns-sd-anycast"
      ;;
    # 2001:2::/48 (Benchmarking)
    2001:2:*)
      echo "benchmarking"
      ;;
    # 2001:3::/32 (AMT)
    2001:3:*)
      echo "amt"
      ;;
    # 2001:4:12::/48 (AS112-v6)
    2001:4:12:*)
      echo "as112"
      ;;
    # 2001:10::/28 (ORCHID)
    2001:1[0-9a-f]:*)
      echo "orchid"
      ;;
    # 2001:20::/28 (ORCHIDv2)
    2001:2[0-9a-f]:*)
      echo "orchid-v2"
      ;;
    # 2001:30::/28 (Drone Remote ID Protocol Entity Tags (DETs) Prefix)
    2001:3[[0-9a-f]:*)
      echo "dets"
      ;;
    # 2001:db8::/32,3ffe::/20 (Documentation)
    2001:db8:*|3ffe:[0-9a-f]*:*|3ffe::*)
      echo "documentation"
      ;;
    # 2001::/23 (IETF Protocol Assignments)
    2001:*)
      echo "ietf"
      ;;
    # 2002::/16 (6to4)
    2002:*)
      echo "6to4"
      ;;
    # 2620:4f:8000::/48 (Direct Delegation AS112 Service)
    2620:4f:8000:*)
      echo "direct-delegation-as112"
      ;;
    # 5f00::/16 (Segment Routing (SRv6) SIDs)
    5f00:*)
      echo "srv6"
      ;;
    # fc00::/7 (Unique-Local)
    fc*|fd*)
      echo "ula"
      ;;
    # fe80::/10 (Link-Local Unicast)
    fe8*|fe9*|fea*|feb*)
      echo "linklocal"
      ;;
    # fec0::/10 (Site-Local Address)
    fec*|fed*|fee*|fef*)
      echo "sitelocal"
      ;;
    # ff00::/8 (Multicast Address)
    ff*)
      echo "multicast"
      ;;
    # [NOTE] included not assigned addresses
    *)
      echo "global"
      ;;
  esac
  return 0
}

# Check if the IPv4 address is configured by DHCP as expected.
# check_v4autoconf <ifname> <v4ifconf>
function check_v4autoconf() {
  if [ $# -ne 2 ]; then
    echo "ERROR: check_v4autoconf <ifname> <v4ifconf>." 1>&2
    return 1
  fi
  local v4addr v4addr_type dhcp_data dhcpv4addr cmp
  if is_dhcp4_conf "$2"; then
    v4addr=$(get_v4addr "$1")
    # exclude link-local and CLAT addresses
    v4addr_type=$(check_v4addr "$v4addr")
    if [ "$v4addr_type" = "linklocal" ] ||
       [ "$v4addr_type" = "ipv4-service-continuity" ]; then
      return 0
    fi
    dhcp_data=$(get_dhcp4_data "$1")
    echo "$dhcp_data"

    # simple comparision
    dhcpv4addr=$(echo "$dhcp_data" | get_dhcp4_addr)
    echo "v4addr=$v4addr, dhcpv4addr=$dhcpv4addr"
    if [ -z "$dhcpv4addr" ] || [ -z "$v4addr" ]; then
      return 1
    fi
    cmp=$(compare_v4addr "$dhcpv4addr" "$v4addr")
    if [ "$cmp" = "same" ]; then
      return 0
    else
      return 1
    fi
  fi
  echo "v4conf is $2"
  return 0
}

# Check if the IPv6 addresses are configured by SLAAC/DHCPv6 as expected.
# The result is 0 if the configuration is as expected. The bit 1 (value 1)
# means that no SLAAC address is found, the bit 2 (value 2) that no DHCPv6
# address is found while the RA has the M flag.
# check_v6autoconf <ifname> <v6ifconf> <ra_flags> <ra_prefix> <ra_prefix_flags>
function check_v6autoconf() {
  if [ $# -ne 5 ]; then
    echo "ERROR: check_v6autoconf <ifname> <v6ifconf> <ra_flags>"      \
         "<ra_prefix> <ra_prefix_flags>." 1>&2
    return 1
  fi
  local result o_flag m_flag a_flag v6addrs dhcp_data addr
  result=1
  if is_auto6_conf "$2"; then
    o_flag=$(echo "$3" | grep O)
    m_flag=$(echo "$3" | grep M)
    v6addrs=$(get_v6addrs "$1" "$4")
    a_flag=$(echo "$5" | grep A)
    print_ra_state "$1"
    if [ -n "$a_flag" ] && [ -n "$v6addrs" ]; then
      result=0
    fi
    if [ -n "$o_flag" ] || [ -n "$m_flag" ]; then
      dhcp_data=$(get_dhcp6_data "$1")
      echo "$dhcp_data"
    fi
    if [ -n "$m_flag" ]; then
      result=$(( result + 2 ))
      for addr in $(echo "$v6addrs" | sed 's/,/ /g'); do
        # simple comparision
        if echo "$dhcp_data" | has_dhcp6_addr "$addr"; then
          result=0
        fi
      done
    fi
    return $result
  fi
  echo "v6conf is $2"
  return 0
}
