#!/bin/bash
# sindan_func2.sh

## Interface Layer functions

# Get IPv4 configuration on the interface.
# get_v4ifconf <ifname> <iftype>
function get_v4ifconf() {
  if [ $# -ne 2 ]; then
    echo "ERROR: get_v4ifconf <ifname> <iftype>." 1>&2
    return 1
  fi
  if which nmcli > /dev/null 2>&1 &&
       [ "$(nmcli networking)" = "enabled" ]; then
    local wwan_dev; local conpath
    if [ "$2" = "WWAN" ]; then
      wwan_dev=$(get_wwan_port "$1")
      conpath=$(nmcli -g general.con-path device show "$wwan_dev")
    else
      conpath=$(nmcli -g general.con-path device show "$1")
    fi
    nmcli -g ipv4.method connection show "$conpath"
  elif [ -f /etc/dhcpcd.conf ]; then
    if grep "^interface $1" /etc/dhcpcd.conf > /dev/null 2>&1; then
      if grep "^static ip_address" /etc/dhcpcd.conf > /dev/null 2>&1; then
        echo 'manual'
      else
        echo 'dhcp'
      fi
    fi
  elif [ -f /etc/network/interfaces ]; then
    grep "^iface $1 inet" /etc/network/interfaces			|
    awk '{print $4}'
  else ## netplan
    echo 'TBD'
  fi
  return $?
}

# Get IPv4 address on the interface.
# get_v4addr <ifname>
function get_v4addr() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_v4addr <ifname>." 1>&2
    return 1
  fi
  ip -4 addr show "$1"							|
  sed -n 's/^.*inet \([0-9.]*\)\/.*$/\1/p'
  return $?
}

# Get netmask of network on the interface.
# get_netmask <ifname>
function get_netmask() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_netmask <ifname>." 1>&2
    return 1
  fi
  local plen; local dec
  plen=$(ip -4 addr show "$1"						|
       sed -n 's/^.*inet [0-9.]*\/\([0-9]*\) .*$/\1/p')
  dec=$(( 0xFFFFFFFF ^ ((2 ** (32 - plen)) - 1) ))
  echo "$(( dec >> 24 )).$(( (dec >> 16) & 0xFF ))."			\
       "$(( (dec >> 8) & 0xFF )).$(( dec & 0xFF ))"			|
  sed 's/ //g'
  return $?
}

# Check IPv4 automatic address processing on the interface.
# check_v4autoconf <ifname> <v4ifconf>
function check_v4autoconf() {
  if [ $# -ne 2 ]; then
    echo "ERROR: check_v4autoconf <ifname> <v4ifconf>." 1>&2
    return 1
  fi
  if [ "$2" = "dhcp" ] || [ "$2" = "auto" ]; then
    local v4addr; local dhcp_data=""; local dhcpv4addr; local cmp
    local conpath
    v4addr=$(get_v4addr "$1")
    if which dhcpcd > /dev/null 2>&1; then
      dhcp_data=$(dhcpcd -4 -U "$1" | sed "s/'//g")
    elif [ -f /var/lib/dhcp/dhclient."$1".leases ]; then
      dhcp_data=$(sed 's/"//g' /var/lib/dhcp/dhclient."$1".leases)
    elif which nmcli > /dev/null 2>&1 &&
         [ "$(nmcli networking)" = "enabled" ]; then
      conpath=$(nmcli -g general.con-path device show $1)
      dhcp_data=$(nmcli -g dhcp4 connection show $conpath)
    else
      dhcp_data='TBD'
    fi
    echo "$dhcp_data"

    # simple comparision
    if which nmcli > /dev/null 2>&1 &&
       [ "$(nmcli networking)" = "enabled" ]; then
      dhcpv4addr=$(echo "$dhcp_data"					|
                 sed -n 's/^.*ip_address = \([0-9.]*\)/\1/p')
    else
      dhcpv4addr=$(echo "$dhcp_data"					|
                 sed -n 's/^ip_address=\([0-9.]*\)/\1/p')
    fi
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

# Get IPv4 gateways on the interface.
# get_v4routers <ifname>
function get_v4routers() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_v4routers <ifname>." 1>&2
    return 1
  fi
  ip -4 route show dev "$1"						|
  sed -n 's/^default via \([0-9.]*\).*$/\1/p'
  return $?
}

# Get IPv4 name servers using on the system.
function get_v4nameservers() {
  local resolvconf
  if grep 127.0.0.53 /etc/resolv.conf > /dev/null 2>&1; then
    resolvconf="/run/systemd/resolve/resolv.conf"
  else
    resolvconf="/etc/resolv.conf"
  fi
  sed -n 's/^nameserver \([0-9.]*\)$/\1/p' "$resolvconf"		|
  awk -v ORS=',' '1; END {printf "\n"}'					|
  sed 's/,$//'
  return $?
}

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
    echo "ERROR: get_v6ifconf <ifname>." 1>&2
    return 1
  fi
  local v6ifconf
  if which nmcli > /dev/null 2>&1 &&
       [ "$(nmcli networking)" = "enabled" ]; then
    local wwan_dev; local conpath
    if [ "$2" = "WWAN" ]; then
      wwan_dev=$(get_wwan_port "$1")
      conpath=$(nmcli -g general.con-path device show "$wwan_dev")
    else
      conpath=$(nmcli -g general.con-path device show "$1")
    fi
    nmcli -g ipv6.method connection show "$conpath"
  elif [ -f /etc/dhcpcd.conf ]; then
    if grep "^interface $1" /etc/dhcpcd.conf > /dev/null 2>&1; then
      if grep "^static ip6_address" /etc/dhcpcd.conf > /dev/null 2>&1; then
        echo 'manual'
      else
        echo 'dhcp'
      fi
    fi
  elif [ -f /etc/network/interfaces ]; then
    v6ifconf=$(grep "$1 inet6" /etc/network/interfaces			|
             awk '{print $4}')
    if [ -n "$v6ifconf" ]; then
      echo "$v6ifconf"
    else
      echo "automatic"
    fi
  else ## netplan
    echo 'TBD'
  fi
  return $?
}

# Get IPv6 link local address on the interface.
# get_v6lladdr <ifname>
function get_v6lladdr() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_v6lladdr <ifname>." 1>&2
    return 1
  fi
  ip -6 addr show "$1" scope link					|
  sed -n 's/^.*inet6 \(fe80[0-9a-f:]*\)\/.*$/\1/p'
  return $?
}

# Get router advertisement (RA) informarion on the interface.
# get_ra_info <ifname>
function get_ra_info() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_ra_info <ifname>." 1>&2
    return 1
  fi
  rdisc6 -n "$1"
  return $?
}

# Get source IPv6 addresses of the RA.
# require get_ra_info() data from STDIN.
function get_ra_addrs() {
  grep '^ from'								|
  awk '{print $2}'							|
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
  awk -v src="$1" 'BEGIN {						#
    flags=""								#
  } {									#
    while (getline line) {						#
      if (match(line,/^Stateful address conf./)				\
          && match(line,/Yes/)) {					#
        flags=flags "M"							#
      } else if (match(line,/^Stateful other conf./)			\
                 && match(line,/Yes/)) {				#
        flags=flags "O"							#
      } else if (match(line,/^Mobile home agent/)			\
                 && match(line,/Yes/)) {				#
        flags=flags "H"							#
      } else if (match(line,/^Router preference/)) {			#
        if (match(line,/low/)) {					#
          flags=flags "l"						#
        } else if (match(line,/medium/)) {				#
          flags=flags "m"						#
        } else if (match(line,/high/)) {				#
          flags=flags "h"						#
        }								#
      } else if (match(line,/^Neighbor discovery proxy/)		\
                 && match(line,/Yes/)) {				#
        flags=flags "P"							#
      } else if (match(line,/^ from.*/)) {				#
        if (line ~ src) {						#
          exit								#
        } else {							#
          flags=""							#
        }								#
      }									#
    }									#
  } END {								#
    printf "%s", flags							#
  }'
  return $?
}

# Get hop limit of the RA.
# require get_ra_info() data from STDIN.
# get_ra_hlim <ra_source>
function get_ra_hlim() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_ra_hlim <ra_source>." 1>&2
    return 1
  fi
  awk -v src="$1" 'BEGIN {						#
    hops=""								#
  } {									#
    while (getline line) {						#
      if (match(line,/^Hop limit/)) {					#
        split(line,h," ")						#
        hops=h[4]							#
      } else if (match(line,/^ from.*/)) {				#
        if (line ~ src) {						#
          exit								#
        } else {							#
          hops=""							#
        }								#
      }									#
    }									#
  } END {								#
    printf "%s", hops							#
  }'
  return $?
}

# Get router lifetime of the RA.
# require get_ra_info() data from STDIN.
# get_ra_ltime <ra_source>
function get_ra_ltime() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_ra_ltime <ra_source>." 1>&2
    return 1
  fi
  awk -v src="$1" 'BEGIN {						#
    time=""								#
  } {									#
    while (getline line) {						#
      if (match(line,/^Router lifetime/)) {				#
        split(line,t," ")						#
        time=t[4]							#
      } else if (match(line,/^ from.*/)) {				#
        if (line ~ src) {						#
          exit								#
        } else {							#
          time=""							#
        }								#
      }									#
    }									#
  } END {								#
    printf "%s", time							#
  }'
  return $?
}

# Get reachable time of the RA.
# require get_ra_info() data from STDIN.
# get_ra_reach <ra_source>
function get_ra_reach() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_ra_reach <ra_source>." 1>&2
    return 1
  fi
  awk -v src="$1" 'BEGIN {						#
    time=""								#
  } {									#
    while (getline line) {						#
      if (match(line,/^Reachable time/)) {				#
        split(line,t," ")						#
        time=t[4]							#
      } else if (match(line,/^ from.*/)) {				#
        if (line ~ src) {						#
          exit								#
        } else {							#
          time=""							#
        }								#
      }									#
    }									#
  } END {								#
    printf "%s", time							#
  }'
  return $?
}

# Get retransmit time of the RA.
# require get_ra_info() data from STDIN.
# get_ra_retrans <ra_source>
function get_ra_retrans() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_ra_retrans <ra_source>." 1>&2
    return 1
  fi
  awk -v src="$1" 'BEGIN {						#
    time=""								#
  } {									#
    while (getline line) {						#
      if (match(line,/^Retransmit time/)) {				#
        split(line,t," ")						#
        time=t[4]							#
      } else if (match(line,/^ from.*/)) {				#
        if (line ~ src) {						#
          exit								#
        } else {							#
          time=""							#
        }								#
      }									#
    }									#
  } END {								#
    printf "%s", time							#
  }'
  return $?
}

# Get prefixes of the RA.
# require get_ra_info() data from STDIN.
# get_ra_prefs <ra_source>
function get_ra_prefs() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_ra_prefs <ra_source>." 1>&2
    return 1
  fi
  awk -v src="$1" 'BEGIN {						#
    prefs=""								#
  } {									#
    while (getline line) {						#
      if (match(line,/^ Prefix/)) {					#
        split(line,p," ")						#
        prefs=prefs ","p[3]						#
      } else if (match(line,/^ from.*/)) {				#
        if (line ~ src) {						#
          exit								#
        } else {							#
          prefs=""							#
        }								#
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
  if [ $# -ne 2 ]; then
    echo "ERROR: get_ra_pref_flags <ra_source> <ra_pref>." 1>&2
    return 1
  fi
  awk -v src="$1" -v pref="$2" 'BEGIN {					#
    find=0								#
    flags=""								#
    split(pref,p,"/")							#
  } {									#
    while (getline line) {						#
      if (find==1) {							#
        if (match(line,/^  On-link/) && match(line,/Yes/)) {		#
          flags=flags "L"						#
        } else if (match(line,/^  Autonomous address conf./)		\
                   && match(line,/Yes/)) {				#
          flags=flags "A"						#
        } else if (match(line,/^  Pref. time/)) {			#
          find=0							#
        }								#
      } else if (match(line,/^ Prefix/) && line ~ p[1]) {		#
        find=1								#
      } else if (match(line,/^ from.*/)) {				#
        if (line ~ src) {						#
          exit								#
        } else {							#
          flags=""							#
        }								#
      }									#
    }									#
  } END {								#
    printf "%s", flags							#
  }'
  return $?
}

# Get valid lifetime of the prefix information in the RA.
# require get_ra_info() data from STDIN.
# get_ra_pref_vltime <ra_source> <ra_pref>
function get_ra_pref_vltime() {
  if [ $# -ne 2 ]; then
    echo "ERROR: get_ra_pref_vltime <ra_source> <ra_pref>." 1>&2
    return 1
  fi
  awk -v src="$1" -v pref="$2" 'BEGIN {					#
    find=0								#
    time=""								#
    split(pref,p,"/")							#
  } {									#
    while (getline line) {						#
      if (find==1) {							#
        if (match(line,/^  Valid time/)) {				#
          split(line,t," ")						#
          time=t[4]							#
          find=0							#
        }								#
      } else if (match(line,/^ Prefix/) && line ~ p[1]) {		#
        find=1								#
      } else if (match(line,/^ from.*/)) {				#
        if (line ~ src) {						#
          exit								#
        } else {							#
          flags=""							#
        }								#
      }									#
    }									#
  } END {								#
    printf "%s", time							#
  }'
  return $?
}

# Get preferred lifetime of the prefix information in the RA.
# require get_ra_info() data from STDIN.
# get_ra_pref_pltime <ra_source> <ra_pref>
function get_ra_pref_pltime() {
  if [ $# -ne 2 ]; then
    echo "ERROR: get_ra_pref_pltime <ra_source> <ra_pref>." 1>&2
    return 1
  fi
  awk -v src="$1" -v pref="$2" 'BEGIN {					#
    find=0								#
    time=""								#
    split(pref,p,"/")							#
  } {									#
    while (getline line) {						#
      if (find==1) {							#
        if (match(line,/^  Pref. time/)) {				#
          split(line,t," ")						#
          time=t[4]							#
          find=0							#
        }								#
      } else if (match(line,/^ Prefix/) && line ~ p[1]) {		#
        find=1								#
      } else if (match(line,/^ from.*/)) {				#
        if (line ~ src) {						#
          exit								#
        } else {							#
          flags=""							#
        }								#
      }									#
    }									#
  } END {								#
    printf "%s", time							#
  }'
  return $?
}

# Get route information in the RA.
# require get_ra_info() data from STDIN.
# get_ra_routes <ra_source>
function get_ra_routes() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_ra_routes <ra_source>." 1>&2
    return 1
  fi
  awk -v src="$1" 'BEGIN {						#
    routes=""								#
  } {									#
    while (getline line) {						#
      if (match(line,/^ Route/)) {					#
        split(line,r," ")						#
        routes=routes ","r[3]						#
      } else if (match(line,/^ from.*/)) {				#
        if (line ~ src) {						#
          exit								#
        } else {							#
          routes=""							#
        }								#
      }									#
    }									#
  } END {								#
    printf "%s", routes							#
  }'									|
  sed 's/^,//'
  return $?
}

# Get route preference of the route information in the RA.
# require get_ra_info() data from STDIN.
# get_ra_route_flag <ra_source> <ra_route>
function get_ra_route_flag() {
  if [ $# -ne 2 ]; then
    echo "ERROR: get_ra_route_flag <ra_source> <ra_route>." 1>&2
    return 1
  fi
  awk -v src="$1" -v route="$2" 'BEGIN {				#
    find=0								#
    flag=""								#
    split(route,r,"/")							#
  } {									#
    while (getline line) {						#
      if (find==1) {							#
        if (match(line,/^  Route preference/)) {			#
          split(line,p," ")						#
          flag=p[4]							#
          find=0							#
        }								#
      } else if (match(line,/^ Route/) && line ~ r[1]) {		#
        find=1								#
      } else if (match(line,/^ from.*/)) {				#
        if (line ~ src) {						#
          exit								#
        } else {							#
          flag=""							#
        }								#
      }									#
    }									#
  } END {								#
    printf "%s", flag							#
  }'
  return $?
}

# Get route lifetime of the route information in the RA.
# require get_ra_info() data from STDIN.
# get_ra_route_ltime <ra_source> <ra_route>
function get_ra_route_ltime() {
  if [ $# -ne 2 ]; then
    echo "ERROR: get_ra_route_ltime <ra_source> <ra_route>." 1>&2
    return 1
  fi
  awk -v src="$1" -v route="$2" 'BEGIN {				#
    find=0								#
    time=""								#
    split(route,r,"/")							#
  } {									#
    while (getline line) {						#
      if (find==1) {							#
        if (match(line,/^  Route lifetime/)) {				#
          split(line,t," ")						#
          time=t[4]							#
          find=0							#
        }								#
      } else if (match(line,/^ Route/) && line ~ r[1]) {		#
        find=1								#
      } else if (match(line,/^ from.*/)) {				#
        if (line ~ src) {						#
          exit								#
        } else {							#
          time=""							#
        }								#
      }									#
    }									#
  } END {								#
    printf "%s", time							#
  }'
  return $?
}

# Get recursive DNS servers in the RA.
# require get_ra_info() data from STDIN.
# get_ra_rdnsses <ra_source>
function get_ra_rdnsses() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_ra_rdnsses <ra_source>." 1>&2
    return 1
  fi
  awk -v src="$1" 'BEGIN {						#
    rdnsses=""								#
  } {									#
    while (getline line) {						#
      if (match(line,/^ Recursive DNS server/)) {			#
        split(line,r," ")						#
        rdnsses=rdnsses ","r[5]						#
      } else if (match(line,/^ from.*/)) {				#
        if (line ~ src) {						#
          exit								#
        } else {							#
          rdnsses=""							#
        }								#
      }									#
    }									#
  } END {								#
    printf "%s", rdnsses						#
  }'									|
  sed 's/^,//'
  return $?
}

# Get RDNSS lifetime in the RA.
# require get_ra_info() data from STDIN.
# get_ra_rdnss_ltime <ra_source> <ra_route>
function get_ra_rdnss_ltime() {
  if [ $# -ne 2 ]; then
    echo "ERROR: get_ra_rdnss_ltime <ra_source> <ra_route>." 1>&2
    return 1
  fi
  awk -v src="$1" -v rdnss="$2" 'BEGIN {				#
    find=0								#
    time=""								#
  } {									#
    while (getline line) {						#
      if (find==1) {							#
        if (match(line,/^  DNS server lifetime/)) {			#
          split(line,t," ")						#
          time=t[5]							#
          find=0							#
        }								#
      } else if (match(line,/^ Recursive DNS server/)			\
                 && line ~ rdnss) {					#
        find=1								#
      } else if (match(line,/^ from.*/)) {				#
        if (line ~ src) {						#
          exit								#
        } else {							#
          time=""							#
        }								#
      }									#
    }									#
  } END {								#
    printf "%s", time							#
  }'
  return $?
}

# Check IPv6 automatic address processing per the RA on the interface.
# check_v6autoconf <ifname> <v6ifconf> \
#                  <ra_flags> <ra_prefix> <ra_prefix_flags>
function check_v6autoconf() {
  if [ $# -ne 5 ]; then
    echo "ERROR: check_v6autoconf <ifname> <v6ifconf> <ra_flags>"	\
         "<ra_prefix> <ra_prefix_flags>." 1>&2
    return 1
  fi
  local result=1
  if [ "$2" = "automatic" ] || [ "$2" = "auto" ]; then
    local o_flag; local m_flag; local a_flag; local v6addrs
    local dhcp_data=""
    o_flag=$(echo "$3" | grep O)
    m_flag=$(echo "$3" | grep M)
    v6addrs=$(get_v6addrs "$1" "$4")
    a_flag=$(echo "$5" | grep A)
    #
    rdisc6 -n "$1"
    if [ -n "$a_flag" ] && [ -n "$v6addrs" ]; then
      result=0
    fi
    if [ -n "$o_flag" ] || [ -n "$m_flag" ]; then
      local conpath
      if which dhcpcd > /dev/null 2>&1; then
        dhcp_data=$(dhcpcd -6 -U "$1" | sed "s/'//g")
      elif [ -f /var/lib/dhcp/dhclient."$1".leases ]; then
        dhcp_data=$(sed 's/"//g' /var/lib/dhcp/dhclient."$1".leases)
      elif which nmcli > /dev/null 2>&1 &&
           [ "$(nmcli networking)" = "enabled" ]; then
        conpath=$(nmcli -g general.con-path device show "$1")
        dhcp_data=$(nmcli -g dhcp6 connection show "$conpath")
      else
        dhcp_data='TBD'
      fi
      echo "$dhcp_data"
    fi
    if [ -n "$m_flag" ]; then
      result=$(( result + 2 ))
      for addr in $(echo "$v6addrs" | sed 's/,/ /g'); do
        # simple comparision
        if echo "$dhcp_data"						|
         grep -e "dhcp6_ia_na1_ia_addr1=${addr}"			\
              -e "ip_address = ${addr}" > /dev/null 2>&1; then
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
    echo "ERROR: get_v6addrs <ifname> <ra_prefix>." 1>&2
    return 1
  fi
  local pref
  pref=$(echo "$2" | sed -n 's/^\([0-9a-f:]*\):\/.*$/\1/p')
  ip -6 addr show "$1" scope global					|
  sed -n "s/^.*inet6 \(${pref}[0-9a-f:]*\)\/.*$/\1/p"			|
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
    echo "ERROR: get_prefixlen_from_ifinfo <ifname> <v6addr>." 1>&2
    return 1
  fi
  ip -6 addr show "$1" scope global					|
  grep "$2"								|
  sed -n "s/^.*inet6 [0-9a-f:]*\/\([0-9]*\).*$/\1/p"
  return $?
}

# Get IPv6 gateways on the interface.
# get_v6routers <ifname>
function get_v6routers() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_v6routers <ifname>." 1>&2
    return 1
  fi
  ip -6 route show dev "$1"						|
  sed -n "s/^default via \([0-9a-f:]*\).*$/\1/p"			|
  sed "/fe80/s/$/%$1/g"							|
  uniq									|
  awk -v ORS=',' '1; END{printf "\n"}'					|
  sed 's/,$//'
  return $?
}

# Get IPv6 name servers using on the system.
function get_v6nameservers() {
  local resolvconf
  if grep 127.0.0.53 /etc/resolv.conf > /dev/null 2>&1; then
    resolvconf="/run/systemd/resolve/resolv.conf"
  else
    resolvconf="/etc/resolv.conf"
  fi
  sed -n 's/^nameserver \([0-9a-f:]*\)$/\1/p' "$resolvconf"		|
  awk -v ORS=',' '1; END{printf "\n"}'					|
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

