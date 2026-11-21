#!/bin/bash
# sindan_func2_os.sh
#
# Interface Layer functions that read the state of the system and depend on
# the platform. The shared functions are in common/sindan_func2.sh.

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
   grep 'IPv6 IP address: none' > /dev/null; then
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

## Platform specific parts of check_v4autoconf and check_v6autoconf

# Check if the IPv4 configuration is DHCP.
# is_dhcp4_conf <v4ifconf>
function is_dhcp4_conf() {
  [ "$1" = "dhcp" ] || [ "$1" = "bootp" ]
}

# Print the DHCPv4 lease data of the interface.
# get_dhcp4_data <ifname>
function get_dhcp4_data() {
  ipconfig getpacket "$1"
}

# Get the address assigned by DHCPv4.
# require get_dhcp4_data() data from STDIN.
function get_dhcp4_addr() {
  sed -n 's/^yiaddr = \([0-9.]*\)/\1/p'
}

# Check if the IPv6 configuration is automatic.
# is_auto6_conf <v6ifconf>
function is_auto6_conf() {
  [ "$1" = "automatic" ]
}

# Print the RA state for the log.
# print_ra_state <ifname>
function print_ra_state() {
  ndp -rn | grep "$1"
  ndp -pn | grep -v ^fe80
}

# Print the DHCPv6 lease data of the interface.
# get_dhcp6_data <ifname>
function get_dhcp6_data() {
  ipconfig getv6packet "$1"
}

# Check if the DHCPv6 lease data contains the address.
# require get_dhcp6_data() data from STDIN.
# has_dhcp6_addr <v6addr>
function has_dhcp6_addr() {
  grep "IAADDR $1" > /dev/null 2>&1
}

