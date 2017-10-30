#!/bin/bash
# sindan.sh
# version 1.6.4

# read configurationfile
. ./sindan.conf

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
  if [ $# -ne 4 ]; then
    echo "ERROR: write_json_campaign <uuid> <mac_addr> <os> <ssid>." 1>&2
    return 1
  fi
  local json="{ \"log_campaign_uuid\" : \"$1\",
                \"mac_addr\" : \"$2\",
                \"os\" : \"$3\",
                \"ssid\" : \"$4\",
                \"occurred_at\" : \"`date -u '+%Y-%m-%d %T'`\" }"
  echo ${json} > log/campaign_`date -u '+%s'`.json
}

#
write_json() {
  if [ $# -ne 7 ]; then
    echo "$1, $2, $3, $4, $5, $6, $7"
    echo "ERROR: write_json <layer> <group> <type> <result> <target> <detail> <count>. ($3)" 1>&2
    return 1
  fi
  local json="{ \"layer\" : \"$1\",
                \"log_group\" : \"$2\",
                \"log_type\" : \"$3\",
                \"log_campaign_uuid\" : \"${uuid}\",
                \"result\" : \"$4\",
                \"target\" : \"$5\",
                \"detail\" : \"$6\",
                \"occurred_at\" : \"`date -u '+%Y-%m-%d %T'`\" }"
  echo ${json} > log/sindan_$1_$3_$7_`date -u '+%s'`.json
}

## for datalink layer
#
get_devicename() {
    echo ${DEVNAME}
}

#
do_ifdown() {
  if [ $# -ne 1 ]; then
    echo "ERROR: do_ifdown <devicename>." 1>&2
    return 1
  fi
  ifdown $1
#  rm /var/lib/dhcp/dhclient.$1.leases
}

#
do_ifup() {
  if [ $# -ne 1 ]; then
    echo "ERROR: do_ifup <devicename>." 1>&2
    return 1
  fi
  ifup $1
}

#
get_os() {
  if type lsb_release > /dev/null 2>&1; then
    lsb_release -ds
  else
    grep PRETTY_NAME /etc/*-release | awk -F\" '{print $2}'
  fi
}

#
get_ifstatus() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_ifstatus <devicename>." 1>&2
    return 1
  fi
#  local status=`ip link show $1 | grep state | awk '{print $9}'`
  local status=`cat /sys/class/net/$1/operstate`
  if [ "${status}" = "up" ]; then
    echo ${status}; return 0
  else
    echo ${status}; return 1
  fi
}

#
get_ifmtu() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_ifmtu <devicename>." 1>&2
    return 1
  fi
#  ip link show $1 | grep mtu | awk '{print $5}'
  cat /sys/class/net/$1/mtu
}

#
get_macaddr() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_macaddr <devicename>." 1>&2
    return 1
  fi
  cat /sys/class/net/$1/address | tr "[:upper:]" "[:lower:]"
}

#
get_mediatype() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_mediatype <devicename>." 1>&2
    return 1
  fi
  local speed=`cat /sys/class/net/$1/speed`
  local duplex=`cat /sys/class/net/$1/duplex`
  echo ${speed} ${duplex}
}

#
get_wifi_ssid() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_wifi_ssid <devicename>." 1>&2
    return 1
  fi
#  wpa_cli -i $1 status | grep [^b]ssid | awk -F: '{print $2}
  iwgetid $1 --raw
}

#
get_wifi_bssid() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_wifi_bssid <devicename>." 1>&2
    return 1
  fi
#  wpa_cli -i $1 status | grep bssid | awk -F: '{print $2}
  iwgetid $1 --raw --ap | tr "[:upper:]" "[:lower:]"
}

#
get_wifi_channel() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_wifi_channel <devicename>." 1>&2
    return 1
  fi
  iwgetid $1 --raw --channel
}

#
get_wifi_rssi() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_wifi_rssi <devicename>." 1>&2
    return 1
  fi
  grep $1 /proc/net/wireless | awk '{print $4}'
}

#
get_wifi_noise() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_wifi_noise <devicename>." 1>&2
    return 1
  fi
  grep $1 /proc/net/wireless | awk '{print $5}'
}

#
get_wifi_rate() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_wifi_rate <devicename>." 1>&2
    return 1
  fi
  iwconfig $1 | sed -n 's@^.*Bit\ Rate=\([0-9.]*\) Mb/s.*$@\1@p'
}

## for interface layer
#
get_v4ifconf() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_v4ifconf <devicename>."
    return 1
  fi

  local os=$(get_os)
  if echo ${os} | grep "Raspbian" | grep -e "jessie" -e "stretch" > /dev/null; then
    if grep "interface $1" /etc/dhcpcd.conf > /dev/null; then
      echo "manual"
    else
      echo "dhcp"
    fi
  else
    grep "$1 inet" /etc/network/interfaces | awk '{print $4}'
  fi
#  echo "TBD"
}

#
check_v4autoconf() {
  if [ $# -ne 2 ]; then
    echo "ERROR: check_v4autoconf <devicename> <v4ifconf>." 1>&2
    return 1
  fi

  local os=$(get_os)
  if [ $2 = "dhcp" ]; then
    if echo ${os} | grep "Raspbian" | grep -e "jessie" -e "stretch" > /dev/null; then
      dhcpcd -4 -U $1 | sed "s/'//g"
    else
      cat /var/lib/dhcp/dhclient.$1.leases | sed 's/"//g'
    fi
    return 0
  fi
  echo "v4conf is $2"
  return 9
}

#
get_v4addr() {
  if [ $# -ne 2 ]; then
    echo "ERROR: get_v4addr <devicename> <v4ifconf>." 1>&2
    return 1
  fi
#  if [ $2 = "dhcp" ]; then
#    echo "TBD"
#  else
    ip -4 address show $1 | sed -n 's@^.*inet \([0-9.]*\)/.*$@\1@p'
#  fi
}

#
get_netmask() {
  if [ $# -ne 2 ]; then
    echo "ERROR: get_netmask <devicename> <v4ifconf>." 1>&2
    return 1
  fi
#  if [ $2 = "dhcp" ]; then
#    echo "TBD"
#  else
    local preflen=`ip -4 address show $1 | sed -n 's@^.*inet [0-9.]*/\([0-9]*\) .*$@\1@p'`
    case "${preflen}" in
      16) echo "255.255.0.0" ;;
      17) echo "255.255.128.0" ;;
      18) echo "255.255.192.0" ;;
      19) echo "255.255.224.0" ;;
      20) echo "255.255.240.0" ;;
      21) echo "255.255.248.0" ;;
      22) echo "255.255.252.0" ;;
      23) echo "255.255.254.0" ;;
      24) echo "255.255.255.0" ;;
      25) echo "255.255.255.128" ;;
      26) echo "255.255.255.192" ;;
      27) echo "255.255.255.224" ;;
      28) echo "255.255.255.240" ;;
      29) echo "255.255.255.248" ;;
      30) echo "255.255.255.252" ;;
      31) echo "255.255.255.254" ;;
      *) ;;
    esac
#  fi
}

#
get_v4routers() {
  if [ $# -ne 2 ]; then
    echo "ERROR: get_v4routers <devicename> <v4ifconf>." 1>&2
    return 1
  fi
#  if [ $2 = "dhcp" ]; then
#    echo "TBD"
#  else
    ip -4 route | grep default | grep $1 | awk '{print $3}'
#  fi
}

#
get_v4nameservers() {
  if [ $# -ne 2 ]; then
    echo "ERROR: get_v4nameservers <devicename> <v4ifconf>." 1>&2
    return 1
  fi
#  if [ $2 = "dhcp" ]; then
#    echo "TBD"
#  else
    grep nameserver /etc/resolv.conf | awk '{print $2}' | grep -v : |
     awk -v ORS=' ' '1; END{printf "\n"}'
#  fi
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
}

#
get_v6ifconf() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_v6ifconf <devicename>." 1>&2
    return 1
  fi
  local v6ifconf=`grep "$1 inet6" /etc/network/interfaces | awk '{print $4}'`
  if [ "X${v6ifconf}" != "X" ]; then
    cat ${v6ifconf}
  else
    echo "automatic"
  fi
#  echo "TBD"
}

#
get_v6lladdr() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_v6lladdr <devicename>." 1>&2
    return 1
  fi
  ip -6 address show $1 | sed -n 's@^.*inet6 \(fe80[0-9a-f:]*\)/.*$@\1@p'
}

#
get_ra_prefixes() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_ra_prefixes <devicename>." 1>&2
    return 1
  fi
  rdisc6 -1 $1 | grep Prefix | awk '{print $3}' |
   awk -F\n -v ORS=',' '{print}' | sed 's/,$//'
}

#
get_ra_prefix_flags() {
  if [ $# -ne 2 ]; then
    echo "ERROR: get_ra_prefix_flags <devicename> <ra_prefix>." 1>&2
    return 1
  fi
  local prefix=`echo $1 | awk -F/ '{print $2}'`
  rdisc6 -1 $1 |
   awk 'BEGIN{
     find=0;
     while (getline line) {
       if (find==1) {
         if (match(line,/'"On-link"'.*/) && match(line,/'"Yes"'.*/)) {
           print "O";
         } else if (match(line,/'"Autonomous"'.*/) && match(line,/'"Yes"'.*/)) {
           print "A";
           find=0;
         }
       } else if (match(line,/'"$prefix"'.*/)) {
         find=1;
       }
     }
   }' |
   awk -F\n -v ORS='' '{print}'
}

#
get_ra_flags() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_ra_flags <devicename>." 1>&2
    return 1
  fi
  rdisc6 -1 $1 |
   awk 'BEGIN{
     while (getline line) {
       if (match(line,/'"Stateful address"'.*/) && match(line,/'"Yes"'.*/)) {
         print "M";
       } else if (match(line,/'"Stateful other"'.*/) && match(line,/'"Yes"'.*/)) {
         print "O";
       }
     }
   }' |
   awk -F\n -v ORS='' '{print}'
}

#
check_v6autoconf() {
  if [ $# -ne 5 ]; then
    echo "ERROR: check_v6autoconf <devicename> <v6ifconf> <ra_flags> <ra_prefix> <ra_prefix_flags>." 1>&2
    return 1
  fi
  local prefix=`echo $3 | sed -n 's@\([0-9a-f:]*\)::/.*$@\1@p'`
  local v6addrs=""
  local a_flag=`echo $3 | grep A`
  local m_flag=`echo $5 | grep M`
  if [ $2 = "automatic" ]; then
#    if [ "X${a_flag}" != "X" ]; then
#     #TBD
#    fi
#    if [ "X${m_flag}" != "X" ]; then
#     #TBD
#    fi
    echo ${v6addrs} | sed 's/,$//'
    return 0
  else
    ip -6 address show $1 | sed -n '/${prefix}/s@^.*inet6 \([0-9a-f:]*\)/.*$@\1@p'
    return 9
  fi
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

#
get_v6addrs() {
  if [ $# -ne 4 ]; then
    echo "ERROR: get_v6addrs <devicename> <v6ifconf> <ra_prefix> <ra_prefix_flags>." 1>&2
    return 1
  fi
  local prefix=`echo $3 | sed -n 's@\([0-9a-f:]*\)::/.*$@\1@p'`
  local m_flag=`echo $4 | grep M`
  if [ $2 = "automatic" -a "${m_flag}" ]; then
    echo "TBD"
  else
    ip -6 address show $1 | grep inet6 | grep ${prefix} | awk '{print $2}' |
     awk -F\n -v ORS=',' '{print}' | sed 's/,$//'
#    ip -6 address show $1 | sed -n '/${prefix}/s@^.*inet6 \([0-9a-f:]*\)/.*$@\1@p' |
#     awk -F\n -v ORS=',' '{print}' | sed 's/,$//'
  fi
}

#
get_prefixlen() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_prefixlen <ra_prefix>." 1>&2
    return 1
  fi
  echo $1 | awk -F/ '{print $2}'
}

#
get_v6routers() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_v6routers <devicename>." 1>&2
    return 1
  fi
  local v6router=`ip -6 route | grep default | grep $1 | awk '{print $3}'`
  echo ${v6router}%$1
}

#
get_v6nameservers() {
  if [ $# -ne 3 ]; then
    echo "ERROR: get_v6nameservers <devicename> <v6ifconf> <ra_flags>." 1>&2
    return 1
  fi
#  local dhcpv6=`echo $3 | grep M`
#  if [ $2 = "automatic" -a "${dhcpv6}" ]; then
#    echo "TBD"
#  else
    # need for IPv6
    grep nameserver /etc/resolv.conf | awk '{print $2}' | grep : |
     awk -v ORS=' ' '1; END{printf "\n"}'
#  fi
}

## for localnet layer
#
do_ping() {
  if [ $# -ne 2 ]; then
    echo "ERROR: do_ping <version> <target_addr>." 1>&2
    return 1
  fi
  case $1 in
    "4" ) ping -i 0.2 -c 10 $2; return $? ;;
    "6" ) ping6 -i 0.2 -c 10 $2; return $? ;;
    * ) echo "ERROR: <version> must be 4 or 6." 1>&2; return 9 ;;
  esac
}

#
get_rtt() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_rtt <ping_result>." 1>&2
    return 1
  fi
  echo "$1" | grep rtt | awk '{print $4}' | sed 's/\// /g'
}

#
get_loss() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_loss <ping_result>." 1>&2
    return 1
  fi
  echo "$1" | sed -n 's/^.*received, \([0-9.]*\)\%.*$/\1/p'
}

## for globalnet layer
#
do_traceroute() {
  if [ $# -ne 2 ]; then
    echo "ERROR: do_traceroute <version> <target_addr>." 1>&2
    return 1
  fi
  case $1 in
    "4" ) traceroute -n -w 2 -q 1 -m 50 $2; return $? ;;
    "6" ) traceroute6 -n -w 2 -q 1 -m 50 $2; return $? ;;
    * ) echo "ERROR: <version> must be 4 or 6." 1>&2; return 9 ;;
  esac
}

#
get_tracepath () {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_tracepath <trace_result>." 1>&2
    return 1
  fi
  echo "$1" | grep -v traceroute | awk '{print $2}' |
   awk -F\n -v ORS=',' '{print}' | sed 's/,$//'
}

#
do_pmtud() {
  if [ $# -ne 4 ]; then
    echo "ERROR: do_pmtud <version> <target_addr> <min_mtu> <max_mtu>." 1>&2
    return 1
  fi
  local command=""
  local dfopt=""
  case $1 in
    "4" ) command=ping; dfopt="-M do" ;;
    "6" ) command=ping6 ;;
    * ) echo "ERROR: <version> must be 4 or 6." 1>&2; return 9 ;;
  esac
  ${command} -c 1 $2 > /dev/null
  if [ $? -ne 0 ]; then
    echo 0
    return 1
  fi

  local version=$1
  local target=$2
  local min=$3
  local max=$4
  local mid=`expr \( ${min} + ${max} \) / 2`
  local result=0
  if [ ${min} -eq ${mid} ] || [ ${max} -eq ${mid} ]; then
    echo ${min}
    return 0
  fi
  ${command} -c 3 -s ${mid} ${dfopt} ${target} >/dev/null 2>/dev/null
  if [ $? -eq 0 ]; then
    result=$(do_pmtud ${version} ${target} ${mid} ${max})
  else
    result=$(do_pmtud ${version} ${target} ${min} ${mid})
  fi
  echo ${result}
}

## for dns layer
#
do_dnslookup() {
  if [ $# -ne 3 ]; then
    echo "ERROR: do_dnslookup <nameserver> <query_type> <target_fqdn>." 1>&2
    return 1
  fi
  dig @$1 $3 $2 +time=1; return $?
  # Dig return codes are:
  # 0: Everything went well, including things like NXDOMAIN
  # 1: Usage error
  # 8: Couldn't open batch file
  # 9: No reply from server
  # 10: Internal error
}

#
get_dnsans() {
  if [ $# -ne 2 ]; then
    echo "ERROR: get_dnsans <query_type> <dig_result>." 1>&2
    return 1
  fi
  echo "$2" | grep -v '^$' | grep -v '^;' | grep "	$1" -m 1 | awk '{print $5}'
}

#
get_dnsttl() {
  if [ $# -ne 2 ]; then
    echo "ERROR: get_dnsttl <query_type> <dig_result>." 1>&2
    return 1
  fi
  echo "$2" | grep -v '^$' | grep -v '^;' | grep "	$1" -m 1 | awk '{print $2}'
}

#
get_dnsrtt() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_dnsrtt <dig_result>." 1>&2
    return 1
  fi
#  echo "$1" | grep "Query time" | sed -n 's/^.*time: \([0-9]*\) .*$/\1/p'
  echo "$1" | grep "Query time" | awk '{print $4}'
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
  curl -$1 --connect-timeout 5 --write-out %{http_code} --silent --output /dev/null $2
}

#
# main
#

####################
## Preparation

# Check parameters
if [ "X${LOCKFILE}" = "X" ]; then
  echo "ERROR: LOCKFILE is null at configration file." 1>&2
  return 1
fi
if [ "X${IFTYPE}" = "X" ]; then
  echo "ERROR: IFTYPE is null at configration file." 1>&2
  return 1
fi
if [ "X${DEVNAME}" = "X" ]; then
  echo "ERROR: DEVNAME is null at configration file." 1>&2
  return 1
fi

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
# Check {IFTYPE} parameter
if [ "X${IFTYPE}" = "X" ]; then
  echo "ERROR: IFTYPE is null at configration file." 1>&2
  return 1
fi
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
  pre_ssid=$(get_wifi_ssid ${devicename})
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
  sleep 10 
fi

# Check I/F status
result=${FAIL}
ifstatus=$(get_ifstatus ${devicename})
if [ $? -eq 0 ]; then
  result=${SUCCESS}
fi
if [ "X${ifstatus}" != "X" ]; then
  write_json ${layer} "common" ifstatus ${result} self ${ifstatus} 0
fi

# Get iftype
write_json ${layer} "common" iftype ${INFO} self ${IFTYPE} 0

# Get ifmtu
ifmtu=$(get_ifmtu ${devicename})
if [ "X${ifmtu}" != "X" ]; then
  write_json ${layer} "common" ifmtu ${INFO} self ${ifmtu} 0
fi

#
if [ ${IFTYPE} != "Wi-Fi" ]; then
  # Get media type
  media=$(get_mediatype ${devicename})
  if [ "X${media}" != "X" ]; then
    write_json ${layer} "${IFTYPE}" media ${INFO} self ${media} 0
  fi
else
  # Get Wi-Fi SSID
  ssid=$(get_wifi_ssid ${devicename})
  if [ "X${ssid}" != "X" ]; then
    write_json ${layer} "${IFTYPE}" ssid ${INFO} self ${ssid} 0
  fi
  # Get Wi-Fi BSSID
  bssid=$(get_wifi_bssid ${devicename})
  if [ "X${bssid}" != "X" ]; then
    write_json ${layer} "${IFTYPE}" bssid ${INFO} self ${bssid} 0
  fi
  # Get Wi-Fi channel
  channel=$(get_wifi_channel ${devicename})
  if [ "X${channel}" != "X" ]; then
    write_json ${layer} "${IFTYPE}" channel ${INFO} self ${channel} 0
  fi
  # Get Wi-Fi RSSI
  rssi=$(get_wifi_rssi ${devicename})
  if [ "X${rssi}" != "X" ]; then
    write_json ${layer} "${IFTYPE}" rssi ${INFO} self ${rssi} 0
  fi
  # Get Wi-Fi noise
  noise=$(get_wifi_noise ${devicename})
  if [ "X${noise}" != "X" ]; then
    write_json ${layer} "${IFTYPE}" noise ${INFO} self ${noise} 0
  fi
  # Get Wi-Fi rate
  rate=$(get_wifi_rate ${devicename})
  if [ "X${rate}" != "X" ]; then
    write_json ${layer} "${IFTYPE}" rate ${INFO} self ${rate} 0
  fi
fi

# Report phase 1 results
if [ "${VERBOSE}" = "yes" ]; then
  echo " datalink information:"
  echo "  type: ${IFTYPE}, dev: ${devicename}"
  echo "  status: ${ifstatus}, mtu: ${ifmtu} MB"
  if [ "${IFTYPE}" != "Wi-Fi" ]; then
    echo "  media: ${media}"
  else
    echo "  ssid: ${ssid}, ch: ${channel}, rate: ${rate} Mbps"
    echo "  bssid: ${bssid}"
    echo "  rssi: ${rssi} dB, noise: ${noise} dB"
  fi
fi

echo " done."
sleep 10

####################
## Phase 2
echo "Phase 2: Interface Layer checking..."
layer="interface"

## IPv4
# Get IPv4 I/F configurations
v4ifconf=$(get_v4ifconf "${devicename}")
if [ "X${v4ifconf}" != "X" ]; then
  write_json ${layer} IPv4 v4ifconf ${INFO} self ${v4ifconf} 0
fi

# Check IPv4 autoconf
result=${FAIL}
v4autoconf=$(check_v4autoconf ${devicename} ${v4ifconf})
if [ $? -eq 0 -a "X${v4autoconf}" != "X" ]; then
  result=${SUCCESS}
fi
write_json ${layer} IPv4 v4autoconf ${result} self "${v4autoconf}" 0

# Get IPv4 address
v4addr=$(get_v4addr ${devicename} ${v4ifconf})
if [ "X${v4addr}" != "X" ]; then
  write_json ${layer} IPv4 v4addr ${INFO} self ${v4addr} 0
fi

# Get IPv4 netmask
netmask=$(get_netmask ${devicename} ${v4ifconf})
if [ "X${netmask}" != "X" ]; then
  write_json ${layer} IPv4 netmask ${INFO} self ${netmask} 0
fi

# Get IPv4 routers
v4routers=$(get_v4routers ${devicename} ${v4ifconf})
if [ "X${v4routers}" != "X" ]; then
  write_json ${layer} IPv4 v4routers ${INFO} self "${v4routers}" 0
fi

# Get IPv4 name servers
v4nameservers=$(get_v4nameservers ${devicename} ${v4ifconf})
if [ "X${v4nameservers}" != "X" ]; then
  write_json ${layer} IPv4 v4nameservers ${INFO} self "${v4nameservers}" 0
fi

# Get IPv4 NTP servers
#TBD

# Report phase 2 results (IPv4)
if [ "${VERBOSE}" = "yes" ]; then
  echo " interface information:"
  echo "  IPv4 conf: ${v4ifconf}"
  echo "  IPv4 addr: ${v4addr}/${netmask}"
  echo "  IPv4 router: ${v4routers}"
  echo "  IPv4 namesrv: ${v4nameservers}"
fi

## IPv6
# Get IPv6 I/F configurations
v6ifconf=$(get_v6ifconf "${devicename}")
if [ "X${v6ifconf}" != "X" ]; then
  write_json ${layer} IPv6 v6ifconf ${INFO} self ${v6ifconf} 0
fi

# Get IPv6 linklocal address
v6lladdr=$(get_v6lladdr ${devicename})
if [ "X${v6lladdr}" != "X" ]; then
  write_json ${layer} IPv6 v6lladdr ${INFO} self ${v6lladdr} 0
fi

# Get IPv6 RA flags
ra_flags=$(get_ra_flags ${devicename})
if [ "X${ra_flags}" != "X" ]; then
  write_json ${layer} RA ra_flags ${INFO} self ${ra_flags} 0
fi

# Get IPv6 RA prefix
ra_prefixes=$(get_ra_prefixes ${devicename})
if [ "X${ra_prefixes}" != "X" ]; then
  write_json ${layer} RA ra_prefixes ${INFO} self ${ra_prefixes} 0
fi

# Report phase 2 results (IPv6)
if [ "${VERBOSE}" = "yes" ]; then
  echo "  IPv6 conf: ${v6ifconf}"
  echo "  IPv6 lladdr: ${v6lladdr}"
fi

if [ "X${ra_flags}" != "X" -o "X${ra_prefixes}" != "X" ]; then
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

    # Get IPv6 address
    v6addrs=$(get_v6addrs ${devicename} ${v6ifconf} ${pref} ${ra_prefix_flags})
    write_json ${layer} IPv6 v6addrs ${INFO} ${pref} "${v6addrs}" ${count}
    if [ "${VERBOSE}" = "yes" ]; then
      for addr in `echo ${v6addrs} | sed 's/,/ /g'`; do
        echo "   IPv6 addr: ${addr}"
      done
    fi
    count=`expr $count + 1`
  done

  # Check IPv6 autoconf
  result=${FAIL}
  if [ ${v6ifconf} = "automatic" -a "X${v6addrs}" != "X" ]; then
    result=${SUCCESS}
  fi
  write_json ${layer} IPv6 v6autoconf ${result} self "${v6addrs}" 0

  # Get IPv6 routers
  v6routers=$(get_v6routers ${devicename})
  if [ "X${v6routers}" != "X" ]; then
    write_json ${layer} IPv6 v6routers ${INFO} self "${v6routers}" 0
  fi
  if [ "${VERBOSE}" = "yes" ]; then
    echo "  IPv6 routers: ${v6routers}"
  fi

  # Get IPv6 name servers
  v6nameservers=$(get_v6nameservers ${devicename} ${v6ifconf} ${ra_flags})
  if [ "X${v6nameservers}" != "X" ]; then
    write_json ${layer} IPv6 v6nameservers ${INFO} self "${v6nameservers}" 0
  fi
  if [ "${VERBOSE}" = "yes" ]; then
    echo "  IPv6 nameservers: ${v6nameservers}"
  fi

  # Get IPv6 NTP servers
  #TBD
else
  if [ "${VERBOSE}" = "yes" ]; then
    echo "   RA does not exist."
  fi
fi

echo " done."
sleep 2

####################
## Phase 3
echo "Phase 3: Localnet Layer checking..."
layer="localnet"

#
cmdset_ping() {
  if [ $# -ne 3 ]; then
    echo "ERROR: cmdset_ping <version> <target_type> <target_addrs>." 1>&2
    return 1
  fi
  local count=0
  local ver=$1
  local ipv="IPv${ver}"
  local type=$2
  local targets=$3
  local rtt_type=(min ave max dev)
  local ping_result=""
  for target in `echo ${targets} | sed 's/,/ /g'`; do
    local result=${FAIL}
    if [ "${VERBOSE}" = "yes" ]; then
      echo " ping to ${ipv} ${type}: ${target}"
    fi
    ping_result=$(do_ping ${ver} ${target})
    if [ $? -eq 0 ]; then
      result=${SUCCESS}
    fi
    write_json ${layer} ${ipv} v${ver}alive_${type} ${result} ${target} "${ping_result}" ${count}
    if [ ${result} = ${SUCCESS} ]; then
      local rtt_data=($(get_rtt "${ping_result}"))
      for i in 0 1 2 3; do
        write_json ${layer} ${ipv} "v${ver}rtt_${type}_${rtt_type[$i]}" ${INFO} ${target} "${rtt_data[$i]}" ${count}
      done
      local rtt_loss=$(get_loss "${ping_result}")
      write_json ${layer} ${ipv} v${ver}loss_${type} ${INFO} ${target} ${rtt_loss} ${count}
      if [ "${VERBOSE}" = "yes" ]; then
        echo "  status: ok, rtt: ${rtt_data[1]} msec, loss: ${rtt_loss} %"
      fi
    else
      if [ "${VERBOSE}" = "yes" ]; then
        echo "  status: ng"
      fi
    fi
    count=`expr $count + 1`
  done
}

# Do ping to IPv4 routers
cmdset_ping 4 router "${v4routers}"

# Do ping to IPv4 nameservers
cmdset_ping 4 namesrv "${v4nameservers}"

# Do ping to IPv6 routers
cmdset_ping 6 router "${v6routers}"

# Do ping to IPv6 nameservers
cmdset_ping 6 namesrv "${v6nameservers}"

echo " done."
sleep 2

####################
## Phase 4
echo "Phase 4: Globalnet Layer checking..."
layer="globalnet"

#
cmdset_trace () {
  if [ $# -ne 3 ]; then
    echo "ERROR: cmdset_trace <version> <target_type> <target_addrs>." 1>&2
    return 1
  fi
  local count=0
  local ver=$1
  local ipv="IPv${ver}"
  local type=$2
  local targets=$3
  local path_result
  for target in `echo ${targets} | sed 's/,/ /g'`; do
    local result=${FAIL}
    if [ "${VERBOSE}" = "yes" ]; then
      echo " traceroute to ${ipv} server: ${target}"
    fi
    path_result=$(do_traceroute ${ver} ${target})
    if [ $? -eq 0 ]; then
      result=${SUCCESS}
    fi
    write_json ${layer} ${ipv} v${ver}path_detail_${type} ${INFO} ${target} "${path_result}" ${count}
    if [ ${result} = ${SUCCESS} ]; then
      local path_data=$(get_tracepath "${path_result}")
      write_json ${layer} ${ipv} v${ver}path_${type} ${INFO} ${target} ${path_data} ${count}
      if [ "${VERBOSE}" = "yes" ]; then
        echo "  path: ${path_data}"
      fi
    else
      if [ "${VERBOSE}" = "yes" ]; then
        echo "  status: ng"
      fi
    fi
    count=`expr $count + 1`
  done
}

#
cmdset_pmtud () {
  if [ $# -ne 3 ]; then
    echo "ERROR: cmdset_pmtud <version> <target_type> <target_addrs>." 1>&2
    return 1
  fi
  local count=0
  local ver=$1
  local ipv="IPv${ver}"
  local type=$2
  local targets=$3
  local pmtu_result=""
  for target in `echo ${targets} | sed 's/,/ /g'`; do
    if [ "${VERBOSE}" = "yes" ]; then
      echo " pmtud to IPv4 server: ${target}"
    fi
    pmtu_result=$(do_pmtud ${ver} ${target} 1470 1500)
    if [ ${pmtu_result} -eq 0 ]; then
      write_json ${layer} ${ipv} v${ver}pmtu_${type} ${INFO} ${target} unmeasurable ${count}
      if [ "${VERBOSE}" = "yes" ]; then
        echo "  pmtud: unmeasurable"
      fi
    else
      local pmtu_data=`expr ${pmtu_result} + 28`
      write_json ${layer} ${ipv} v${ver}pmtu_${type} ${INFO} ${target} ${pmtu_data} ${count}
      if [ "${VERBOSE}" = "yes" ]; then
        echo "  pmtu: ${pmtu_data} MB"
      fi
    fi
    count=`expr $count + 1`
  done
}

# Check PING_SRVS parameter
if [ "X${PING_SRVS}" = "X" ]; then
  echo "ERROR: PING_SRVS is null at configration file." 1>&2
  return 1
fi

v4addr_type=$(check_v4addr ${v4addr})
if [ "${v4addr_type}" != "loopback" -a "${v4addr_type}" != "linklocal" ]; then
  # Do ping to extarnal IPv4 servers
  cmdset_ping 4 srv "${PING_SRVS}"
  
  # Do traceroute to extarnal IPv4 servers
  cmdset_trace 4 srv "${PING_SRVS}"
  
  # Check path MTU to extarnal IPv4 servers
  cmdset_pmtud 4 srv "${PING_SRVS}"
fi

# Check PING6_SRVS parameter
if [ "X${PING6_SRVS}" = "X" ]; then
  echo "ERROR: PING6_SRVS is null at configration file." 1>&2
  return 1
fi

if [ "X${v6addrs}" != "X" ]; then
  # Do ping to extarnal IPv6 servers
  cmdset_ping 6 srv "${PING6_SRVS}"
  
  # Do traceroute to extarnal IPv6 servers
  cmdset_trace 6 srv "${PING6_SRVS}"
  
  # Check path MTU to extarnal IPv6 servers
  cmdset_pmtud 6 srv "${PING6_SRVS}"
fi

echo " done."
sleep 2

####################
## Phase 5
echo "Phase 5: DNS Layer checking..."
layer="dns"

#
cmdset_dnslookup () {
  if [ $# -ne 3 ]; then
    echo "ERROR: cmdset_dnslookup <version> <target_type> <target_addrs>." 1>&2
    return 1
  fi
  local count=0
  local ver=$1
  local ipv="IPv${ver}"
  local type=$2
  local targets=$3
  local dns_result=""
  for target in `echo ${targets} | sed 's/,/ /g'`; do
    if [ "${VERBOSE}" = "yes" ]; then
      echo " dns lookup for ${type} record by ${ipv} nameserver: ${target}"
    fi
    for fqdn in `echo ${FQDNS} | sed 's/,/ /g'`; do
      local result=${FAIL}
      if [ "${VERBOSE}" = "yes" ]; then
        echo "  resolve server: ${fqdn}"
      fi
      dns_result=$(do_dnslookup ${target} ${type} ${fqdn})
      if [ $? -eq 0 ]; then
        result=${SUCCESS}
      else
        local stat=$?
      fi
      write_json ${layer} ${ipv} v${ver}dnsqry_${type}_${fqdn} ${result} ${target} "${dns_result}" ${count}
      if [ ${result} = ${SUCCESS} ]; then
        local dns_ans=$(get_dnsans ${type} "${dns_result}")
        write_json ${layer} ${ipv} v${ver}dnsans_${type}_${fqdn} ${INFO} ${target} "${dns_ans}" ${count}
        local dns_ttl=$(get_dnsttl ${type} "${dns_result}")
        write_json ${layer} ${ipv} v${ver}dnsttl_${type}_${fqdn} ${INFO} ${target} "${dns_ttl}" ${count}
        local dns_rtt=$(get_dnsrtt "${dns_result}")
        write_json ${layer} ${ipv} v${ver}dnsrtt_${type}_${fqdn} ${INFO} ${target} "${dns_rtt}" ${count}
        if [ "${VERBOSE}" = "yes" ]; then
          echo "   status: ok, result(ttl): ${dns_ans}(${dns_ttl} s), query time: ${dns_rtt} ms"
        fi
      else
        if [ "${VERBOSE}" = "yes" ]; then
          echo "   status: ng ($stat)"
        fi
      fi
      count=`expr $count + 1`
    done
    # Check DNS64
    if [ ${ver} = "6" -a ${type} = "AAAA" ]; then
      local dns64_result=$(do_dnslookup ${target} ${type} "ipv4only.arpa")
      local check_dns64=$(get_dnsans ${type} "${dns64_result}")
      if [ "X${check_dns64}" != "X" ]; then
        exist_dns64="yes"
      fi
    fi
  done
}

# Clear dns local cache
#TBD

# Check FQDNS parameter
if [ "X${FQDNS}" = "X" ]; then
  echo "ERROR: FQDNS is null at configration file." 1>&2
  return 1
fi

if [ "${v4addr_type}" != "loopback" -a "${v4addr_type}" != "linklocal" ]; then
  # Do dns lookup for A record by IPv4
  cmdset_dnslookup 4 A "${v4nameservers}"

  # Do dns lookup for AAAA record by IPv4
  cmdset_dnslookup 4 AAAA "${v4nameservers}"
fi

exist_dns64="no"
if [ "X${v6addrs}" != "X" ]; then
  # Do dns lookup for A record by IPv6
  cmdset_dnslookup 6 A "${v6nameservers}"

  # Do dns lookup for AAAA record by IPv6
  cmdset_dnslookup 6 AAAA "${v6nameservers}"
fi

# Check GPDNS[4|6] parameter
if [ "X${GPDNS4}" = "X" ]; then
  echo "ERROR: GPDNS4 is null at configration file." 1>&2
  return 1
fi
if [ "X${GPDNS6}" = "X" ]; then
  echo "ERROR: GPDNS6 is null at configration file." 1>&2
  return 1
fi

if [ "${v4addr_type}" != "loopback" -a "${v4addr_type}" != "linklocal" ]; then
  # Do dns lookup for A record by GPDNS4
  cmdset_dnslookup 4 A "${GPDNS4}"

  # Do dns lookup for AAAA record by GPDNS4
  cmdset_dnslookup 4 AAAA "${GPDNS4}"
fi

if [ "X${v6addrs}" != "X" ]; then
  # Do dns lookup for A record by GPDNS6
  cmdset_dnslookup 6 A "${GPDNS6}"

  # Do dns lookup for AAAA record by GPDNS6
  cmdset_dnslookup 6 AAAA "${GPDNS6}"
fi

echo " done."
sleep 2

####################
## Phase 6
echo "Phase 6: Web Layer checking..."
layer="web"

cmdset_http () {
  if [ $# -ne 3 ]; then
    echo "ERROR: cmdset_http <version> <target_type> <target_addrs>." 1>&2
    return 1
  fi
  local count=0
  local ver=$1
  local ipv="IPv${ver}"
  local type=$2
  local targets=$3
  local http_ans=""
  for target in `echo ${targets} | sed 's/,/ /g'`; do
    local result=${FAIL}
    if [ "${VERBOSE}" = "yes" ]; then
      echo " curl to extarnal server: ${target} by ${ipv}"
    fi
    http_ans=$(do_curl ${ver} ${target})
    if [ $? -eq 0 ]; then
      result=${SUCCESS}
    else
      stat=$?
    fi
    write_json ${layer} ${ipv} v${ver}http_${type} ${result} ${target} "${http_ans}" ${count}
    if [ "${VERBOSE}" = "yes" ]; then
      if [ ${result} = ${SUCCESS} ]; then
        echo "  status: ok, http status code: ${http_ans}"
      else
        echo "  status: ng ($stat)"
      fi
    fi
    count=`expr $count + 1`
  done
}

# Check V4WEB_SRVS parameter
if [ "X${V4WEB_SRVS}" = "X" ]; then
  echo "ERROR: V4WEB_SRVS is null at configration file." 1>&2
  return 1
fi

if [ "${v4addr_type}" != "loopback" -a "${v4addr_type}" != "linklocal" ]; then
  # Do curl to IPv4 web servers by IPv4
  cmdset_http 4 srv "${V4WEB_SRVS}"

  # Do measure http throuput by IPv4
  #TBD
  # v4http_throughput_srv
fi

# Check V6WEB_SRVS parameter
if [ "X${V6WEB_SRVS}" = "X" ]; then
  echo "ERROR: V6WEB_SRVS is null at configration file." 1>&2
  return 1
fi

if [ "X${v6addrs}" != "X" ]; then
  # Do curl to IPv6 web servers by IPv6
  cmdset_http 6 srv "${V6WEB_SRVS}"

  # Do measure http throuput by IPv6
  #TBD
  # v6http_throughput_srv
fi

# DNS64
if [ ${exist_dns64} = "yes" ]; then
  echo " exist dns64 server"
  # Do curl to IPv4 web servers by IPv6
  cmdset_http 6 srv "${V4WEB_SRVS}"

  # Do measure http throuput by IPv6
  #TBD
  # v6http_throughput_srv
fi

echo " done."
sleep 2

####################
## Phase 7
echo "Phase 7: Create campaign log..."

# Write campaign log file
ssid=WIRED
if [ ${IFTYPE} = "Wi-Fi" ]; then
  ssid=$(get_wifi_ssid ${devicename})
fi
write_json_campaign ${uuid} ${mac_addr} "${os}" ${ssid}

# remove lock file
rm -f ${LOCKFILE}

echo " done."

exit 0
