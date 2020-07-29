#!/bin/bash
# sindan.sh
# version 2.2.10
VERSION="2.2.10"

# read configurationfile
source sindan.conf

#
# functions
#

## for initial
#
cleate_uuid() {
  uuidgen
}

#
hash_result() {
  if [ $# -ne 2 ]; then
    echo "ERROR: hash_result <type> <src>." 1>&2
    return 1
  fi
  type="$1"
  src="$2"
  case "$type" in
    "ssid"|"bssid")
      if [ "$LOCAL_NETWORK_PRIVACY" = "yes" ]; then
        echo "$(echo "$src" | $CMD_HASH | cut -d' ' -f1):SHA1"
      else
        echo "$src"
      fi
      ;;
    "environment")
      # XXX do something if "$LOCAL_NETWORK_PRIVACY" = "yes".
      if [ "$LOCAL_NETWORK_PRIVACY" = "yes" ]; then
        echo 'XXX'
      else
        echo "$src"
      fi
      ;;
    "mac_addr")
      if [ "$CLIENT_PRIVACY" = "yes" ]; then
        echo "$(echo "$src" | $CMD_HASH | cut -d' ' -f1):SHA1"
      else
        echo "$src"
      fi
      ;;
    "v4autoconf"|"v6autoconf")
      # XXX do something if "$CLIENT_PRIVACY" = "yes".
      if [ "$CLIENT_PRIVACY" = "yes" ]; then
        echo 'XXX'
      else
        echo "$src"
      fi
      ;;
    *) echo "$src" ;;
  esac
}

#
write_json_campaign() {
  if [ $# -ne 4 ]; then
    echo "ERROR: write_json_campaign <uuid> <mac_addr> <os> <ssid>." 1>&2
    echo "DEBUG(input data): $1, $2, $3, $4" 1>&2
    return 1
  fi
  local mac_addr; local ssid
  mac_addr=$(hash_result mac_addr "$2")
  ssid=$(hash_result ssid "$4")
  echo "{ \"log_campaign_uuid\" : \"$1\","				\
       "\"mac_addr\" : \"$mac_addr\","					\
       "\"os\" : \"$3\","						\
       "\"ssid\" : \"$ssid\","						\
       "\"version\" : \"$VERSION\","					\
       "\"occurred_at\" : \"$(date -u '+%Y-%m-%d %T')\" }"		\
  > log/campaign_"$(date -u '+%s')".json
  return $?
}

#
write_json() {
  if [ $# -ne 7 ]; then
    echo "ERROR: write_json <layer> <group> <type> <result> <target>"	\
         "<detail> <count>. ($4)" 1>&2
    echo "DEBUG(input data): $1, $2, $3, $4, $5, $6, $7" 1>&2
    return 1
  fi
  local detail
  detail=$(hash_result "$3" "$6")
  echo "{ \"layer\" : \"$1\","						\
       "\"log_group\" : \"$2\","					\
       "\"log_type\" : \"$3\","						\
       "\"log_campaign_uuid\" : \"$UUID\","				\
       "\"result\" : \"$4\","						\
       "\"target\" : \"$5\","						\
       "\"detail\" : \"$detail\","					\
       "\"occurred_at\" : \"$(date -u '+%Y-%m-%d %T')\" }"		\
  > log/sindan_"$1"_"$3"_"$7"_"$(date -u '+%s')".json
  return $?
}

## for datalink layer
#
get_devicename() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_devicename <iftype>." 1>&2
    return 1
  fi
  networksetup -listnetworkserviceorder					|
  sed -n "s/^.*: $1, Device: \([a-z0-9]*\))$/\1/p"
  return $?
}

#
do_ifdown() {
  if [ $# -ne 1 ]; then
    echo "ERROR: do_ifdown <devicename>." 1>&2
    return 1
  fi
  networksetup -setairportpower "$1" off
  return $?
}

#
do_ifup() {
  if [ $# -ne 1 ]; then
    echo "ERROR: do_ifup <devicename>." 1>&2
    return 1
  fi
  networksetup -setairportpower "$1" on
  return $?
}

#
get_os() {
  sw_vers								|
  awk -F: '{sub(/\t/,""); print $2}'					|
  awk -v ORS=' ' '1; END {printf "\n"}'
  return $?
}

#
get_ifstatus() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_ifstatus <devicename>." 1>&2
    return 1
  fi
  local status
  status=$(ifconfig "$1" | sed -n 's/^.*status: \(.*\)$/\1/p')
  if [ "$status" = "active" ]; then
    echo "$status"; return 0
  else
    echo "$status"; return 1
  fi
}

#
get_ifmtu() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_ifmtu <devicename>." 1>&2
    return 1
  fi
  ifconfig "$1"								|
  sed -n 's/^.*mtu \([0-9]*\)$/\1/p'
  return $?
}

#
get_macaddr() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_macaddr <devicename>." 1>&2
    return 1
  fi
  ifconfig "$1"								|
  sed -n 's/^.*ether \([0-9a-fA-F:]*\).*$/\1/p'				|
  tr "[:upper:]" "[:lower:]"
  return $?
}

#
get_mediatype() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_mediatype <devicename>." 1>&2
    return 1
  fi
  ifconfig "$1"								|
  sed -n 's/^.*media: \(.*\)$/\1/p'
  return $?
}

#
get_wifi_ssid() {
  $CMD_AIRPORT -I							|
  sed -n 's/^.*[^B]SSID: \(.*\).*$/\1/p'
  return $?
}

#
get_wifi_bssid() {
  $CMD_AIRPORT -I							|
  sed -n 's/^.*BSSID: \([0-9a-fA-F:]*\).*$/\1/p'			|
  tr "[:upper:]" "[:lower:]" 
  return $?
}

#
get_wifi_apoui() {
  $CMD_AIRPORT -I							|
  sed -n 's/^.*BSSID: \([0-9a-fA-F:]*\).*$/\1/p'			|
  cut -d: -f1-3								|
  tr "[:upper:]" "[:lower:]" 
  return $?
}

#
get_wifi_channel() {
  $CMD_AIRPORT -I							|
  sed -n 's/^.*channel: \([0-9]*\).*$/\1/p'
  return $?
}

#
get_wifi_rssi() {
  $CMD_AIRPORT -I							|
  sed -n 's/^.*agrCtlRSSI: \([-0-9]*\).*$/\1/p'
  return $?
}

#
get_wifi_noise() {
  $CMD_AIRPORT -I							|
  sed -n 's/^.*agrCtlNoise: \([-0-9]*\).*$/\1/p'
  return $?
}

#
get_wifi_quality() {
  :
  #TBD
}

#
get_wifi_rate() {
  $CMD_AIRPORT -I							|
  sed -n 's/^.*lastTxRate: \([0-9]*\).*$/\1/p'
  return $?
}

#
get_wifi_environment() {
  $CMD_AIRPORT -s							|
  awk '{printf "%s,%s,%s,%s\n", $1, $2, $3, $4}'
  return $?
}

## for interface layer
#
get_v4ifconf() {
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

#
get_v4addr() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_v4addr <devicename>." 1>&2
    return 1
  fi
  ifconfig "$1"								|
  sed -n 's/^.*inet \([0-9.]*\).*$/\1/p'
  return $?
}

#
get_netmask() {
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

#
check_v4autoconf() {
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

#
get_v4routers() {
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

#
get_v4nameservers() {
  sed -n 's/^nameserver \([0-9.]*\)$/\1/p' /etc/resolv.conf		|
  awk -v ORS=' ' '1; END{printf "\n"}'
  return $?
}

#
ip2decimal() {
  if [ $# -ne 1 ]; then
    echo "ERROR: ip2decimal <v4addr>." 1>&2
    return 1
  fi
  echo "$1"								|
  tr . '\n'								|
  awk '{s = s * 256 + $1} END {print s}'
}

#
compare_v4addr() {
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

#
check_v4addr() {
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
    echo 'grobal'
    return 0
  fi
  return 1
}

#
get_v6ifconf() {
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

#
get_v6lladdr() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_v6lladdr <devicename>." 1>&2
    return 1
  fi
  ifconfig "$1"								|
  sed -n 's/^.*inet6 \(fe80[0-9a-f:]*\)\%.*$/\1/p'
  return $?
}

#
get_ra_info() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_ra_info <devicename>." 1>&2
    return 1
  fi
  ndp -rn | grep "$1"
  ndp -pn | grep -v ^fe80
  return $?
}

#
get_ra_addrs() {
  # require get_ra_info() data from STDIN.
  grep ' flags='							|
  awk '{print $1}'							|
  awk -F% '{print $1}'							|
  uniq									|
  awk -F\n -v ORS=',' '{print}'						|
  sed 's/,$//'
  return $?
}

#
get_ra_flags() {
  # require get_ra_info() data from STDIN.
  if [ $# -ne 1 ]; then
    echo "ERROR: get_ra_flags <ra_source>." 1>&2
    return 1
  fi
  grep "$1"								|
  sed -n 's/^.*flags=\([A-Z]*\),.*$/\1/p'
  return $?
}

#
get_ra_hlim() {
  :
  #TBD
}

#
get_ra_ltime() {
  :
  #TBD
}

#
get_ra_reach() {
  :
  #TBD
}

#
get_ra_retrans() {
  :
  #TBD
}

#
get_ra_prefs() {
  # require get_ra_info() data from STDIN.
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

#
get_ra_pref_flags() {
  # require get_ra_info() data from STDIN.
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

#
get_ra_pref_vltime() {
  # require get_ra_info() data from STDIN.
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

#
get_ra_pref_pltime() {
  # require get_ra_info() data from STDIN.
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

#
get_ra_routes() {
  :
  #TBD
}

#
get_ra_route_flag() {
  :
  #TBD
}

#
get_ra_route_ltime() {
  :
  #TBD
}

#
get_ra_rdnsses() {
  :
  #TBD
}

#
get_ra_rdnss_ltime() {
  :
  #TBD
}

#
check_v6autoconf() {
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

#
get_v6addrs() {
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

#
get_prefixlen() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_prefixlen <ra_prefix>." 1>&2
    return 1
  fi
  echo "$1"								|
  awk -F/ '{print $2}'
  return $?
}

#
get_prefixlen_from_ifinfo() {
  if [ $# -ne 2 ]; then
    echo "ERROR: get_prefixlen_from_ifinfo <devicename> <v6addr>." 1>&2
    return 1
  fi
  ifconfig "$1"								|
  grep "$2"								|
  sed -n "s/^.*prefixlen \([0-9]*\).*$/\1/p"
  return $?
}

#
get_v6routers() {
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

#
get_v6nameservers() {
  sed -n 's/^nameserver \([0-9a-f:]*\)$/\1/p' /etc/resolv.conf		|
  awk -v ORS=',' '1; END {printf "\n"}'					|
  sed 's/,$//'
  return $?
}

#
check_v6addr() {
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

## for localnet layer
#
do_ping() {
  if [ $# -ne 2 ]; then
    echo "ERROR: do_ping <version> <target_addr>." 1>&2
    return 1
  fi
  case $1 in
    "4" ) ping -i 0.2 -c 10 "$2"; return $? ;;
    "6" ) ping6 -i 0.2 -c 10 "$2"; return $? ;;
    * ) echo "ERROR: <version> must be 4 or 6." 1>&2; return 9 ;;
  esac
}

#
get_rtt() {
  # require do_ping() data from STDIN.
  sed -n 's/^round-trip.* \([0-9\.\/]*\) .*$/\1/p'			|
  sed 's/\// /g'
  return $?
}

#
get_loss() {
  # require do_ping() data from STDIN.
  sed -n 's/^.* \([0-9.]*\)\% packet loss.*$/\1/p'
  return $?
}

#
cmdset_ping() {
  if [ $# -ne 5 ]; then
    echo "ERROR: cmdset_ping <layer> <version> <target_type>"		\
         "<target_addr> <count>." 1>&2
    return 1
  fi
  local layer=$1
  local ver=$2
  local ipv=IPv${ver}
  local type=$3
  local target=$4
  local count=$5
  local rtt_type=(min ave max dev)
  local result=$FAIL
  local string=" ping to $ipv $type: $target"
  local ping_result; local rtt_data; local rtt_loss

  if ping_result=$(do_ping "$ver" "$target"); then
    result=$SUCCESS
  fi
  write_json "$layer" "$ipv" "v${ver}alive_${type}" "$result" "$target"	\
             "$ping_result" "$count"
  if [ "$result" = "$SUCCESS" ]; then
    rtt_data=($(echo "$ping_result" | get_rtt))
    for i in 0 1 2 3; do
      write_json "$layer" "$ipv" "v${ver}rtt_${type}_${rtt_type[$i]}"	\
                 "$INFO" "$target" "${rtt_data[$i]}" "$count"
    done
    rtt_loss=$(echo "$ping_result" | get_loss)
    write_json "$layer" "$ipv" "v${ver}loss_${type}" "$INFO" "$target"	\
               "$rtt_loss" "$count"
    string="$string\n  status: ok"
    string="$string, rtt: ${rtt_data[1]} msec, loss: $rtt_loss %"
  else
    string="$string\n  status: ng"
  fi
  if [ "$VERBOSE" = "yes" ]; then
    echo -e "$string"
  fi
}

## for globalnet layer
#
do_traceroute() {
  if [ $# -ne 2 ]; then
    echo "ERROR: do_traceroute <version> <target_addr>." 1>&2
    return 1
  fi
  case $1 in
    "4" ) traceroute -n -I -w 2 -q 1 -m 20 "$2" 2>/dev/null; return $? ;;
    "6" ) traceroute6 -n -I -w 2 -q 1 -m 20 "$2" 2>/dev/null; return $? ;;
    * ) echo "ERROR: <version> must be 4 or 6." 1>&2; return 9 ;;
  esac
}

#
get_tracepath() {
  # require do_traceroute() data from STDIN.
  grep -v traceroute							|
  awk '{print $2}'							|
  awk -F\n -v ORS=',' '{print}'						|
  sed 's/,$//'
  return $?
}

#
do_pmtud() {
  if [ $# -ne 4 ]; then
    echo "ERROR: do_pmtud <version> <target_addr> <min_mtu>"		\
         "<max_mtu>." 1>&2
    return 1
  fi
  case $1 in
    "4" ) command="ping -i 0.2 -t 1"; dfopt="-D"; header=28 ;;
    "6" ) command="ping6 -i 0.2"; dfopt=""; header=48 ;;
    * ) echo "ERROR: <version> must be 4 or 6." 1>&2; return 9 ;;
  esac
  if $command -c 1 "$2" > /dev/null; then
    echo 0
    return 1
  fi
  local version=$1
  local target=$2
  local min=$3
  local max=$4
  local mid=$(( ( min + max ) / 2 ))
  local result=0

  if [ "$min" -eq "$mid" ] || [ "$max" -eq "$mid" ]; then
    echo "$(( min + header ))"
    return 0
  fi
  if $command -c 1 -s "$mid" "$dfopt" "$target" >/dev/null 2>/dev/null
  then
    result=$(do_pmtud "$version" "$target" "$mid" "$max")
  else
    result=$(do_pmtud "$version" "$target" "$min" "$mid")
  fi
  echo "$result"
}

#
cmdset_trace() {
  if [ $# -ne 5 ]; then
    echo "ERROR: cmdset_trace <layer> <version> <target_type>"		\
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
  local string=" traceroute to $ipv $type: $target"
  local path_result; local path_data

  if path_result=$(do_traceroute "$ver" "$target" | sed 's/\*/-/g'); then
    result=$SUCCESS
  fi
  write_json "$layer" "$ipv" "v${ver}path_detail_${type}" "$INFO"	\
             "$target" "$path_result" "$count"
  if [ "$result" = "$SUCCESS" ]; then
    path_data=$(echo "$path_result" | get_tracepath)
    write_json "$layer" "$ipv" "v${ver}path_${type}" "$INFO"		\
               "$target" "$path_data" "$count"
    string="$string\n  path: $path_data"
  else
    string="$string\n  status: ng"
  fi
  if [ "$VERBOSE" = "yes" ]; then
    echo -e "$string"
  fi
}

#
cmdset_pmtud() {
  if [ $# -ne 6 ]; then
    echo "ERROR: cmdset_pmtud <layer> <version> <target_type>"		\
         "<target_addr> <ifmtu> <count>." 1>&2
    return 1
  fi
  local layer=$1
  local ver=$2
  local ipv=IPv${ver}
  local type=$3
  local target=$4
  local min_mtu=1200
  local max_mtu=$5
  local count=$6
  local string=" pmtud to $ipv server: $target"
  local pmtu_result

  pmtu_result=$(do_pmtud "$ver" "$target" "$min_mtu" "$max_mtu")
  if [ "$pmtu_result" -eq 0 ]; then
    write_json "$layer" "$ipv" "v${ver}pmtu_${type}" "$INFO" "$target"	\
               unmeasurable "$count"
    string="$string\n  pmtu: unmeasurable"
  else
    write_json "$layer" "$ipv" "v${ver}pmtu_${type}" "$INFO" "$target"	\
               "$pmtu_result" "$count"
    string="$string\n  pmtu: $pmtu_result MB"
  fi
  if [ "$VERBOSE" = "yes" ]; then
    echo -e "$string"
  fi
}

## for dns layer
#
do_dnslookup() {
  if [ $# -ne 3 ]; then
    echo "ERROR: do_dnslookup <nameserver> <query_type>"		\
         "<target_fqdn>." 1>&2
    return 1
  fi
  dig @"$1" "$3" "$2" +time=1
  return $?
}

#
get_dnsans() {
  # require do_dnslookup() data from STDIN.
  if [ $# -ne 1 ]; then
    echo "ERROR: get_dnsans <query_type>." 1>&2
    return 1
  fi
  grep -v -e '^$' -e '^;'						|
  grep "	$1" -m 1						|
  awk '{print $5}'
  return $?
}

#
get_dnsttl() {
  # require do_dnslookup() data from STDIN.
  if [ $# -ne 1 ]; then
    echo "ERROR: get_dnsttl <query_type>." 1>&2
    return 1
  fi
  grep -v -e '^$' -e '^;'						|
  grep "	$1" -m 1						|
  awk '{print $2}'
  return $?
}

#
get_dnsrtt() {
  # require do_dnslookup() data from STDIN.
  sed -n 's/^;; Query time: \([0-9]*\) msec$/\1/p'
  return $?
}

#
check_dns64() {
  if [ $# -ne 1 ]; then
    echo "ERROR: check_dns64 <target_addr>." 1>&2
    return 1
  fi
  local dns_ans
  dns_ans=$(do_dnslookup "$target" AAAA ipv4only.arpa			|
          get_dnsans AAAA)
  if [ -n "$dns_ans" ]; then
    echo 'yes'
  else
    echo 'no'
  fi
}

#
cmdset_dnslookup() {
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

## for application layer
#
do_curl() {
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

#
cmdset_http() {
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

#
do_sshkeyscan() {
  if [ $# -ne 3 ]; then
    echo "ERROR: do_sshkeyscan <version> <target> <key_type>." 1>&2	\
    return 1
  fi
  ssh-keyscan -"$1" -T 5 -t "$3" "$2" 2>/dev/null
  return $?
}

#
cmdset_ssh() {
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


#
# main
#

####################
## Preparation

# Check parameters
for param in LOCKFILE MAX_RETRY IFTYPE PING_SRVS PING6_SRVS FQDNS GPDNS4 GPDNS6 V4WEB_SRVS V6WEB_SRVS CMD_AIRPORT V4SSH_SRVS V6SSH_SRVS; do
  if [ -z $(eval echo '$'$param) ]; then
    echo "ERROR: $param is null in configration file." 1>&2
    exit 1
  fi
done

####################
## Phase 0

# Set lock file
trap 'rm -f $LOCKFILE; exit 0' INT

if [ ! -e "$LOCKFILE" ]; then
  echo $$ >"$LOCKFILE"
else
  pid=$(cat "$LOCKFILE")
  if kill -0 "$pid" > /dev/null 2>&1; then
    exit 0
  else
    echo $$ >"$LOCKFILE"
    echo "Warning: previous check appears to have not finished correctly"
  fi
fi

# Make log directory
mkdir -p log

# Cleate UUID
UUID=$(cleate_uuid)

# Get devicename
devicename=$(get_devicename "$IFTYPE")

# Get MAC address
mac_addr=$(get_macaddr "$devicename")

# Get OS version
os=$(get_os)

####################
## Phase 1
echo "Phase 1: Datalink Layer checking..."
layer="datalink"

# Get current SSID
if [ "$IFTYPE" = "Wi-Fi" ]; then
  pre_ssid=$(get_wifi_ssid)
fi

# Down, Up interface
if [ "$RECONNECT" = "yes" ]; then
  # Down target interface
  if [ "$VERBOSE" = "yes" ]; then
    echo " interface:$devicename down"
  fi
  do_ifdown "$devicename"
  sleep 2

  # Start target interface
  if [ "$VERBOSE" = "yes" ]; then
    echo " interface:$devicename up"
  fi
  do_ifup "$devicename"
  sleep 5 
fi

# set specific ssid
if [ -n "$SSID" ] && [ -n "$SSID_KEY" ]; then
  echo " set SSID:$SSID"
  networksetup -setairportnetwork "$devicename" "$SSID" "$SSID_KEY"
  sleep 5
#elif [ -n "$pre_ssid" ]; then
#  networksetup -setairportnetwork "$devicename" "$pre_ssid"
#  sleep 5
fi

# Check I/F status
result_phase1=$FAIL
rcount=0
while [ "$rcount" -lt "$MAX_RETRY" ]; do
  if ifstatus=$(get_ifstatus "$devicename"); then
    result_phase1=$SUCCESS
    break
  fi
  sleep 5
  rcount=$(( rcount + 1 ))
done
if [ -n "$ifstatus" ]; then
  write_json "$layer" common ifstatus "$result_phase1" self "$ifstatus" 0
fi

# Get iftype
write_json "$layer" common iftype "$INFO" self "$IFTYPE" 0

# Get ifmtu
ifmtu=$(get_ifmtu "$devicename")
if [ -n "$ifmtu" ]; then
  write_json "$layer" common ifmtu "$INFO" self "$ifmtu" 0
fi

#
if [ "$IFTYPE" != "Wi-Fi" ]; then
  # Get media type
  media=$(get_mediatype "$devicename")
  if [ -n "$media" ]; then
    write_json "$layer" "$IFTYPE" media "$INFO" self "$media" 0
  fi
else
  # Get Wi-Fi SSID
  ssid=$(get_wifi_ssid)
  if [ -n "$ssid" ]; then
    write_json "$layer" "$IFTYPE" ssid "$INFO" self "$ssid" 0
  fi
  # Get Wi-Fi BSSID
  bssid=$(get_wifi_bssid)
  if [ -n "$bssid" ]; then
    write_json "$layer" "$IFTYPE" bssid "$INFO" self "$bssid" 0
  fi
  # Get Wi-Fi AP's OUI
  wifiapoui=$(get_wifi_apoui)
  if [ -n "$wifiapoui" ]; then
    write_json "$layer" "$IFTYPE" wifiapoui "$INFO" self "$wifiapoui" 0
  fi
  # Get Wi-Fi channel
  channel=$(get_wifi_channel)
  if [ -n "$channel" ]; then
    write_json "$layer" "$IFTYPE" channel "$INFO" self "$channel" 0
  fi
  # Get Wi-Fi RSSI
  rssi=$(get_wifi_rssi)
  if [ -n "$rssi" ]; then
    write_json "$layer" "$IFTYPE" rssi "$INFO" self "$rssi" 0
  fi
  # Get Wi-Fi noise
  noise=$(get_wifi_noise)
  if [ -n "$noise" ]; then
    write_json "$layer" "$IFTYPE" noise "$INFO" self "$noise" 0
  fi
#  # Get Wi-Fi quality
#  quarity=$(get_wifi_quality)
#  if [ -n "$quarity" ]; then
#    write_json "$layer" "$IFTYPE" quarity "$INFO" self "$quarity" 0
#  fi
  # Get Wi-Fi rate
  rate=$(get_wifi_rate)
  if [ -n "$rate" ]; then
    write_json "$layer" "$IFTYPE" rate "$INFO" self "$rate" 0
  fi
  # Get Wi-Fi environment
  environment=$(get_wifi_environment)
  if [ -n "$environment" ]; then
    write_json "$layer" "$IFTYPE" environment "$INFO" self		\
               "$environment" 0
  fi
fi

## Write campaign log file (pre)
#ssid=WIRED
#if [ "$IFTYPE" = "Wi-Fi" ]; then
#  ssid=$(get_wifi_ssid $devicename)
#fi
#write_json_campaign $UUID $mac_addr "$os" "$ssid"

# Report phase 1 results
if [ "$VERBOSE" = "yes" ]; then
  echo " datalink information:"
  echo "  datalink status: $result_phase1"
  echo "  type: $IFTYPE, dev: $devicename"
  echo "  status: $ifstatus, mtu: $ifmtu MB"
  if [ "$IFTYPE" != "Wi-Fi" ]; then
    echo "  media: $media"
  else
    echo "  ssid: $ssid, ch: $channel, rate: $rate Mbps"
    echo "  bssid: $bssid"
    echo "  rssi: $rssi dB, noise: $noise dB"
#    echo "  quarity: $quarity"
    echo "  environment:"
    echo "$environment"
  fi
fi

echo " done."

####################
## Phase 2
echo "Phase 2: Interface Layer checking..."
layer="interface"

## IPv4
if [ "$EXCL_IPv4" != "yes" ]; then
  # Get IPv4 I/F configurations
  v4ifconf=$(get_v4ifconf "$IFTYPE")
  if [ -n "$v4ifconf" ]; then
    write_json "$layer" IPv4 v4ifconf "$INFO" self "$v4ifconf" 0
  fi

  # Check IPv4 autoconf
  result_phase2_1=$FAIL
  rcount=0
  while [ $rcount -lt "$MAX_RETRY" ]; do
    if v4autoconf=$(check_v4autoconf "$devicename" "$v4ifconf"); then
      result_phase2_1=$SUCCESS
      break
    fi
    sleep 5
    rcount=$(( rcount + 1 ))
  done
  write_json "$layer" IPv4 v4autoconf "$result_phase2_1" self		\
             "$v4autoconf" 0

  # Get IPv4 address
  v4addr=$(get_v4addr "$devicename")
  if [ -n "$v4addr" ]; then
    write_json "$layer" IPv4 v4addr "$INFO" self "$v4addr" 0
  fi

  # Get IPv4 netmask
  netmask=$(get_netmask "$devicename")
  if [ -n "$netmask" ]; then
    write_json "$layer" IPv4 netmask "$INFO" self "$netmask" 0
  fi

  # Get IPv4 routers
  v4routers=$(get_v4routers "$devicename")
  if [ -n "$v4routers" ]; then
    write_json "$layer" IPv4 v4routers "$INFO" self "$v4routers" 0
  fi

  # Get IPv4 name servers
  v4nameservers=$(get_v4nameservers)
  if [ -n "$v4nameservers" ]; then
    write_json "$layer" IPv4 v4nameservers "$INFO" self			\
               "$v4nameservers" 0
  fi

  # Get IPv4 NTP servers
  #TBD

  # Report phase 2 results (IPv4)
  if [ "$VERBOSE" = "yes" ]; then
    echo " interface information:"
    echo "  intarface status (IPv4): $result_phase2_1"
    echo "  IPv4 conf: $v4ifconf"
    echo "  IPv4 addr: ${v4addr}/${netmask}"
    echo "  IPv4 router: $v4routers"
    echo "  IPv4 namesrv: $v4nameservers"
  fi
fi

## IPv6
if [ "$EXCL_IPv6" != "yes" ]; then
  # Get IPv6 I/F configurations
  v6ifconf=$(get_v6ifconf "$IFTYPE")
  if [ -n "$v6ifconf" ]; then
    write_json "$layer" IPv6 v6ifconf "$INFO" self "$v6ifconf" 0
  fi

  # Get IPv6 linklocal address
  v6lladdr=$(get_v6lladdr "$devicename")
  if [ -n "$v6lladdr" ]; then
    write_json "$layer" IPv6 v6lladdr "$INFO" self "$v6lladdr" 0
  fi

  # Report phase 2 results (IPv6)
  if [ "$VERBOSE" = "yes" ]; then
    echo "  IPv6 conf: $v6ifconf"
    echo "  IPv6 lladdr: $v6lladdr"
  fi

  # Get IPv6 RA infomation
  ra_info=$(get_ra_info "$devicename")

  # Get IPv6 RA source addresses
  ra_addrs=$(echo "$ra_info" | get_ra_addrs)
  if [ -n "$ra_addrs" ]; then
    write_json "$layer" IPv6 ra_addrs "$INFO" self "$ra_addrs" 0
  fi

  if [ "$v6ifconf" = "automatic" ] && [ -z "$ra_addrs" ]; then
    # Report phase 2 results (IPv6-RA)
    if [ "$VERBOSE" = "yes" ]; then
      echo "   RA does not exist."
    fi
  else
    if [ "$v6ifconf" = "manual" ]; then
      result_phase2_2=$SUCCESS
      v6autoconf="v6conf is $v6ifconf"
      write_json "$layer" IPv6 v6autoconf "$result_phase2_2" self	\
                 "$v6autoconf" 0
      # Get IPv6 address
      v6addrs=$(get_v6addrs "$devicename" "")
      if [ -n "$v6addr" ]; then
        write_json "$layer" IPv6 v6addrs "$INFO" "$v6ifconf" "$v6addrs" 0
      fi
      s_count=0
      for addr in $(echo "$v6addrs" | sed 's/,/ /g'); do
        # Get IPv6 prefix length
        pref_len=$(get_prefixlen_from_ifinfo "$devicename" "$addr")
        if [ -n "$pref_len" ]; then
          write_json "$layer" IPv6 pref_len "$INFO" "$addr" "$pref_len"	\
                     "$s_count"
        fi
        if [ "$VERBOSE" = "yes" ]; then
          echo "   IPv6 addr: ${addr}/${pref_len}"
        fi
        s_count=$(( s_count + 1 ))
      done
      if [ "$VERBOSE" = "yes" ]; then
        echo "   intarface status (IPv6): $result_phase2_2"
      fi
    else
      count=0
      for saddr in $(echo "$ra_addrs" | sed 's/,/ /g'); do
        # Get IPv6 RA flags
        ra_flags=$(echo "$ra_info" | get_ra_flags "$saddr")
        if [ -z "$ra_flags" ]; then
          ra_flags="none"
        fi
        write_json "$layer" RA ra_flags "$INFO" "$saddr" "$ra_flags"	\
                   "$count"

        # Get IPv6 RA parameters
#        ra_hlim=$(echo "$ra_info" | get_ra_hlim "$saddr")
#        if [ -n "$ra_hlim" ]; then
#          write_json "$layer" RA ra_hlim "$INFO" "$saddr" "$ra_hlim"	\
#                     "$count"
#        fi
#        ra_ltime=$(echo "$ra_info" | get_ra_ltime "$saddr")
#        if [ -n "$ra_ltime" ]; then
#          write_json "$layer" RA ra_ltime "$INFO" "$saddr" "$ra_ltime"	\
#                     "$count"
#        fi
#        ra_reach=$(echo "$ra_info" | get_ra_reach "$saddr")
#        if [ -n "$ra_reach" ]; then
#          write_json "$layer" RA ra_reach "$INFO" "$saddr" "$ra_reach"	\
#                     "$count"
#        fi
#        ra_retrans=$(echo "$ra_info" | get_ra_retrans "$saddr")
#        if [ -n "$ra_retrans" ]; then
#          write_json "$layer" RA ra_retrans "$INFO" "$saddr"		\
#                     "$ra_retrans" "$count"
#        fi

        # Report phase 2 results (IPv6-RA)
        if [ "$VERBOSE" = "yes" ]; then
          echo "  IPv6 RA src addr: $saddr"
          echo "   IPv6 RA flags: $ra_flags"
#          echo "   IPv6 RA hoplimit: $ra_hlim"
#          echo "   IPv6 RA lifetime: $ra_ltime"
#          echo "   IPv6 RA reachable: $ra_reach"
#          echo "   IPv6 RA retransmit: $ra_retrans"
        fi

        # Get IPv6 RA prefixes
        ra_prefs=$(echo "$ra_info" | get_ra_prefs "$saddr" "$devicename")
        if [ -n "$ra_prefs" ]; then
          write_json "$layer" RA ra_prefs "$INFO" "$saddr" "$ra_prefs"	\
                     "$count"
        fi

        s_count=0
        for pref in $(echo "$ra_prefs" | sed 's/,/ /g'); do
          # Get IPv6 RA prefix flags
          ra_pref_flags=$(echo "$ra_info"				|
                        get_ra_pref_flags "$saddr" "$pref" "$devicename")
          if [ -z "$ra_pref_flags" ]; then
            ra_pref_flags="none"
          fi
          write_json "$layer" RA ra_pref_flags "$INFO"			\
                     "${saddr}-${pref}" "$ra_pref_flags" "$s_count"

          # Get IPv6 RA prefix parameters
          ra_pref_vltime=$(echo "$ra_info"				|
                       get_ra_pref_vltime "$saddr" "$pref" "$devicename")
          if [ -n "$ra_pref_vltime" ]; then
            write_json "$layer" RA ra_pref_vltime "$INFO"		\
                       "${saddr}-${pref}" "$ra_pref_vltime" "$s_count"
          fi
          ra_pref_pltime=$(echo "$ra_info"				|
                       get_ra_pref_pltime "$saddr" "$pref" "$devicename")
          if [ -n "$ra_pref_pltime" ]; then
            write_json "$layer" RA ra_pref_pltime "$INFO"		\
                       "${saddr}-${pref}" "$ra_pref_pltime" "$s_count"
          fi

          # Get IPv6 prefix length
          ra_pref_len=$(get_prefixlen "$pref")
          if [ -n "$ra_pref_len" ]; then
            write_json "$layer" RA ra_pref_len "$INFO"			\
                       "${saddr}-${pref}" "$ra_pref_len" "$s_count"
          fi

          # Report phase 2 results (IPv6-RA-Prefix)
          if [ "$VERBOSE" = "yes" ]; then
            echo "   IPv6 RA prefix: $pref"
            echo "    flags: $ra_pref_flags"
            echo "    valid time: $ra_pref_vltime"
            echo "    preferred time: $ra_pref_pltime"
          fi

          # Check IPv6 autoconf
          result_phase2_2=$FAIL
          rcount=0
          while [ $rcount -lt "$MAX_RETRY" ]; do
            # Get IPv6 address
            v6addrs=$(get_v6addrs "$devicename" "$pref")
            if v6autoconf=$(check_v6autoconf "$devicename" "$v6ifconf"	\
                       "$ra_flags" "$pref" "$ra_pref_flags"); then
              result_phase2_2=$SUCCESS
              break
            fi
            sleep 5

            rcount=$(( rcount + 1 ))
          done
          write_json "$layer" IPv6 v6addrs "$INFO" "$pref" "$v6addrs"	\
                     "$count"
          write_json "$layer" IPv6 v6autoconf "$result_phase2_2"	\
                     "$pref" "$v6autoconf" "$count"
          if [ "$VERBOSE" = "yes" ]; then
            for addr in $(echo "$v6addrs" | sed 's/,/ /g'); do
              echo "   IPv6 addr: ${addr}/${ra_pref_len}"
            done
            echo "   intarface status (IPv6): $result_phase2_2"
          fi

          s_count=$(( s_count + 1 ))
        done

        # Get IPv6 RA routes
        #TBD

        # Get IPv6 RA RDNSSes
        #TBD

        count=$(( count + 1 ))
      done
    fi

    # Get IPv6 routers
    v6routers=$(get_v6routers "$devicename")
    if [ -n "$v6routers" ]; then
      write_json "$layer" IPv6 v6routers "$INFO" self "$v6routers" 0
    fi

    # Get IPv6 name servers
    v6nameservers=$(get_v6nameservers)
    if [ -n "$v6nameservers" ]; then
      write_json "$layer" IPv6 v6nameservers "$INFO" self "$v6nameservers" 0
    fi

    # Get IPv6 NTP servers
    #TBD

    # Report phase 2 results (IPv6)
    if [ "$VERBOSE" = "yes" ]; then
      echo "  IPv6 routers: $v6routers"
      echo "  IPv6 nameservers: $v6nameservers"
    fi
  fi
fi

echo " done."

####################
## Phase 3
echo "Phase 3: Localnet Layer checking..."
layer="localnet"

# Do ping to IPv4 routers
count=0
for target in $(echo "$v4routers" | sed 's/,/ /g'); do
  cmdset_ping "$layer" 4 router "$target" "$count" &
  count=$(( count + 1 ))
done

# Do ping to IPv4 nameservers
count=0
for target in $(echo "$v4nameservers" | sed 's/,/ /g'); do
  cmdset_ping "$layer" 4 namesrv "$target" "$count" &
  count=$(( count + 1 ))
done

# Do ping to IPv6 routers
count=0
for target in $(echo "$v6routers" | sed 's/,/ /g'); do
  cmdset_ping "$layer" 6 router "$target" "$count" &
  count=$(( count + 1 ))
done

# Do ping to IPv6 nameservers
count=0
for target in $(echo "$v6nameservers" | sed 's/,/ /g'); do
  cmdset_ping "$layer" 6 namesrv "$target" "$count" &
  count=$(( count + 1 ))
done

wait
echo " done."

####################
## Phase 4
echo "Phase 4: Globalnet Layer checking..."
layer="globalnet"

if [ "$EXCL_IPv4" != "yes" ]; then
  v4addr_type=$(check_v4addr "$v4addr")
else
  v4addr_type="linklocal"
fi
if [ "$v4addr_type" = "private" ] || [ "$v4addr_type" = "grobal" ]; then
  count=0
  for target in $(echo "$PING_SRVS" | sed 's/,/ /g'); do
    if [ "$MODE" = "probe" ]; then
      # Do ping to IPv4 routers
      count_r=0
      for target_r in $(echo "$v4routers" | sed 's/,/ /g'); do
        cmdset_ping "$layer" 4 router "$target_r" "$count_r" &
        count_r=$(( count_r + 1 ))
      done
    fi

    # Do ping to extarnal IPv4 servers
    cmdset_ping "$layer" 4 srv "$target" "$count" &

    # Do traceroute to extarnal IPv4 servers
    cmdset_trace "$layer" 4 srv "$target" "$count" &

    if [ "$MODE" = "client" ]; then
      # Check path MTU to extarnal IPv4 servers
      cmdset_pmtud "$layer" 4 srv "$target" "$ifmtu" "$count" &
    fi

    count=$(( count + 1 ))
  done
fi

if [ -n "$v6addrs" ]; then
  count=0
  for target in $(echo "$PING6_SRVS" | sed 's/,/ /g'); do
    if [ "$MODE" = "probe" ]; then
      # Do ping to IPv6 routers
      count_r=0
      for target_r in $(echo "$v6routers" | sed 's/,/ /g'); do
        cmdset_ping "$layer" 6 router "$target_r" "$count_r" &
        count_r=$(( count_r + 1 ))
      done
    fi

    # Do ping to extarnal IPv6 servers
    cmdset_ping "$layer" 6 srv "$target" "$count" &
  
    # Do traceroute to extarnal IPv6 servers
    cmdset_trace "$layer" 6 srv "$target" "$count" &
  
    if [ "$MODE" = "client" ]; then
      # Check path MTU to extarnal IPv6 servers
      cmdset_pmtud "$layer" 6 srv "$target" "$ifmtu" "$count" &
    fi

    count=$(( count + 1 ))
  done
fi

wait
echo " done."

####################
## Phase 5
echo "Phase 5: DNS Layer checking..."
layer="dns"

# Clear dns local cache
#TBD

if [ "$v4addr_type" = "private" ] || [ "$v4addr_type" = "grobal" ]; then
  count=0
  for target in $(echo "$v4nameservers" | sed 's/,/ /g'); do
    if [ "$MODE" = "probe" ]; then
      # Do ping to IPv4 nameservers
      cmdset_ping "$layer" 4 namesrv "$target" "$count" &
    fi

    # Do dns lookup for A record by IPv4
    cmdset_dnslookup "$layer" 4 A "$target" "$count" &

    # Do dns lookup for AAAA record by IPv4
    cmdset_dnslookup "$layer" 4 AAAA "$target" "$count" &

    count=$(( count + 1 ))
  done

  count=0
  for target in $(echo "$GPDNS4" | sed 's/,/ /g'); do
    if [ "$MODE" = "probe" ]; then
      # Do ping to IPv4 routers
      count_r=0
      for target_r in $(echo "$v4routers" | sed 's/,/ /g'); do
        cmdset_ping "$layer" 4 router "$target_r" "$count_r" &
        count_r=$(( count_r + 1 ))
      done

      # Do ping to IPv4 nameservers
      cmdset_ping "$layer" 4 namesrv "$target" "$count" &

      # Do traceroute to IPv4 nameservers
      cmdset_trace "$layer" 4 namesrv "$target" "$count" &
    fi

    # Do dns lookup for A record by IPv4
    cmdset_dnslookup "$layer" 4 A "$target" "$count" &

    # Do dns lookup for AAAA record by IPv4
    cmdset_dnslookup "$layer" 4 AAAA "$target" "$count" &

    count=$(( count + 1 ))
  done
fi

exist_dns64="no"
if [ -n "$v6addrs" ]; then
  count=0
  for target in $(echo "$v6nameservers" | sed 's/,/ /g'); do
    if [ "$MODE" = "probe" ]; then
      # Do ping to IPv6 nameservers
      cmdset_ping "$layer" 6 namesrv "$target" "$count" &
    fi

    # Do dns lookup for A record by IPv6
    cmdset_dnslookup "$layer" 6 A "$target" "$count" &

    # Do dns lookup for AAAA record by IPv6
    cmdset_dnslookup "$layer" 6 AAAA "$target" "$count" &

    # check DNS64
    exist_dns64=$(check_dns64 "$target")

    count=$(( count + 1 ))
  done

  count=0
  for target in $(echo "$GPDNS6" | sed 's/,/ /g'); do
    if [ "$MODE" = "probe" ]; then
      # Do ping to IPv6 routers
      count_r=0
      for target_r in $(echo "$v6routers" | sed 's/,/ /g'); do
        cmdset_ping "$layer" 6 router "$target_r" "$count_r" &
        count_r=$(( count_r + 1 ))
      done

      # Do ping to IPv6 nameservers
      cmdset_ping "$layer" 6 namesrv "$target" "$count" &

      # Do traceroute to IPv6 nameservers
      cmdset_trace "$layer" 6 namesrv "$target" "$count" &
    fi

    # Do dns lookup for A record by IPv6
    cmdset_dnslookup "$layer" 6 A "$target" "$count" &

    # Do dns lookup for AAAA record by IPv6
    cmdset_dnslookup "$layer" 6 AAAA "$target" "$count" &

    count=$(( count + 1 ))
  done
fi

wait
echo " done."

####################
## Phase 6
echo "Phase 6: Application Layer checking..."
layer="app"

if [ "$v4addr_type" = "private" ] || [ "$v4addr_type" = "grobal" ]; then
  count=0
  for target in $(echo "$V4WEB_SRVS" | sed 's/,/ /g'); do
    if [ "$MODE" = "probe" ]; then
      # Do ping to IPv4 routers
      count_r=0
      for target_r in $(echo "$v4routers" | sed 's/,/ /g'); do
        cmdset_ping "$layer" 4 router "$target_r" "$count_r" &
        count_r=$(( count_r + 1 ))
      done

      # Do ping to IPv4 web servers
      cmdset_ping "$layer" 4 websrv "$target" "$count" &

      # Do traceroute to IPv4 web servers
      cmdset_trace "$layer" 4 websrv "$target" "$count" &
    fi

    # Do curl to IPv4 web servers by IPv4
    cmdset_http "$layer" 4 websrv "$target" "$count" &

    # Do measure http throuput by IPv4
    #TBD
    # v4http_throughput_srv

    count=$(( count + 1 ))
  done

  count=0
  for target in $(echo "$V4SSH_SRVS" | sed 's/,/ /g'); do
    if [ "$MODE" = "probe" ]; then
      target_fqdn=$(echo $target | awk -F_ '{print $1}')

      # Do ping to IPv4 ssh servers
      cmdset_ping "$layer" 4 sshsrv "$target_fqdn" "$count" &

      # Do traceroute to IPv4 ssh servers
      cmdset_trace "$layer" 4 sshsrv "$target_fqdn" "$count" &
    fi

    # Do ssh-keyscan to IPv4 ssh servers by IPv4
    cmdset_ssh "$layer" 4 sshsrv "$target" "$count" &

    count=$(( count + 1 ))
  done
fi

if [ -n "$v6addrs" ]; then
  count=0
  for target in $(echo "$V6WEB_SRVS" | sed 's/,/ /g'); do
    if [ "$MODE" = "probe" ]; then
      count_r=0
      for target_r in $(echo "$v6routers" | sed 's/,/ /g'); do
        cmdset_ping "$layer" 6 router "$target_r" "$count_r" &
        count_r=$(( count_r + 1 ))
      done

      # Do ping to IPv6 web servers
      cmdset_ping "$layer" 6 websrv "$target" "$count" &

      # Do traceroute to IPv6 web servers
      cmdset_trace "$layer" 6 websrv "$target" "$count" &
    fi

    # Do curl to IPv6 web servers by IPv6
    cmdset_http "$layer" 6 websrv "$target" "$count" &

    # Do measure http throuput by IPv6
    #TBD
    # v6http_throughput_srv

    count=$(( count + 1 ))
  done

  count=0
  for target in $(echo "$V6SSH_SRVS" | sed 's/,/ /g'); do
    if [ "$MODE" = "probe" ]; then
      target_fqdn=$(echo $target | awk -F_ '{print $1}')

      # Do ping to IPv6 ssh servers
      cmdset_ping "$layer" 6 sshsrv "$target_fqdn" "$count" &

      # Do traceroute to IPv6 ssh servers
      cmdset_trace "$layer" 6 sshsrv "$target_fqdn" "$count" &
    fi

    # Do ssh-keyscan to IPv6 ssh servers by IPv6
    cmdset_ssh "$layer" 6 sshsrv "$target" "$count" &

    count=$(( count + 1 ))
  done

  # DNS64
  if [ "$exist_dns64" = "yes" ]; then
    echo " exist dns64 server"
    count=0
    for target in $(echo "$V4WEB_SRVS" | sed 's/,/ /g'); do
      if [ "$MODE" = "probe" ]; then
        # Do ping to IPv6 routers
        count_r=0
        for target_r in $(echo "$v6routers" | sed 's/,/ /g'); do
          cmdset_ping "$layer" 6 router "$target_r" "$count_r" &
          count_r=$(( count_r + 1 ))
        done

        # Do ping to IPv4 web servers by IPv6
        cmdset_ping "$layer" 6 websrv "$target" "$count" &

        # Do traceroute to IPv4 web servers by IPv6
        cmdset_trace "$layer" 6 websrv "$target" "$count" &
      fi

      # Do curl to IPv4 web servers by IPv6
      cmdset_http "$layer" 6 websrv "$target" "$count" &

      # Do measure http throuput by IPv6
      #TBD
      # v6http_throughput_srv

      count=$(( count + 1 ))
    done

    count=0
    for target in $(echo "$V4SSH_SRVS" | sed 's/,/ /g'); do
      if [ "$MODE" = "probe" ]; then
        target_fqdn=$(echo $target | awk -F_ '{print $1}')

        # Do ping to IPv4 ssh servers by IPv6
        cmdset_ping "$layer" 6 sshsrv "$target_fqdn" "$count" &

        # Do traceroute to IPv4 ssh servers by IPv6
        cmdset_trace "$layer" 6 sshsrv "$target_fqdn" "$count" &
      fi

      # Do ssh-keyscan to IPv4 ssh servers by IPv6
      cmdset_ssh "$layer" 6 sshsrv "$target" "$count" &

      count=$(( count + 1 ))
    done
  fi
fi

wait
echo " done."

####################
## Phase 7
echo "Phase 7: Create campaign log..."

# Write campaign log file (overwrite)
ssid=WIRED
if [ "$IFTYPE" = "Wi-Fi" ]; then
  ssid=$(get_wifi_ssid "$devicename")
fi
write_json_campaign "$UUID" "$mac_addr" "$os" "$ssid"

# remove lock file
rm -f "$LOCKFILE"

echo " done."

exit 0

