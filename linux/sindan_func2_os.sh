#!/bin/bash
# sindan_func2_os.sh
#
# Interface Layer functions that read the state of the system and depend on
# the platform. The shared functions are in common/sindan_func2.sh.

## Interface Layer functions

# Get IPv4 configuration on the interface.
# get_v4ifconf <ifname> <iftype>
function get_v4ifconf() {
  if [ $# -ne 2 ]; then
    echo "ERROR: get_v4ifconf <ifname> <iftype>." 1>&2
    return 1
  fi
  local wwan_dev conpath
  if which nmcli > /dev/null 2>&1 &&
       [ "$(nmcli networking)" = "enabled" ]; then
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
  local plen dec
  plen=$(ip -4 addr show "$1"						|
       sed -n 's/^.*inet [0-9.]*\/\([0-9]*\) .*$/\1/p')
  dec=$(( 0xFFFFFFFF ^ ((2 ** (32 - plen)) - 1) ))
  echo "$(( dec >> 24 )).$(( (dec >> 16) & 0xFF ))."			\
       "$(( (dec >> 8) & 0xFF )).$(( dec & 0xFF ))"			|
  sed 's/ //g'
  return $?
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

# Get IPv6 configuration on the interface.
# The interface type is needed to find the connection of a WWAN device.
# get_v6ifconf <ifname> <iftype>
function get_v6ifconf() {
  if [ $# -ne 2 ]; then
    echo "ERROR: get_v6ifconf <ifname> <iftype>." 1>&2
    return 1
  fi
  local v6ifconf wwan_dev conpath
  if which nmcli > /dev/null 2>&1 &&
       [ "$(nmcli networking)" = "enabled" ]; then
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

# Get flags of the RA.
# require get_ra_info() data from STDIN.
# get_ra_flags <ra_source>
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

# Get router preference of the RA.
# require get_ra_info() data from STDIN.
# get_ra_pref <ra_source>
function get_ra_pref() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_ra_pref <ra_source>." 1>&2
    return 1
  fi
  awk -v src="$1" 'BEGIN {						#
    pref=""								#
  } {									#
    while (getline line) {						#
      if (match(line,/^Router preference/)) {				#
        split(line,t," ")						#
        pref=t[4]							#
      } else if (match(line,/^ from.*/)) {				#
        if (line ~ src) {						#
          exit								#
        } else {							#
          pref=""							#
        }								#
      }									#
    }									#
  } END {								#
    printf "%s", pref							#
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
# The interface name is not used on Linux; the macOS functions need it.
# get_ra_prefs <ra_source> <ifname>
function get_ra_prefs() {
  if [ $# -ne 2 ]; then
    echo "ERROR: get_ra_prefs <ra_source> <ifname>." 1>&2
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
# The interface name is not used on Linux; the macOS functions need it.
# get_ra_pref_flags <ra_source> <ra_pref> <ifname>
function get_ra_pref_flags() {
  if [ $# -ne 3 ]; then
    echo "ERROR: get_ra_pref_flags <ra_source> <ra_pref> <ifname>." 1>&2
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
# The interface name is not used on Linux; the macOS functions need it.
# get_ra_pref_vltime <ra_source> <ra_pref> <ifname>
function get_ra_pref_vltime() {
  if [ $# -ne 3 ]; then
    echo "ERROR: get_ra_pref_vltime <ra_source> <ra_pref> <ifname>." 1>&2
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
# The interface name is not used on Linux; the macOS functions need it.
# get_ra_pref_pltime <ra_source> <ra_pref> <ifname>
function get_ra_pref_pltime() {
  if [ $# -ne 3 ]; then
    echo "ERROR: get_ra_pref_pltime <ra_source> <ra_pref> <ifname>." 1>&2
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

## Platform specific parts of check_v4autoconf and check_v6autoconf

# Check if the IPv4 configuration is DHCP.
# is_dhcp4_conf <v4ifconf>
function is_dhcp4_conf() {
  [ "$1" = "dhcp" ] || [ "$1" = "auto" ]
}

# Print the DHCPv4 lease data of the interface.
# get_dhcp4_data <ifname>
function get_dhcp4_data() {
  local conpath
  if [ -f /var/lib/dhcp/dhclient."$1".leases ]; then
    sed 's/"//g' /var/lib/dhcp/dhclient."$1".leases
  elif systemctl is-active dhcpcd --quiet; then
    dhcpcd -4 -U "$1" | sed "s/'//g"
  elif systemctl is-active NetworkManager --quiet; then
    conpath=$(nmcli -g general.con-path device show "$1")
    nmcli -g dhcp4 connection show "$conpath"
  else
    echo 'TBD'
  fi
}

# Get the address assigned by DHCPv4.
# require get_dhcp4_data() data from STDIN.
function get_dhcp4_addr() {
  if which nmcli > /dev/null 2>&1 &&
     [ "$(nmcli networking)" = "enabled" ]; then
    sed -n 's/^.*ip_address = \([0-9.]*\)/\1/p'
  else
    sed -n 's/^ip_address=\([0-9.]*\)/\1/p'
  fi
}

# Check if the IPv6 configuration is automatic.
# is_auto6_conf <v6ifconf>
function is_auto6_conf() {
  [ "$1" = "automatic" ] || [ "$1" = "auto" ]
}

# Print the RA state for the log. Nothing to print on Linux.
# print_ra_state <ifname>
function print_ra_state() {
  return 0
}

# Print the DHCPv6 lease data of the interface.
# get_dhcp6_data <ifname>
function get_dhcp6_data() {
  local conpath
  if [ -f /var/lib/dhcp/dhclient."$1".leases ]; then
    sed 's/"//g' /var/lib/dhcp/dhclient."$1".leases
  elif systemctl is-active dhcpcd --quiet; then
    dhcpcd -6 -U "$1" | sed "s/'//g"
  elif systemctl is-active NetworkManager --quiet; then
    conpath=$(nmcli -g general.con-path device show "$1")
    nmcli -g dhcp6 connection show "$conpath"
  else
    echo 'TBD'
  fi
}

# Check if the DHCPv6 lease data contains the address.
# require get_dhcp6_data() data from STDIN.
# has_dhcp6_addr <v6addr>
function has_dhcp6_addr() {
  grep -e "dhcp6_ia_na1_ia_addr1=${1}"                                 \
       -e "ip_address = ${1}" > /dev/null 2>&1
}

