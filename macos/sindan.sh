#!/bin/bash
# sindan.sh
# version 2.0.0
VERSION="2.0.0"

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
write_json_campaign() {
  (
  if [ $# -ne 4 ]; then
    echo "ERROR: write_json_campaign <uuid> <mac_addr> <os> <ssid>." 1>&2
    echo "DEBUG(input data): $1, $2, $3, $4" 1>&2
    return 1
  fi
  json="{ \"log_campaign_uuid\" : \"$1\",
          \"mac_addr\" : \"$2\",
          \"os\" : \"$3\",
          \"ssid\" : \"$4\",
          \"version\" : \"${VERSION}\",
          \"occurred_at\" : \"`date -u '+%Y-%m-%d %T'`\" }"
  echo ${json} > log/campaign_`date -u '+%s'`.json
  return $?
  )
}

#
write_json() {
  (
  if [ $# -ne 7 ]; then
    echo "ERROR: write_json <layer> <group> <type> <result> <target> <detail> <count>. ($3)" 1>&2
    echo "DEBUG(input data): $1, $2, $3, $4, $5, $6, $7" 1>&2
    return 1
  fi
  json="{ \"layer\" : \"$1\",
          \"log_group\" : \"$2\",
          \"log_type\" : \"$3\",
          \"log_campaign_uuid\" : \"${uuid}\",
          \"result\" : \"$4\",
          \"target\" : \"$5\",
          \"detail\" : \"$6\",
          \"occurred_at\" : \"`date -u '+%Y-%m-%d %T'`\" }"
  echo ${json} > log/sindan_$1_$3_$7_`date -u '+%s'`.json
  return $?
  )
}

## for datalink layer
#
do_ifdown() {
  if [ $# -ne 1 ]; then
    echo "ERROR: do_ifdown <devicename>." 1>&2
    return 1
  fi
  networksetup -setairportpower $1 off
  return $?
}

#
do_ifup() {
  if [ $# -ne 1 ]; then
    echo "ERROR: do_ifup <devicename>." 1>&2
    return 1
  fi
  networksetup -setairportpower $1 on
  return $?
}

#
get_os() {
  sw_vers								|
  awk -F: '{sub(/\t/,""); print $2}'					|
  awk -v ORS=' ' '1; END{printf "\n"}'
  return $?
}

#
get_devicename() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_devicename <iftype>." 1>&2
    return 1
  fi
  networksetup -listnetworkserviceorder					|
  sed -n "s/^.*$1, Device: \([a-z0-9]*\))$/\1/p"
  return $?
}

#
get_ifstatus() {
  (
  if [ $# -ne 1 ]; then
    echo "ERROR: get_ifstatus <devicename>." 1>&2
    return 1
  fi
  status=`ifconfig $1 | sed -n 's/^.*status: \(.*\)$/\1/p'`
  if [ "${status}" = "active" ]; then
    echo ${status}; return 0
  else
    echo ${status}; return 1
  fi
  )
}

#
get_ifmtu() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_ifmtu <devicename>." 1>&2
    return 1
  fi
  ifconfig $1								|
  sed -n 's/^.*mtu \([0-9]*\)$/\1/p'
  return $?
}

#
get_macaddr() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_macaddr <devicename>." 1>&2
    return 1
  fi
  ifconfig $1								|
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
  ifconfig $1								|
  sed -n 's/^.*media: \(.*\)$/\1/p'
  return $?
}

#
get_wifi_ssid() {
  ${CMD_AIRPORT} -I							|
  sed -n 's/^.*[^B]SSID: \(.*\).*$/\1/p'
  return $?
}

#
get_wifi_bssid() {
  ${CMD_AIRPORT} -I							|
  sed -n 's/^.*BSSID: \([0-9a-fA-F:]*\).*$/\1/p'			|
  tr "[:upper:]" "[:lower:]" 
  return $?
}

#
get_wifi_channel() {
  ${CMD_AIRPORT} -I							|
  sed -n 's/^.*channel: \([0-9]*\).*$/\1/p'
  return $?
}

#
get_wifi_rssi() {
  ${CMD_AIRPORT} -I							|
  sed -n 's/^.*agrCtlRSSI: \([-0-9]*\).*$/\1/p'
  return $?
}

#
get_wifi_noise() {
  ${CMD_AIRPORT} -I							|
  sed -n 's/^.*agrCtlNoise: \([-0-9]*\).*$/\1/p'
  return $?
}

#
get_wifi_rate() {
  ${CMD_AIRPORT} -I							|
  sed -n 's/^.*lastTxRate: \([0-9]*\).*$/\1/p'
  return $?
}

get_wifi_environment() {
  ${CMD_AIRPORT} -s							|
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
  if networksetup -getinfo "$1" | grep 'DHCP Configuration' > /dev/null
  then
    echo 'dhcp'
  elif networksetup -getinfo "$1" | grep 'Manually Using DHCP' > /dev/null
  then
    echo 'manual and dhcp'
  elif networksetup -getinfo "$1" | grep 'BOOTP Configuration' > /dev/null
  then
    echo 'bootp'
  elif networksetup -getinfo "$1" | grep 'Manual Configuration' > /dev/null
  then
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
  ifconfig $1								|
  sed -n 's/^.*inet \([0-9.]*\).*$/\1/p'
  return $?
}

#
get_netmask() {
  (
  if [ $# -ne 1 ]; then
    echo "ERROR: get_netmask <devicename>." 1>&2
    return 1
  fi
  netmask=`ifconfig $1 | sed -n 's/^.*netmask \([0-9a-fx]*\).*$/\1/p'`
  oct1=0x`echo ${netmask} | cut -c 3-4`
  oct2=0x`echo ${netmask} | cut -c 5-6`
  oct3=0x`echo ${netmask} | cut -c 7-8`
  oct4=0x`echo ${netmask} | cut -c 9-10`
  printf "%d.%d.%d.%d" ${oct1} ${oct2} ${oct3} ${oct4}
  return $?
  )
}

#
check_v4autoconf() {
  (
  if [ $# -ne 2 ]; then
    echo "ERROR: check_v4autoconf <devicename> <v4ifconf>." 1>&2
    return 1
  fi
  if [ $2 = "dhcp" -o $2 = "bootp" ]; then
    v4addr=$(get_v4addr $1)
    dhcp_data=`ipconfig getpacket $1`
    echo "${dhcp_data}"

    # simple comparision (TBD)
    dhcpv4addr=`echo "${dhcp_data}"                                     |
                sed -n 's/^yiaddr = \([0-9.]*\)/\1/p'`
    if [ -n "${dhcpv4addr}" -o -n "${v4addr}" ]; then
      return 1
    fi
    cmp=$(compare_v4addr ${dhcpv4addr} ${v4addr})
    if [ ${cmp} = "same" ]; then
      return 0
    else
      return 1
    fi
  fi
  echo "v4conf is $2"
  return 9
  )
}

#
get_v4routers() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_v4routers <devicename>." 1>&2
    return 1
  fi
  netstat -rnf inet							|
  grep ^default								|
  grep $1								|
  awk '{print $2}'
  return $?
}

#
get_v4nameservers() {
  cat /etc/resolv.conf							|
  sed -n 's/^nameserver \([0-9.]*\)$/\1/p'				|
  awk -v ORS=' ' '1; END{printf "\n"}'
  return $?
}

#
ip2decimal() {
  if [ $# -ne 1 ]; then
    echo "ERROR: ip2decimal <v4addr>." 1>&2
    return 1
  fi
  echo $1                                                               |
  tr . '\n'                                                             |
  awk '{s = s*256 + $1} END{print s}'
}

#
decimal2ip() {
  if [ $# -ne 1 ]; then
    echo "ERROR: decimal2ip <32bit_num>." 1>&2
    return 1
  fi
  printf "%d.%d.%d.%d\n" $(($n >> 24)) $(( ($n >> 16) & 0xFF)) $(( ($n >> 8) & 0xFF)) $(($n & 0xFF))
}

#
compare_v4addr() {
  (
  if [ $# -ne 2 ]; then
    echo "ERROR: compare_v4addr <v4addr1> <v4addr2>." 1>&2
    return 1
  fi
  addr1=$(ip2decimal $1)
  addr2=$(ip2decimal $2)
  if [ ${addr1} = ${addr2} ]; then
    echo "same"
  else
    echo "diff"
  fi
  )
}

#
check_v4addr() {
  if [ $# -ne 1 ]; then
    echo "ERROR: check_v4addr <v4addr>." 1>&2
    return 1
  fi
  if [ `echo $1 | egrep -v "^(([1-9]?[0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([1-9]?[0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$"` ]; then
    echo "not IP address"
    return 1
  fi
  if [ `echo $1 | grep '^127\.'` ]; then
    echo "loopback"
    return 0
  fi
  if [ `echo $1 | grep '^169\.254'` ]; then
    echo "linklocal"
    return 0
  fi
  if [ `echo $1 | grep -e '^10\.' -e '^172\.\(1[6-9]\|2[0-9]\|3[01]\)\.' -e '^192\.168\.'` ]; then
    echo "private"
    return 0
  else
    echo "grobal"
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
  if networksetup -getinfo "$1" | grep 'IPv6: Automatic' > /dev/null
  then
    echo 'automatic'
  elif networksetup -getinfo "$1" | grep 'IPv6: Manual' > /dev/null
  then
    echo 'manual'
  elif networksetup -getinfo "$1" | grep 'IPv6 IP address: none' > /dev/null
  then
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
  ifconfig $1								|
  sed -n 's/^.*inet6 \(fe80[0-9a-f:]*\)\%.*$/\1/p'
  return $?
}

#
get_ra_prefixes() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_ra_prefixes <devicename>." 1>&2
    return 1
  fi
  ndp -pn								|
  grep "if=$1"								|
  grep -v ^fe80:							|
  awk '{print $1}'							|
  awk -F\n -v ORS=',' '{print}'						|
  sed 's/,$//'
  return $?
}

#
get_ra_prefix_flags() {
  (
  if [ $# -ne 2 ]; then
    echo "ERROR: get_ra_prefix_flags <devicename> <ra_prefix>." 1>&2
    return 1
  fi
  prefix=`echo $2 | awk -F/ '{print $1}'`
  ndp -pn								|
  awk 'BEGIN{								#
    find=0;								#
    while (getline line) {						#
      if (find==1) {							#
        print line;							#
        find=0;								#
      } else if (match(line,/'"${prefix}"'.*'if="$1"'/)) {		#
        find=1;								#
      }									#
    }									#
  }'									|
  sed -n 's/^flags=\([A-Z]*\).*$/\1/p'
  return $?
  )
}

#
get_ra_flags() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_ra_flags <devicename>." 1>&2
    return 1
  fi
  ra_data=`ndp -rn | grep $1`
  if [ -z "${ra_data}" ]; then
    echo "not_exist"
    return 0
  fi
  echo ${ra_data}							|
  sed -n 's/^.*flags=\([A-Z]*\),.*$/\1/p'
  return $?
}

#
check_v6autoconf() {
  (
  if [ $# -ne 5 ]; then
    echo "ERROR: check_v6autoconf <devicename> <v6ifconf> <ra_flags> <ra_prefix> <ra_prefix_flags>." 1>&2
    return 1
  fi
  result=1
  if [ $2 = "automatic" ]; then
    o_flag=`echo $3 | grep O`
    m_flag=`echo $3 | grep M`
    v6addrs=$(get_v6addrs $1 $4)
    a_flag=`echo $5 | grep A`
    dhcp_data=""
    #
    ndp -rn | grep $1
    ndp -pn | grep $1 | grep -v ^fe80
    if [ -n "${a_flag}" -a -n "${v6addrs}" ]; then
      result=0
    fi
    if [ -n "${o_flag}" -o -n "${m_flag}" ]; then
      dhcp_data=`ipconfig getv6packet $1`
      echo "${dhcp_data}"
    fi
    if [ -n "${m_flag}" ]; then
      result=$(( result + 2 ))
      for addr in `echo ${v6addrs} | sed 's/,/ /g'`; do
        # simple comparision (TBD)
        echo "${dhcp_data}"						|
        grep "IAADDR ${addr}" > /dev/null 2>&1
        if [ $? -eq 0 ]; then
          result=0
        fi
      done
    fi
    return ${result}
  fi
  echo "v6conf is $2"
  return 0
  )
}

#
get_v6addrs() {
  (
  if [ $# -ne 2 ]; then
    echo "ERROR: get_v6addrs <devicename> <ra_prefix>." 1>&2
    return 1
  fi
  pref=`echo $2 | sed -n 's/^\([0-9a-f:]*\)::\/.*$/\1/p'`
  ifconfig $1								|
  sed -n 's/^.*inet6 \([0-9a-f:]*\).*$/\1/p'				|
  grep -v ^fe80
  return $?
  )
}

#
get_prefixlen() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_prefixlen <ra_prefix>." 1>&2
    return 1
  fi
  echo $1								|
  awk -F/ '{print $2}'
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
  grep $1								|
  awk '{print $2}'
  return $?
}

#
get_v6nameservers() {
  cat /etc/resolv.conf							|
  sed -n 's/^nameserver \([0-9a-f:]*\)$/\1/p'				|
  awk -v ORS=' ' '1; END{printf "\n"}'
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
  if [ `echo $1 | grep -e '^::1$' -e '^\(0\+:\)\{7\}0*1$'` ]; then
    echo "loopback"
    return 0
  fi
  if [ `echo $1 | grep '^fe80:'` ]; then
    echo "linklocal"
    return 0
  fi
  if [ `echo $1 | grep '^fec0:'` ]; then
    echo "sitelocal"
    return 0
  fi
  if [ `echo $1 | grep -e '^fc00:' -e '^fd00:'` ]; then
    echo "ula"
    return 0
  else
    echo "global"
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
    "4" ) ping -i 0.5 -c 10 $2; return $? ;;
    "6" ) ping6 -c 10 $2; return $? ;;
    * ) echo "ERROR: <version> must be 4 or 6." 1>&2; return 9 ;;
  esac
}

get_rtt() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_rtt <ping_result>." 1>&2
    return 1
  fi
  echo "$1"								|
  sed -n 's/^round-trip.* \([0-9\.\/]*\) .*$/\1/p'			|
  sed 's/\// /g'
  return $?
}

#
get_loss() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_loss <ping_result>." 1>&2
    return 1
  fi
  echo "$1"								|
  sed -n 's/^.* \([0-9.]*\)\% packet loss.*$/\1/p'
  return $?
}

#
cmdset_ping() {
  (
  if [ $# -ne 5 ]; then
    echo "ERROR: cmdset_ping <layer> <version> <target_type> <target_addr> <count>." 1>&2
    return 1
  fi
  layer=$1
  ver=$2
  ipv="IPv${ver}"
  type=$3
  target=$4
  count=$5
  rtt_type=(min ave max dev)
  result=${FAIL}
  string=`echo " ping to ${ipv} ${type}: ${target}"`
  ping_result=$(do_ping ${ver} ${target})
  if [ $? -eq 0 ]; then
    result=${SUCCESS}
  fi
  write_json ${layer} ${ipv} v${ver}alive_${type} ${result} ${target}	\
             "${ping_result}" ${count}
  if [ "${result}" = "${SUCCESS}" ]; then
    rtt_data=($(get_rtt "${ping_result}"))
    for i in 0 1 2 3; do
      write_json ${layer} ${ipv} "v${ver}rtt_${type}_${rtt_type[$i]}"	\
                 ${INFO} ${target} "${rtt_data[$i]}" ${count}
    done
    rtt_loss=$(get_loss "${ping_result}")
    write_json ${layer} ${ipv} v${ver}loss_${type} ${INFO} ${target}	\
               ${rtt_loss} ${count}
    string=`echo "${string}\n  status: ok, rtt: ${rtt_data[1]} msec, loss: ${rtt_loss} %"`
  else
    string=`echo "${string}\n  status: ng"`
  fi
  if [ "${VERBOSE}" = "yes" ]; then
    echo -e "${string}"
  fi
  )
}

## for globalnet layer
#
do_traceroute() {
  if [ $# -ne 2 ]; then
    echo "ERROR: do_traceroute <version> <target_addr>." 1>&2
    return 1
  fi
  case $1 in
    "4" ) traceroute -n -w 2 -q 1 -m 50 $2 2>/dev/null; return $? ;;
    "6" ) traceroute6 -n -w 2 -q 1 -m 50 $2 2>/dev/null; return $? ;;
    * ) echo "ERROR: <version> must be 4 or 6." 1>&2; return 9 ;;
  esac
}

#
get_tracepath () {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_tracepath <trace_result>." 1>&2
    return 1
  fi
  echo "$1"								|
  grep -v traceroute							|
  awk '{print $2}'							|
  awk -F\n -v ORS=',' '{print}'						|
  sed 's/,$//'
  return $?
}

#
do_pmtud() {
  (
  if [ $# -ne 4 ]; then
    echo "ERROR: do_pmtud <version> <target_addr> <min_mtu> <max_mtu>." 1>&2
    return 1
  fi
  case $1 in
    "4" ) command="ping -t 1"; dfopt="-D"; header=28 ;;
    "6" ) command="ping6"; dfopt=""; header=48 ;;
    * ) echo "ERROR: <version> must be 4 or 6." 1>&2; return 9 ;;
  esac
  ${command} -c 1 $2 > /dev/null
  if [ $? -ne 0 ]; then
    echo 0
    return 1
  fi
  version=$1
  target=$2
  min=$3
  max=$4
  mid=$(( ( min + max ) / 2 ))
  result=0
  if [ "${min}" -eq "${mid}" ] || [ "${max}" -eq "${mid}" ]; then
    echo "$(( min + header ))"
    return 0
  fi
  ${command} -c 1 -s ${mid} ${dfopt} ${target} >/dev/null 2>/dev/null
  if [ $? -eq 0 ]; then
    result=$(do_pmtud ${version} ${target} ${mid} ${max})
  else
    result=$(do_pmtud ${version} ${target} ${min} ${mid})
  fi
  echo ${result}
  )
}

#
cmdset_trace () {
  (
  if [ $# -ne 5 ]; then
    echo "ERROR: cmdset_trace <layer> <version> <target_type> <target_addr> <count>." 1>&2
    return 1
  fi
  layer=$1
  ver=$2
  ipv="IPv${ver}"
  type=$3
  target=$4
  count=$5
  result=${FAIL}
  string=`echo " traceroute to ${ipv} server: ${target}"`
  path_result=$(do_traceroute ${ver} ${target})
  if [ $? -eq 0 ]; then
    result=${SUCCESS}
  fi
  write_json ${layer} ${ipv} v${ver}path_detail_${type} ${INFO}		\
             ${target} "${path_result}" ${count}
  if [ "${result}" = "${SUCCESS}" ]; then
    path_data=$(get_tracepath "${path_result}")
    write_json ${layer} ${ipv} v${ver}path_${type} ${INFO} ${target}	\
               ${path_data} ${count}
    string=`echo "${string}\n  path: ${path_data}"`
  else
    string=`echo "${string}\n  status: ng"`
  fi
  if [ "${VERBOSE}" = "yes" ]; then
    echo -e "${string}"
  fi
  )
}

#
cmdset_pmtud () {
  (
  if [ $# -ne 6 ]; then
    echo "ERROR: cmdset_pmtud <layer> <version> <target_type> <target_addr> <ifmtu> <count>." 1>&2
    return 1
  fi
  layer=$1
  ver=$2
  ipv="IPv${ver}"
  type=$3
  target=$4
  min_mtu=1200
  max_mtu=$5
  count=$6
  string=`echo " pmtud to ${ipv} server: ${target}"`
  pmtu_result=$(do_pmtud ${ver} ${target} ${min_mtu} ${max_mtu})
  if [ "${pmtu_result}" -eq 0 ]; then
    write_json ${layer} ${ipv} v${ver}pmtu_${type} ${INFO} ${target}	\
               unmeasurable ${count}
    string=`echo "${string}\n  pmtud: unmeasurable"`
  else
    write_json ${layer} ${ipv} v${ver}pmtu_${type} ${INFO} ${target}	\
               ${pmtu_result} ${count}
    string=`echo "${string}\n  pmtu: ${pmtu_result} MB"`
  fi
  if [ "${VERBOSE}" = "yes" ]; then
    echo -e "${string}"
  fi
  )
}

## for dns layer
#
do_dnslookup() {
  if [ $# -ne 3 ]; then
    echo "ERROR: do_dnslookup <nameserver> <query_type> <target_fqdn>." 1>&2
    return 1
  fi
  dig @$1 $3 $2 +time=1
  return $?
}

#
get_dnsans() {
  if [ $# -ne 2 ]; then
    echo "ERROR: get_dnsans <query_type> <dig_result>." 1>&2
    return 1
  fi
  echo "$2"								|
  grep -v -e '^$' -e '^;'						|
  grep "	$1" -m 1						|
  awk '{print $5}'
  return $?
}

#
get_dnsttl() {
  if [ $# -ne 2 ]; then
    echo "ERROR: get_dnsttl <query_type> <dig_result>." 1>&2
    return 1
  fi
  echo "$2"								|
  grep -v -e '^$' -e '^;'						|
  grep "	$1" -m 1						|
  awk '{print $2}'
  return $?
}

#
get_dnsrtt() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_dnsrtt <dig_result>." 1>&2
    return 1
  fi
  echo "$1"								|
  sed -n 's/^;; Query time: \([0-9]*\) msec$/\1/p'
  return $?
}

#
check_dns64 () {
  (
  if [ $# -ne 1 ]; then
    echo "ERROR: check_dns64 <target_addr>." 1>&2
    return 1
  fi
  dns_result=$(do_dnslookup ${target} "AAAA" "ipv4only.arpa")
  dns_ans=$(get_dnsans "AAAA" "${dns_result}")
  if [ -n "${dns_ans}" ]; then
    echo "yes"
  else
    echo "no"
  fi
  )
}

#
cmdset_dnslookup () {
  (
  if [ $# -ne 5 ]; then
    echo "ERROR: cmdset_dnslookup <layer> <version> <target_type> <target_addr> <count>." 1>&2
    return 1
  fi
  layer=$1
  ver=$2
  ipv="IPv${ver}"
  type=$3
  target=$4
  dns_result=""
  string=`echo " dns lookup for ${type} record by ${ipv} nameserver: ${target}"`
  for fqdn in `echo ${FQDNS} | sed 's/,/ /g'`; do
    result=${FAIL}
    string=`echo "${string}\n  resolve server: ${fqdn}"`
    dns_result=$(do_dnslookup ${target} ${type} ${fqdn})
    if [ $? -eq 0 ]; then
      result=${SUCCESS}
    else
      stat=$?
    fi
    write_json ${layer} ${ipv} v${ver}dnsqry_${type}_${fqdn} ${result}	\
               ${target} "${dns_result}" ${count}
    if [ "${result}" = "${SUCCESS}" ]; then
      dns_ans=$(get_dnsans ${type} "${dns_result}")
      write_json ${layer} ${ipv} v${ver}dnsans_${type}_${fqdn} ${INFO}	\
                 ${target} "${dns_ans}" ${count}
      dns_ttl=$(get_dnsttl ${type} "${dns_result}")
      write_json ${layer} ${ipv} v${ver}dnsttl_${type}_${fqdn} ${INFO}	\
                 ${target} "${dns_ttl}" ${count}
      dns_rtt=$(get_dnsrtt "${dns_result}")
      write_json ${layer} ${ipv} v${ver}dnsrtt_${type}_${fqdn} ${INFO}	\
                 ${target} "${dns_rtt}" ${count}
      string=`echo "${string}\n   status: ok, result(ttl): ${dns_ans}(${dns_ttl} s), query time: ${dns_rtt} ms"`
    else
      string=`echo "${string}\n   status: ng ($stat)"`
    fi
  done
  if [ "${VERBOSE}" = "yes" ]; then
    echo -e "${string}"
  fi
  )
}

## for web layer
#
do_curl() {
  if [ $# -ne 2 ]; then
    echo "ERROR: do_curl <version> <target_url>." 1>&2
    return 1
  fi
  if [ $1 != 4 -a $1 != 6 ]; then
    echo "ERROR: <version> must be 4 or 6." 1>&2
    return 9
  fi
  curl -$1 --connect-timeout 5 --write-out %{http_code} --silent	\
       --output /dev/null $2
  return $?
}

#
cmdset_http () {
  (
  if [ $# -ne 5 ]; then
    echo "ERROR: cmdset_http <layer> <version> <target_type> <target_addr> <count>." 1>&2
    return 1
  fi
  layer=$1
  ver=$2
  ipv="IPv${ver}"
  type=$3
  target=$4
  count=$5
  result=${FAIL}
  string=`echo " curl to extarnal server: ${target} by ${ipv}"`
  http_ans=$(do_curl ${ver} ${target})
  if [ $? -eq 0 ]; then
    result=${SUCCESS}
  else
    stat=$?
  fi
  write_json ${layer} ${ipv} v${ver}http_${type} ${result} ${target}	\
             "${http_ans}" ${count}
  if [ "${result}" = "${SUCCESS}" ]; then
    string=`echo "${string}\n  status: ok, http status code: ${http_ans}"`
  else
    string=`echo "${string}\n  status: ng ($stat)"`
  fi
  if [ "${VERBOSE}" = "yes" ]; then
    echo -e "${string}"
  fi
  )
}


#
# main
#

####################
## Preparation

# Check parameters
for param in LOCKFILE MAX_RETRY IFTYPE PING_SRVS PING6_SRVS FQDNS GPDNS4 GPDNS6 V4WEB_SRVS V6WEB_SRVS CMD_AIRPORT; do
  if [ -z `eval echo '$'${param}` ]; then
    echo "ERROR: ${param} is null in configration file." 1>&2
    exit 1
  fi
done

####################
## Phase 0

# Set lock file
trap 'rm -f ${LOCKFILE}; exit 0' INT

if [ ! -e ${LOCKFILE} ]; then
  echo $$ >"${LOCKFILE}"
else
  pid=`cat "${LOCKFILE}"`
  kill -0 "${pid}" > /dev/null 2>&1
  if [ $? -eq 0 ]; then
    exit 0
  else
    echo $$ >"${LOCKFILE}"
    echo "Warning: previous check appears to have not finished correctly"
  fi
fi

# Make log directory
mkdir -p log

# Cleate UUID
uuid=$(cleate_uuid)

# Get devicename
devicename=$(get_devicename "${IFTYPE}")

# Get MAC address
mac_addr=$(get_macaddr ${devicename})

# Get OS version
os=$(get_os)

####################
## Phase 1
echo "Phase 1: Datalink Layer checking..."
layer="datalink"

# Get current SSID
if [ ${IFTYPE} = "Wi-Fi" ]; then
  pre_ssid=$(get_wifi_ssid)
fi

# Down, Up interface
if [ ${RECONNECT} = "yes" ]; then
  # Down target interface
  if [ "${VERBOSE}" = "yes" ]; then
    echo " interface:${devicename} down"
  fi
  do_ifdown ${devicename}
  sleep 2

  # Start target interface
  if [ "${VERBOSE}" = "yes" ]; then
    echo " interface:${devicename} up"
  fi
  do_ifup ${devicename}
  sleep 5 
fi

# set specific ssid
if [ -n "${SSID}" -a -n "${SSID_KEY}" ]; then
  echo " set SSID:${SSID}"
  networksetup -setairportnetwork ${devicename} ${SSID} ${SSID_KEY}
  sleep 5
#elif [ -n "${pre_ssid}" ]; then
#  networksetup -setairportnetwork ${devicename} "${pre_ssid}"
#  sleep 5
fi

# Check I/F status
result_phase1=${FAIL}
rcount=0
while [ "${rcount}" -lt "${MAX_RETRY}" ]; do
  ifstatus=$(get_ifstatus ${devicename})
  if [ $? -eq 0 ]; then
    result_phase1=${SUCCESS}
    break
  fi
  sleep 5
  rcount=$(( rcount + 1 ))
done
if [ -n "${ifstatus}" ]; then
  write_json ${layer} "common" ifstatus ${result_phase1} self ${ifstatus} 0
fi

# Get iftype
write_json ${layer} "common" iftype ${INFO} self ${IFTYPE} 0

# Get ifmtu
ifmtu=$(get_ifmtu ${devicename})
if [ -n "${ifmtu}" ]; then
  write_json ${layer} "common" ifmtu ${INFO} self ${ifmtu} 0
fi

#
if [ "${IFTYPE}" != "Wi-Fi" ]; then
  # Get media type
  media=$(get_mediatype ${devicename})
  if [ -n "${media}" ]; then
    write_json ${layer} "${IFTYPE}" media ${INFO} self ${media} 0
  fi
else
  # Get Wi-Fi SSID
  ssid=$(get_wifi_ssid)
  if [ -n "${ssid}" ]; then
    write_json ${layer} "${IFTYPE}" ssid ${INFO} self "${ssid}" 0
  fi
  # Get Wi-Fi BSSID
  bssid=$(get_wifi_bssid)
  if [ -n "${bssid}" ]; then
    write_json ${layer} "${IFTYPE}" bssid ${INFO} self ${bssid} 0
  fi
  # Get Wi-Fi channel
  channel=$(get_wifi_channel)
  if [ -n "${channel}" ]; then
    write_json ${layer} "${IFTYPE}" channel ${INFO} self ${channel} 0
  fi
  # Get Wi-Fi RSSI
  rssi=$(get_wifi_rssi)
  if [ -n "${rssi}" ]; then
    write_json ${layer} "${IFTYPE}" rssi ${INFO} self ${rssi} 0
  fi
  # Get Wi-Fi noise
  noise=$(get_wifi_noise)
  if [ -n "${noise}" ]; then
    write_json ${layer} "${IFTYPE}" noise ${INFO} self ${noise} 0
  fi
  # Get Wi-Fi rate
  rate=$(get_wifi_rate)
  if [ -n "${rate}" ]; then
    write_json ${layer} "${IFTYPE}" rate ${INFO} self ${rate} 0
  fi
  # Get Wi-Fi environment
  environment=$(get_wifi_environment)
  if [ -n "${environment}" ]; then
    write_json ${layer} "${IFTYPE}" environment ${INFO} self "${environment}" 0
  fi
fi

## Write campaign log file (pre)
#ssid=WIRED
#if [ "${IFTYPE}" = "Wi-Fi" ]; then
#  ssid=$(get_wifi_ssid ${devicename})
#fi
#write_json_campaign ${uuid} ${mac_addr} "${os}" "${ssid}"

# Report phase 1 results
if [ "${VERBOSE}" = "yes" ]; then
  echo " datalink information:"
  echo "  datalink status: ${result_phase1}"
  echo "  type: ${IFTYPE}, dev: ${devicename}"
  echo "  status: ${ifstatus}, mtu: ${ifmtu} MB"
  if [ "${IFTYPE}" != "Wi-Fi" ]; then
    echo "  media: ${media}"
  else
    echo "  ssid: ${ssid}, ch: ${channel}, rate: ${rate} Mbps"
    echo "  bssid: ${bssid}"
    echo "  rssi: ${rssi} dB, noise: ${noise} dB"
    echo "  environment:"
    echo "${environment}"
  fi
fi

echo " done."

####################
## Phase 2
echo "Phase 2: Interface Layer checking..."
layer="interface"

## IPv4
# Get IPv4 I/F configurations
v4ifconf=$(get_v4ifconf "${IFTYPE}")
if [ -n "${v4ifconf}" ]; then
  write_json ${layer} IPv4 v4ifconf ${INFO} self ${v4ifconf} 0
fi

# Check IPv4 autoconf
result_phase2_1=${FAIL}
rcount=0
while [ ${rcount} -lt "${MAX_RETRY}" ]; do
  v4autoconf=$(check_v4autoconf ${devicename} ${v4ifconf})
  if [ $? -eq 0 -a -n "${v4autoconf}" ]; then
    result_phase2_1=${SUCCESS}
    break
  fi
  sleep 5
  rcount=$(( rcount + 1 ))
done
write_json ${layer} IPv4 v4autoconf ${result_phase2_1} self "${v4autoconf}" 0

# Get IPv4 address
v4addr=$(get_v4addr ${devicename})
if [ -n "${v4addr}" ]; then
  write_json ${layer} IPv4 v4addr ${INFO} self ${v4addr} 0
fi

# Get IPv4 netmask
netmask=$(get_netmask ${devicename})
if [ -n "${netmask}" ]; then
  write_json ${layer} IPv4 netmask ${INFO} self ${netmask} 0
fi

# Get IPv4 routers
v4routers=$(get_v4routers ${devicename})
if [ -n "${v4routers}" ]; then
  write_json ${layer} IPv4 v4routers ${INFO} self "${v4routers}" 0
fi

# Get IPv4 name servers
v4nameservers=$(get_v4nameservers)
if [ -n "${v4nameservers}" ]; then
  write_json ${layer} IPv4 v4nameservers ${INFO} self "${v4nameservers}" 0
fi

# Get IPv4 NTP servers
#TBD

# Report phase 2 results (IPv4)
if [ "${VERBOSE}" = "yes" ]; then
  echo " interface information:"
  echo "  intarface status (IPv4): ${result_phase2_1}"
  echo "  IPv4 conf: ${v4ifconf}"
  echo "  IPv4 addr: ${v4addr}/${netmask}"
  echo "  IPv4 router: ${v4routers}"
  echo "  IPv4 namesrv: ${v4nameservers}"
fi

## IPv6
# Get IPv6 I/F configurations
v6ifconf=$(get_v6ifconf "${IFTYPE}")
if [ -n "${v6ifconf}" ]; then
  write_json ${layer} IPv6 v6ifconf ${INFO} self ${v6ifconf} 0
fi

# Get IPv6 linklocal address
v6lladdr=$(get_v6lladdr ${devicename})
if [ -n "${v6lladdr}" ]; then
  write_json ${layer} IPv6 v6lladdr ${INFO} self ${v6lladdr} 0
fi

# Get IPv6 RA flags
ra_flags=$(get_ra_flags ${devicename})
if [ -z "${ra_flags}" ]; then
  ra_flags="none"
fi
if [ -n "${ra_flags}" ]; then
  write_json ${layer} RA ra_flags ${INFO} self ${ra_flags} 0
fi

# Get IPv6 RA prefix
ra_prefixes=$(get_ra_prefixes ${devicename})
if [ -n "${ra_prefixes}" ]; then
  write_json ${layer} RA ra_prefixes ${INFO} self ${ra_prefixes} 0
fi

# Report phase 2 results (IPv6)
if [ "${VERBOSE}" = "yes" ]; then
  echo "  IPv6 conf: ${v6ifconf}"
  echo "  IPv6 lladdr: ${v6lladdr}"
fi

if [ "${ra_flags}" = "not_exist" ]; then
  if [ "${VERBOSE}" = "yes" ]; then
    echo "   RA does not exist."
  fi
else
  if [ "${VERBOSE}" = "yes" ]; then
    echo "  IPv6 RA flags: ${ra_flags}"
  fi
  count=0
  for pref in `echo ${ra_prefixes} | sed 's/,/ /g'`; do
    # Get IPv6 RA prefix flags
    ra_prefix_flags=$(get_ra_prefix_flags ${devicename} ${pref})
    write_json ${layer} RA ra_prefix_flags ${INFO} ${pref} "${ra_prefix_flags}" ${count}
    if [ "${VERBOSE}" = "yes" ]; then
      echo "  IPv6 RA prefix(flags): ${pref}(${ra_prefix_flags})"
    fi

    # Get IPv6 prefix length
    prefixlen=$(get_prefixlen ${pref})
    write_json ${layer} RA prefixlen ${INFO} ${pref} ${prefixlen} ${count}

    # Check IPv6 autoconf
    result_phase2_2=${FAIL}
    rcount=0
    while [ ${rcount} -lt "${MAX_RETRY}" ]; do
      # Get IPv6 address
      v6addrs=$(get_v6addrs ${devicename} ${pref})
      v6autoconf=$(check_v6autoconf ${devicename} ${v6ifconf} ${ra_flags} ${pref} ${ra_prefix_flags})
      if [ $? -eq 0 -a -n "${v6autoconf}" ]; then
        result_phase2_2=${SUCCESS}
        break
      fi
      sleep 5
      rcount=$(( rcount + 1 ))
    done
    write_json ${layer} IPv6 v6addrs ${INFO} ${pref} "${v6addrs}" ${count}
    write_json ${layer} IPv6 v6autoconf ${result_phase2_2} ${pref} "${v6autoconf}" ${count}
    if [ "${VERBOSE}" = "yes" ]; then
      for addr in `echo ${v6addrs} | sed 's/,/ /g'`; do
        echo "   IPv6 addr: ${addr}/${prefixlen}"
      done
      echo "   intarface status (IPv6): ${result_phase2_2}"
    fi
    count=$(( count + 1 ))
  done

  # Get IPv6 routers
  v6routers=$(get_v6routers ${devicename})
  if [ -n "${v6routers}" ]; then
    write_json ${layer} IPv6 v6routers ${INFO} self "${v6routers}" 0
  fi
  if [ "${VERBOSE}" = "yes" ]; then
    echo "  IPv6 routers: ${v6routers}"
  fi

  # Get IPv6 name servers
  v6nameservers=$(get_v6nameservers)
  if [ -n "${v6nameservers}" ]; then
    write_json ${layer} IPv6 v6nameservers ${INFO} self "${v6nameservers}" 0
  fi
  if [ "${VERBOSE}" = "yes" ]; then
    echo "  IPv6 nameservers: ${v6nameservers}"
  fi

  # Get IPv6 NTP servers
  #TBD
fi

echo " done."

####################
## Phase 3
echo "Phase 3: Localnet Layer checking..."
layer="localnet"

# Do ping to IPv4 routers
count=0
for target in `echo ${v4routers} | sed 's/,/ /g'`; do
  cmdset_ping ${layer} 4 router ${target} ${count} &
  count=$(( count + 1 ))
done

# Do ping to IPv4 nameservers
count=0
for target in `echo ${v4nameservers} | sed 's/,/ /g'`; do
  cmdset_ping ${layer} 4 namesrv ${target} ${count} &
  count=$(( count + 1 ))
done

# Do ping to IPv6 routers
count=0
for target in `echo ${v6routers} | sed 's/,/ /g'`; do
  cmdset_ping ${layer} 6 router ${target} ${count} &
  count=$(( count + 1 ))
done

# Do ping to IPv6 nameservers
count=0
for target in `echo ${v6nameservers} | sed 's/,/ /g'`; do
  cmdset_ping ${layer} 6 namesrv ${target} ${count} &
  count=$(( count + 1 ))
done

wait
echo " done."

if [ "${MODE}" = "client" ]; then
  ####################
  ## Phase 4
  echo "Phase 4: Globalnet Layer checking..."
  layer="globalnet"

  v4addr_type=$(check_v4addr ${v4addr})
  if [ "${v4addr_type}" = "private" -o "${v4addr_type}" = "grobal" ]; then
    count=0
    for target in `echo ${PING_SRVS} | sed 's/,/ /g'`; do

      # Do ping to extarnal IPv4 servers
      cmdset_ping ${layer} 4 srv ${target} ${count} &

      # Do traceroute to extarnal IPv4 servers
      cmdset_trace ${layer} 4 srv ${target} ${count} &

      # Check path MTU to extarnal IPv4 servers
      cmdset_pmtud ${layer} 4 srv ${target} ${ifmtu} ${count} &

      count=$(( count + 1 ))
    done
  fi

  if [ -n "${v6addrs}" ]; then
    count=0
    for target in `echo ${PING6_SRVS} | sed 's/,/ /g'`; do

      # Do ping to extarnal IPv6 servers
      cmdset_ping ${layer} 6 srv ${target} ${count} &
  
      # Do traceroute to extarnal IPv6 servers
      cmdset_trace ${layer} 6 srv ${target} ${count} &
  
      # Check path MTU to extarnal IPv6 servers
      cmdset_pmtud ${layer} 6 srv ${target} ${ifmtu} ${count} &

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

  if [ "${v4addr_type}" = "private" -o "${v4addr_type}" = "grobal" ]; then
    count=0
    for target in `echo "${v4nameservers} ${GPDNS4}" | sed 's/,/ /g'`; do

      # Do dns lookup for A record by IPv4
      cmdset_dnslookup ${layer} 4 A ${target} ${count} &

      # Do dns lookup for AAAA record by IPv4
      cmdset_dnslookup ${layer} 4 AAAA ${target} ${count} &

      count=$(( count + 1 ))
    done
  fi

  exist_dns64="no"
  if [ -n "${v6addrs}" ]; then
    count=0
    for target in `echo "${v6nameservers} ${GPDNS6}" | sed 's/,/ /g'`; do

      # Do dns lookup for A record by IPv6
      cmdset_dnslookup ${layer} 6 A ${target} ${count} &

      # Do dns lookup for AAAA record by IPv6
      cmdset_dnslookup ${layer} 6 AAAA ${target} ${count} &

      count=$(( count + 1 ))
    done

    # check DNS64
    for target in `echo ${v6nameservers} | sed 's/,/ /g'`; do
      exist_dns64=$(check_dns64 ${target})
    done
  fi

  wait
  echo " done."

  ####################
  ## Phase 6
  echo "Phase 6: Web Layer checking..."
  layer="web"

  if [ "${v4addr_type}" = "private" -o "${v4addr_type}" = "grobal" ]; then
    count=0
    for target in `echo ${V4WEB_SRVS} | sed 's/,/ /g'`; do

      # Do curl to IPv4 web servers by IPv4
      cmdset_http ${layer} 4 srv ${target} ${count} &

      # Do measure http throuput by IPv4
      #TBD
      # v4http_throughput_srv

      count=$(( count + 1 ))
    done
  fi

  if [ -n "${v6addrs}" ]; then
    count=0
    for target in `echo ${V6WEB_SRVS} | sed 's/,/ /g'`; do

      # Do curl to IPv6 web servers by IPv6
      cmdset_http ${layer} 6 srv ${target} ${count} &

      # Do measure http throuput by IPv6
      #TBD
      # v6http_throughput_srv

      count=$(( count + 1 ))
    done

    # DNS64
    if [ "${exist_dns64}" = "yes" ]; then
      echo " exist dns64 server"
      count=0
      for target in `echo ${V4WEB_SRVS} | sed 's/,/ /g'`; do

        # Do curl to IPv4 web servers by IPv6
        cmdset_http ${layer} 6 srv ${target} ${count} &

        # Do measure http throuput by IPv6
        #TBD
        # v6http_throughput_srv

        count=$(( count + 1 ))
      done
    fi
  fi

  wait
  echo " done."
elif [ "${MODE}" = "probe" ]; then
  ####################
  ## Phase 4
  echo "Phase 4: Local name server checking..."
  layer="dns"

  v4addr_type=$(check_v4addr ${v4addr})
  if [ "${v4addr_type}" = "private" -o "${v4addr_type}" = "grobal" ]; then
    count=0
    for target in `echo ${v4nameservers} | sed 's/,/ /g'`; do

      # Do ping to IPv4 nameservers
      cmdset_ping ${layer} 4 namesrv ${target} ${count} &

      # Do dns lookup for A record by IPv4
      cmdset_dnslookup ${layer} 4 A ${target} ${count} &

      # Do dns lookup for AAAA record by IPv4
      cmdset_dnslookup ${layer} 4 AAAA ${target} ${count} &

      count=$(( count + 1 ))
    done
  fi

  if [ -n "${v6addrs}" ]; then
    count=0
    for target in `echo ${v6nameservers} | sed 's/,/ /g'`; do

      # Do ping to IPv6 nameservers
      cmdset_ping ${layer} 6 namesrv ${target} ${count} &
  
      # Do dns lookup for A record by IPv6
      cmdset_dnslookup ${layer} 6 A ${target} ${count} &

      # Do dns lookup for AAAA record by IPv6
      cmdset_dnslookup ${layer} 6 AAAA ${target} ${count} &

      count=$(( count + 1 ))
    done
  fi

  wait
  echo " done."

  ####################
  ## Phase 5
  echo "Phase 5: Extarnal name server checking..."
  layer="dns"

  if [ "${v4addr_type}" = "private" -o "${v4addr_type}" = "grobal" ]; then
    count=0
    for target in `echo ${GPDNS4} | sed 's/,/ /g'`; do

      # Do ping to IPv4 routers
      count_r=0
      for target_r in `echo ${v4routers} | sed 's/,/ /g'`; do
        cmdset_ping ${layer} 4 router ${target_r} ${count_r} &
        count_r=$(( count_r + 1 ))
      done

      # Do ping to extarnal IPv4 nameservers
      cmdset_ping globalnet 4 namesrv ${target} ${count} &

      # Do traceroute to IPv4 nameservers
      cmdset_trace globalnet 4 srv ${target} ${count} &

      # Do dns lookup for A record by IPv4
      cmdset_dnslookup ${layer} 4 A ${target} ${count} &

      # Do dns lookup for AAAA record by IPv4
      cmdset_dnslookup ${layer} 4 AAAA ${target} ${count} &

      count=$(( count + 1 ))
    done
  fi

  if [ -n "${v6addrs}" ]; then
    count=0
    for target in `echo ${GPDNS6} | sed 's/,/ /g'`; do

      # Do ping to IPv6 routers
      count_r=0
      for target_r in `echo ${v6routers} | sed 's/,/ /g'`; do
        cmdset_ping ${layer} 6 router ${target_r} ${count_r} &
        count_r=$(( count_r + 1 ))
      done

      # Do ping to IPv6 nameservers
      cmdset_ping globalnet 6 namesrv ${target} ${count} &

      # Do traceroute to IPv6 nameservers
      cmdset_trace globalnet 6 srv ${target} ${count} &
  
      # Do dns lookup for A record by IPv6
      cmdset_dnslookup ${layer} 6 A ${target} ${count} &

      # Do dns lookup for AAAA record by IPv6
      cmdset_dnslookup ${layer} 6 AAAA ${target} ${count} &

      count=$(( count + 1 ))
    done
  fi

  wait
  echo " done."

  ####################
  ## Phase 6
  echo "Phase 6: Web Layer checking..."
  layer="web"

  if [ "${v4addr_type}" = "private" -o "${v4addr_type}" = "grobal" ]; then
    count=0
    for target in `echo ${V4WEB_SRVS} | sed 's/,/ /g'`; do

      # Do ping to IPv4 routers
      count_r=0
      for target_r in `echo ${v4routers} | sed 's/,/ /g'`; do
        cmdset_ping ${layer} 4 router ${target_r} ${count_r} &
        count_r=$(( count_r + 1 ))
      done

      # Do ping to IPv4 web servers
      cmdset_ping globalnet 4 srv ${target} ${count} &

      # Do traceroute to IPv4 web servers
      cmdset_trace globalnet 4 srv ${target} ${count} &

      # Do curl to IPv4 web servers by IPv4
      cmdset_http ${layer} 4 srv ${target} ${count} &

      # Do measure http throuput by IPv4
      #TBD
      # v4http_throughput_srv

    count=$(( count + 1 ))
    done
  fi

  if [ -n "${v6addrs}" ]; then
    count=0
    for target in `echo ${V6WEB_SRVS} | sed 's/,/ /g'`; do

      # Do ping to IPv6 routers
      count_r=0
      for target_r in `echo ${v6routers} | sed 's/,/ /g'`; do
        cmdset_ping ${layer} 6 router ${target_r} ${count_r} &
        count_r=$(( count_r + 1 ))
      done

      # Do ping to IPv6 web servers
      cmdset_ping globalnet 6 srv ${target} ${count} &

      # Do traceroute to IPv6 web servers
      cmdset_trace globalnet 6 srv ${target} ${count} &

      # Do curl to IPv6 web servers by IPv6
      cmdset_http ${layer} 6 srv ${target} ${count} &

      # Do measure http throuput by IPv6
      #TBD
      # v6http_throughput_srv

    count=$(( count + 1 ))
    done
  fi

  # DNS64
  if [ "${exist_dns64}" = "yes" ]; then
    echo " exist dns64 server"
    for target in `echo ${V4WEB_SRVS} | sed 's/,/ /g'`; do

      # Do ping to IPv6 routers
      count_r=0
      for target_r in `echo ${v6routers} | sed 's/,/ /g'`; do
        cmdset_ping ${layer} 6 router ${target_r} ${count_r} &
        count_r=$(( count_r + 1 ))
      done

      # Do ping to IPv4 web servers by IPv6
      cmdset_ping globalnet 6 srv ${target} ${count} &

      # Do traceroute to IPv4 web servers by IPv6
      cmdset_trace globalnet 6 srv ${target} ${count} &

      # Do curl to IPv4 web servers by IPv6
      cmdset_http ${layer} 6 srv ${target} ${count} &

      # Do measure http throuput by IPv6
      #TBD
      # v6http_throughput_srv

      count=$(( count + 1 ))
    done
  fi

  wait
  echo " done."
else
  echo "ERROR: MODE supports only client and probe." 1>&2
fi

####################
## Phase 7
echo "Phase 7: Create campaign log..."

# Write campaign log file (overwrite)
ssid=WIRED
if [ "${IFTYPE}" = "Wi-Fi" ]; then
  ssid=$(get_wifi_ssid ${devicename})
fi
write_json_campaign ${uuid} ${mac_addr} "${os}" "${ssid}"

# remove lock file
rm -f ${LOCKFILE}

echo " done."

exit 0

