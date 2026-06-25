#!/bin/bash
# sindan_func2.sh

## Interface Layer functions

# Get IPv4 configuration on the interface.
# get_v4ifconf <ifname> <iftype>
function get_v4ifconf() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_v4ifconf <iftype>." 1>&2
    return 1
  fi
  if networksetup -getinfo "$1"						|
   grep 'DHCP Configuration' > /dev/null; then
    echo 'dhcp'
  elif networksetup -getinfo "$1"					|
   grep 'Manually Using DHCP' > /dev/null; then
    echo 'manual and dhcp'
  elif networksetup -getinfo "$1"					|
   grep 'BOOTP Configuration' > /dev/null; then
    echo 'bootp'
  elif networksetup -getinfo "$1"					|
   grep 'Manual Configuration' > /dev/null; then
    echo 'manual'
  else
    echo 'unknown'
    return 1
  fi
  return 0
}

# Get IPv4 address on the interface.
# get_v4addr <ifname>
function get_v4addr() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_v4addr <devicename>." 1>&2
    return 1
  fi
  ifconfig "$1"								|
  sed -n 's/^.*inet \([0-9.]*\).*$/\1/p'
  return $?
}

# Get netmask of network on the interface.
# get_netmask <ifname>
function get_netmask() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_netmask <devicename>." 1>&2
    return 1
  fi
  local mask o1 o2 o3 o4
  mask=$(ifconfig "$1"							|
       sed -n 's/^.*netmask \([0-9a-fx]*\).*$/\1/p')
  o1=0x$(echo "$mask" | cut -c 3-4)
  o2=0x$(echo "$mask" | cut -c 5-6)
  o3=0x$(echo "$mask" | cut -c 7-8)
  o4=0x$(echo "$mask" | cut -c 9-10)
  printf "%d.%d.%d.%d" "$o1" "$o2" "$o3" "$o4"
  return $?
}

# Check IPv4 automatic address processing on the interface.
# check_v4autoconf <ifname> <v4ifconf>
function check_v4autoconf() {
  if [ $# -ne 2 ]; then
    echo "ERROR: check_v4autoconf <devicename> <v4ifconf>." 1>&2
    return 1
  fi
  local v4addr v4addr_type dhcp_data dhcpv4addr cmp
  if [ "$2" = "dhcp" ] || [ "$2" = "bootp" ]; then
    v4addr=$(get_v4addr "$1")
    # exclude link-local and CLAT addresses
    v4addr_type=$(check_v4addr "$v4addr")
    if [ "$v4addr_type" = "linklocal" ] ||
       [ "$v4addr_type" = "ipv4-service-continuity" ]; then
      return 0
    fi
    dhcp_data=$(ipconfig getpacket "$1")
    echo "$dhcp_data"

    # simple comparision
    dhcpv4addr=$(echo "$dhcp_data"					|
                sed -n 's/^yiaddr = \([0-9.]*\)/\1/p')
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

# Get IPv4 gateways on the interface.
# get_v4routers <ifname>
function get_v4routers() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_v4routers <devicename>." 1>&2
    return 1
  fi
  netstat -rnf inet							|
  grep ^default								|
  grep "$1"								|
  awk '{print $2}'
  return $?
}

# Get IPv4 name servers using on the system.
# get_v4nameservers XXXX
function get_v4nameservers() {
  sed -n 's/^nameserver \([0-9.]*\)$/\1/p' /etc/resolv.conf		|
  awk -v ORS=' ' '1; END{printf "\n"}'
  return $?
}

# Convert the IPv4 address to decimal value.
# ip2decimal <v4addr>
function ip2decimal() {
  if [ $# -ne 1 ]; then
    echo "ERROR: ip2decimal <v4addr>." 1>&2
    return 1
  fi
  echo "$1"								|
  tr . '\n'								|
  awk '{s = s * 256 + $1} END {print s}'
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
  if echo "$ip"                                                         |
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

# Get IPv6 configuration on the interface.
# get_v6ifconf <ifname>
function get_v6ifconf() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_v6ifconf <iftype>." 1>&2
    return 1
  fi
  if networksetup -getinfo "$1"						|
   grep 'IPv6: Automatic' > /dev/null; then
    echo 'automatic'
  elif networksetup -getinfo "$1"					|
   grep 'IPv6: Manual' > /dev/null; then
    echo 'manual'
  elif networksetup -getinfo "$1"					|
   grep 'IPv6 IP address: none' > /dev/nul; then
    echo 'linklocal'
  else
    echo 'unknown'
  fi
  return $?
}

# Get IPv6 link local address on the interface.
# get_v6lladdr <ifname>
function get_v6lladdr() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_v6lladdr <devicename>." 1>&2
    return 1
  fi
  ifconfig "$1"								|
  sed -n 's/^.*inet6 \(fe80[0-9a-f:]*\)\%.*$/\1/p'
  return $?
}

# Get router advertisement (RA) informarion on the interface.
# get_ra_info <ifname>
function get_ra_info() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_ra_info <devicename>." 1>&2
    return 1
  fi
  ndp -rn | grep "$1"
  ndp -pn | grep -v ^fe80
  return $?
}

# Get source IPv6 addresses of the RA.
# require get_ra_info() data from STDIN.
function get_ra_addrs() {
  grep ' flags='							|
  awk '{print $1}'							|
  awk -F% '{print $1}'							|
  uniq									|
  awk -F\n -v ORS=',' '{print}'						|
  sed 's/,$//'
  return $?
}

# Get flags of the RA.
# require get_ra_info() data from STDIN.
# get_ra_flags <ra_source>
function get_ra_flags() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_ra_flags <ra_source>." 1>&2
    return 1
  fi
  grep "$1"								|
  sed -n 's/^.*flags=\([A-Z]*\),.*$/\1/p'
  return $?
}

# Get router preference of the RA.
# require get_ra_info() data from STDIN.
# get_ra_pref <ra_source>
function get_ra_pref() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_ra_pref <ra_source>." 1>&2
    return 1
  fi
  grep "$1"								|
  sed -n 's/^.*pref=\([a-z]*\),.*$/\1/p'
  return $?
}

# Get hop limit of the RA.
# require get_ra_info() data from STDIN.
# get_ra_hlim <ra_source>
function get_ra_hlim() {
  :
  #TBD
}

# Get router lifetime of the RA.
# require get_ra_info() data from STDIN.
# get_ra_ltime <ra_source>
function get_ra_ltime() {
  :
  #TBD
}

# Get reachable time of the RA.
# require get_ra_info() data from STDIN.
# get_ra_reach <ra_source>
function get_ra_reach() {
  :
  #TBD
}

# Get retransmit time of the RA.
# require get_ra_info() data from STDIN.
# get_ra_retrans <ra_source>
function get_ra_retrans() {
  :
  #TBD
}

# Get prefixes of the RA.
# require get_ra_info() data from STDIN.
# get_ra_prefs <ra_source>
function get_ra_prefs() {
  if [ $# -ne 2 ]; then
    echo "ERROR: get_ra_prefs <ra_source> <devicename>." 1>&2
    return 1
  fi
  awk -v src="$1" -v dev="$2" 'BEGIN {					#
    find=0								#
    pref=""								#
    plefs=""								#
  } {									#
    while (getline line) {						#
      if (find==1) {							#
        if ((line ~ src) && !(pref=="")) {				#
          prefs=prefs ","pref						#
        }								#
        find=0								#
        pref=""								#
      } else if (line ~ dev) {						#
        split(line,p," ")						#
        pref=p[1]							#
      } else if (match(line,/^  advertised by/)) {			#
        find=1								#
      } else if (match(line,/^  No advertising router/)) {		#
        pref=""								#
      }									#
    }									#
  } END {								#
    printf "%s", prefs							#
  }'									|
  sed 's/^,//'
  return $?
}

# Get flags of the prefix information in the RA.
# require get_ra_info() data from STDIN.
# get_ra_pref_flags <ra_source> <ra_pref>
function get_ra_pref_flags() {
  if [ $# -ne 3 ]; then
    echo "ERROR: get_ra_pref_flags <ra_source> <ra_pref>"		\
         "<devicename>." 1>&2
    return 1
  fi
  awk -v src="$1" -v pref="$2" -v dev="$3" 'BEGIN {			#
    find=0								#
    data=""								#
  } {									#
    while (getline line) {						#
      if (find==1) {							#
        data=line							#
        find=0								#
      } else if (find==2) {						#
        if (line ~ src) {						#
          exit								#
        }                                                               #
        find=0                                                          #
        data=""								#
      } else if ((line ~ pref) && (line ~ dev)) {			#
        find=1								#
      } else if (match(line,/^  advertised by/)) {			#
        find=2								#
      } else if (match(line,/^  No advertising router/)) {		#
        data=""								#
      }									#
    }									#
  } END {								#
    print data								#
  }'									|
  sed -n 's/^flags=\([A-Z]*\).*$/\1/p'
  return $?
}

# Get valid lifetime of the prefix information in the RA.
# require get_ra_info() data from STDIN.
# get_ra_pref_vltime <ra_source> <ra_pref>
function get_ra_pref_vltime() {
  if [ $# -ne 3 ]; then
    echo "ERROR: get_ra_pref_vltime <ra_source> <ra_pref>"		\
         "<devicename>." 1>&2
    return 1
  fi
  awk -v src="$1" -v pref="$2" -v dev="$3" 'BEGIN {			#
    find=0								#
    data=""								#
  } {									#
    while (getline line) {						#
      if (find==1) {							#
        data=line							#
        find=0								#
      } else if (find==2) {						#
        if (line ~ src) {						#
          exit								#
        }                                                               #
        find=0                                                          #
        data=""								#
      } else if ((line ~ pref) && (line ~ dev)) {			#
        find=1								#
      } else if (match(line,/^  advertised by/)) {			#
        find=2								#
      } else if (match(line,/^  No advertising router/)) {		#
        data=""								#
      }									#
    }									#
  } END {								#
    print data								#
  }'									|
  sed -n 's/^.*vltime=\([0-9]*\).*$/\1/p'
  return $?
}

# Get preferred lifetime of the prefix information in the RA.
# require get_ra_info() data from STDIN.
# get_ra_pref_pltime <ra_source> <ra_pref>
function get_ra_pref_pltime() {
  if [ $# -ne 3 ]; then
    echo "ERROR: get_ra_pref_pltime <ra_source> <ra_pref>"		\
         "<devicename>." 1>&2
    return 1
  fi
  awk -v src="$1" -v pref="$2" -v dev="$3" 'BEGIN {			#
    find=0								#
    data=""								#
  } {									#
    while (getline line) {						#
      if (find==1) {							#
        data=line							#
        find=0								#
      } else if (find==2) {						#
        if (line ~ src) {						#
          exit								#
        }                                                               #
        find=0                                                          #
        data=""								#
      } else if ((line ~ pref) && (line ~ dev)) {			#
        find=1								#
      } else if (match(line,/^  advertised by/)) {			#
        find=2								#
      } else if (match(line,/^  No advertising router/)) {		#
        data=""								#
      }									#
    }									#
  } END {								#
    print data								#
  }'									|
  sed -n 's/^.*pltime=\([0-9]*\).*$/\1/p'
  return $?
}

# Get route information in the RA.
# require get_ra_info() data from STDIN.
# get_ra_routes <ra_source>
function get_ra_routes() {
  :
  #TBD
}

# Get route preference of the route information in the RA.
# require get_ra_info() data from STDIN.
# get_ra_route_flag <ra_source> <ra_route>
function get_ra_route_flag() {
  :
  #TBD
}

# Get route lifetime of the route information in the RA.
# require get_ra_info() data from STDIN.
# get_ra_route_ltime <ra_source> <ra_route>
function get_ra_route_ltime() {
  :
  #TBD
}

# Get recursive DNS servers in the RA.
# require get_ra_info() data from STDIN.
# get_ra_rdnsses <ra_source>
function get_ra_rdnsses() {
  :
  #TBD
}

# Get RDNSS lifetime in the RA.
# require get_ra_info() data from STDIN.
# get_ra_rdnss_ltime <ra_source> <ra_route>
function get_ra_rdnss_ltime() {
  :
  #TBD
}

# Check IPv6 automatic address processing per the RA on the interface.
# check_v6autoconf <ifname> <v6ifconf> \
#                  <ra_flags> <ra_prefix> <ra_prefix_flags>
function check_v6autoconf() {
  if [ $# -ne 5 ]; then
    echo "ERROR: check_v6autoconf <devicename> <v6ifconf> <ra_flags>"	\
         "<ra_prefix> <ra_prefix_flags>." 1>&2
    return 1
  fi
  local result o_flag m_flag a_flag v6addrs dhcp_data
  result=1
  if [ "$2" = "automatic" ]; then
    o_flag=$(echo "$3" | grep O)
    m_flag=$(echo "$3" | grep M)
    v6addrs=$(get_v6addrs "$1" "$4")
    a_flag=$(echo "$5" | grep A)
    #
    ndp -rn | grep "$1"
    ndp -pn | grep -v ^fe80
    if [ -n "$a_flag" ] && [ -n "$v6addrs" ]; then
      result=0
    fi
    if [ -n "$o_flag" ] || [ -n "$m_flag" ]; then
      dhcp_data=$(ipconfig getv6packet "$1")
      echo "$dhcp_data"
    fi
    if [ -n "$m_flag" ]; then
      result=$(( result + 2 ))
      for addr in $(echo "$v6addrs" | sed 's/,/ /g'); do
        # simple comparision
        if echo "$dhcp_data"						|
         grep "IAADDR $addr" > /dev/null 2>&1; then
          result=0
        fi
      done
    fi
    return $result
  fi
  echo "v6conf is $2"
  return 0
}

# Get IPv6 addresses configured by the RA on the interface.
# get_v6addrs <ifname> <ra_prefix>
function get_v6addrs() {
  if [ $# -le 1 ]; then
    # ra_prefix can be omitted in case of manual configuration.
    echo "ERROR: get_v6addrs <devicename> <ra_prefix>." 1>&2
    return 1
  fi
  local pref
  pref=$(echo "$2" | sed -n 's/^\([0-9a-f:]*\):\/.*$/\1/p')
  ifconfig "$1"								|
  grep -v fe80								|
  sed -n "s/^.*inet6 \(${pref}[0-9a-f:]*\).*$/\1/p"			|
  awk -F\n -v ORS=',' '{print}'						|
  sed 's/,$//'
  return $?
}

# Get IPv6 prefix length configured by the RA.
# get_prefixlen <ra_prefix>
function get_prefixlen() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_prefixlen <ra_prefix>." 1>&2
    return 1
  fi
  echo "$1"								|
  awk -F/ '{print $2}'
  return $?
}

# Get IPv6 prefix length of the IPv6 address on the interface.
# get_prefixlen_from_ifinfo <ifname> <v6addr>
function get_prefixlen_from_ifinfo() {
  if [ $# -ne 2 ]; then
    echo "ERROR: get_prefixlen_from_ifinfo <devicename> <v6addr>." 1>&2
    return 1
  fi
  ifconfig "$1"								|
  grep "$2"								|
  sed -n "s/^.*prefixlen \([0-9]*\).*$/\1/p"
  return $?
}

# Get IPv6 gateways on the interface.
# get_v6routers <ifname>
function get_v6routers() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_v6routers <devicename>." 1>&2
    return 1
  fi
  netstat -rnf inet6							|
  grep ^default								|
  grep "$1"								|
  awk '{print $2}'							|
  awk -v ORS=',' '1; END{printf "\n"}'					|
  sed 's/,$//'
  return $?
}

# Get IPv6 name servers using on the system.
# get_v6nameservers XXXX
function get_v6nameservers() {
  sed -n 's/^nameserver \([0-9a-f:]*\)$/\1/p' /etc/resolv.conf		|
  awk -v ORS=',' '1; END {printf "\n"}'					|
  sed 's/,$//'
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
  if echo "$ip"                                                         |
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

