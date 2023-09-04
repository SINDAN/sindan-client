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
  local mask; local o1; local o2; local o3; local o4
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
  if [ "$2" = "dhcp" ] || [ "$2" = "bootp" ]; then
    local v4addr; local dhcp_data; local dhcpv4addr; local cmp
    v4addr=$(get_v4addr "$1")
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
  local addr1; local addr2
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
  if echo "$1"								|
   grep -vE '^(([1-9]?[0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([1-9]?[0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$' > /dev/null; then
    echo 'not IP address'
    return 1
  elif echo "$1" | grep '^127\.' > /dev/null; then
    echo 'loopback'
    return 0
  elif echo "$1" | grep '^169\.254' > /dev/null; then
    echo 'linklocal'
    return 0
  elif echo "$1"							|
   grep -e '^10\.' -e '^172\.\(1[6-9]\|2[0-9]\|3[01]\)\.' -e '^192\.168\.' > /dev/null; then
    echo 'private'
    return 0
  else
    echo 'global'
    return 0
  fi
  return 1
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

# Get flags of RA.
# require get_ra_info() data from STDIN.
function get_ra_flags() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_ra_flags <ra_source>." 1>&2
    return 1
  fi
  grep "$1"								|
  sed -n 's/^.*flags=\([A-Z]*\),.*$/\1/p'
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
  local result=1
  if [ "$2" = "automatic" ]; then
    local o_flag; local m_flag; local a_flag; local v6addrs
    local dhcp_data=""
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
  # IPv6 address format check (TBD)
  #if [ ]; then
    #return 1 
  #fi
  if echo "$1"								|
   grep -e '^::1$' -e '^\(0\+:\)\{7\}0*1$' > /dev/null; then
    echo 'loopback'
    return 0
  elif echo "$1" | grep '^fe80:' > /dev/null; then
    echo 'linklocal'
    return 0
  elif echo "$1" | grep '^fec0:' > /dev/null; then
    echo 'sitelocal'
    return 0
  elif echo "$1" | grep -e '^fc00:' -e '^fd00:' > /dev/null; then
    echo 'ula'
    return 0
  else
    echo 'global'
    return 0
  fi
}

