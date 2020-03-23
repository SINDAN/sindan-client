#!/bin/bash
# sindan.sh
# version 2.1.0
VERSION="2.1.0"

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
get_devicename() {
  echo ${DEVNAME}
  return $?
}

#
do_ifdown() {
  if [ $# -ne 1 ]; then
    echo "ERROR: do_ifdown <devicename>." 1>&2
    return 1
  fi
  ifdown $1
  return $?
}

#
do_ifup() {
  if [ $# -ne 1 ]; then
    echo "ERROR: do_ifup <devicename>." 1>&2
    return 1
  fi
  ifup $1
  return $?
}

#
get_os() {
  which lsb_release > /dev/null 2>&1
  if [ $? -eq 0 ]; then
    lsb_release -ds
  else
    grep PRETTY_NAME /etc/*-release					|
    awk -F\" '{print $2}'
  fi
  return $?
}

#
get_ifstatus() {
  (
  if [ $# -ne 1 ]; then
    echo "ERROR: get_ifstatus <devicename>." 1>&2
    return 1
  fi
  status=`cat /sys/class/net/$1/operstate`
  if [ "${status}" = "up" ]; then
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
  cat /sys/class/net/$1/mtu
  return $?
}

#
get_macaddr() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_macaddr <devicename>." 1>&2
    return 1
  fi
  cat /sys/class/net/$1/address						|
  tr "[:upper:]" "[:lower:]"
  return $?
}

#
get_mediatype() {
  (
  if [ $# -ne 1 ]; then
    echo "ERROR: get_mediatype <devicename>." 1>&2
    return 1
  fi
  speed=`cat /sys/class/net/$1/speed`
  duplex=`cat /sys/class/net/$1/duplex`
  echo ${speed}_${duplex}
  return $?
  )
}

#
get_wifi_ssid() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_wifi_ssid <devicename>." 1>&2
    return 1
  fi
  iwgetid $1 --raw
  return $?
}

#
get_wifi_bssid() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_wifi_bssid <devicename>." 1>&2
    return 1
  fi
  iwgetid $1 --raw --ap							|
  tr "[:upper:]" "[:lower:]"
  return $?
}

#
get_wifi_channel() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_wifi_channel <devicename>." 1>&2
    return 1
  fi
  iwgetid $1 --raw --channel
  return $?
}

#
get_wifi_rssi() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_wifi_rssi <devicename>." 1>&2
    return 1
  fi
  grep $1 /proc/net/wireless						|
  awk '{print $4}'
  return $?
}

#
get_wifi_noise() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_wifi_noise <devicename>." 1>&2
    return 1
  fi
  grep $1 /proc/net/wireless						|
  awk '{print $5}'
  return $?
}

#
get_wifi_quality() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_wifi_quality <devicename>." 1>&2
    return 1
  fi
  iwconfig $1								|
  sed -n 's/^.*Link Quality=\([0-9\/]*\).*$/\1/p'
  return $?
}

#
get_wifi_rate() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_wifi_rate <devicename>." 1>&2
    return 1
  fi
  iwconfig $1								|
  sed -n 's/^.*Bit Rate=\([0-9.]*\) Mb\/s.*$/\1/p'
  return $?
}

#
get_wifi_environment() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_wifi_environment <devicename>." 1>&2
    return 1
  fi
  echo "BSSID,Protocol,SSID,Quality,RSSI,Noise,BitRates"
  iwlist $1 scanning							|
  awk 'BEGIN{								#
    find=0;								#
    while (getline line) {						#
      if (find==1) {							#
        if (match(line,/Protocol:.*/)) {				#
          split(line,a,":");						#
          printf ",%s", a[2];						#
        } else if (match(line,/ESSID:.*/)) {				#
          split(line,a,"\"");						#
          printf ",%s", a[2];						#
        } else if (match(line,/Channel [0-9]*/)) {			#
          split(substr(line,RSTART,RLENGTH),a," ");			#
          printf ",%s", a[2];						#
        } else if (match(line,/Quality=.*/)) {				#
          gsub(/=/," ",line);						#
          split(line,a," ");						#
          printf ",%s,%s,%s", a[2], a[5], a[9];				#
        } else if (match(line,/Rates:[0-9.]* /)) {			#
          split(substr(line,RSTART,RLENGTH),a,":");			#
          printf ",%s\n", a[2];						#
          find=0;							#
        }								#
      } else if (match(line,/Address:.*/)) {				#
        split(substr(line,RSTART,RLENGTH),a," ");			#
        printf "%s", tolower(a[2]);					#
        find=1;								#
      }									#
    }									#
  }'
  return $?
}

## for interface layer
#
get_v4ifconf() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_v4ifconf <devicename>."
    return 1
  fi
  if [ -f /etc/dhcpcd.conf ]; then
    grep "^interface $1" /etc/dhcpcd.conf > /dev/null 2>&1
    if [ $? -eq 0 ]; then
      echo "manual"
    else
      echo "dhcp"
    fi
  else
    grep "^iface $1 inet" /etc/network/interfaces			|
    awk '{print $4}'
  fi
  return $?
}

#
check_v4autoconf() {
  (
  if [ $# -ne 2 ]; then
    echo "ERROR: check_v4autoconf <devicename> <v4ifconf>." 1>&2
    return 1
  fi
  if [ $2 = "dhcp" ]; then
    v4addr=$(get_v4addr $1)
    dhcp_data=""
    which dhcpcd > /dev/null 2>&1
    if [ $? -eq 0 ]; then
      dhcp_data=`dhcpcd -4 -U $1 | sed "s/'//g"`
    else
      dhcp_data=`cat /var/lib/dhcp/dhclient.$1.leases | sed 's/"//g'`
    fi
    echo "${dhcp_data}"

    # simple comparision
    dhcpv4addr=`echo "${dhcp_data}"                                     |
                sed -n 's/^ip_address=\([0-9.]*\)/\1/p'`
    if [ -z "${dhcpv4addr}" -o -z "${v4addr}" ]; then
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
  return 0
  )
}

#
get_v4addr() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_v4addr <devicename>." 1>&2
    return 1
  fi
  ip -4 addr show $1							|
  sed -n 's/^.*inet \([0-9.]*\)\/.*$/\1/p'
  return $?
}

#
get_netmask() {
  (
  if [ $# -ne 1 ]; then
    echo "ERROR: get_netmask <devicename>." 1>&2
    return 1
  fi
  preflen=`ip -4 addr show $1 | sed -n 's/^.*inet [0-9.]*\/\([0-9]*\) .*$/\1/p'`
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
  return $?
  )
}

#
get_v4routers() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_v4routers <devicename>." 1>&2
    return 1
  fi
  ip -4 route show dev $1						|
  sed -n 's/^default via \([0-9.]*\).*$/\1/p'
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
  (
  if [ $# -ne 1 ]; then
    echo "ERROR: get_v6ifconf <devicename>." 1>&2
    return 1
  fi
  v6ifconf=`grep "$1 inet6" /etc/network/interfaces | awk '{print $4}'`
  if [ -n "${v6ifconf}" ]; then
    cat ${v6ifconf}
  else
    echo "automatic"
  fi
  return $?
  )
}

#
get_v6lladdr() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_v6lladdr <devicename>." 1>&2
    return 1
  fi
  ip -6 addr show $1 scope link						|
  sed -n 's/^.*inet6 \(fe80[0-9a-f:]*\)\/.*$/\1/p'
  return $?
}

#
get_ra_info() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_ra_info <devicename>." 1>&2
    return 1
  fi
  rdisc6 -n $1
  return $?
}

#
get_ra_addrs() {
  grep "^ from"                                                         |
  awk '{print $2}'                                                      |
  awk -F\n -v ORS=',' '{print}'                                         |
  sed 's/,$//'
  return $?
}

#
get_ra_flags() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_ra_flags <ra_source>." 1>&2
    return 1
  fi
  awk -v src=$1 'BEGIN {                                                #
    flags=""                                                            #
  } {                                                                   #
    while (getline line) {                                              #
      if (match(line,/^Stateful address conf./)                         \
          && match(line,/Yes/)) {                                       #
        flags=flags "M"                                                 #
      } else if (match(line,/^Stateful other conf./)                    \
                 && match(line,/Yes/)) {                                #
        flags=flags "O"                                                 #
      } else if (match(line,/^Mobile home agent/)                       \
                 && match(line,/Yes/)) {                                #
        flags=flags "H"                                                 #
      } else if (match(line,/^Router preference/)) {                    #
        if (match(line,/low/)) {                                        #
          flags=flags "l"                                               #
        } else if (match(line,/medium/)) {                              #
          flags=flags "m"                                               #
        } else if (match(line,/high/)) {                                #
          flags=flags "h"                                               #
        }                                                               #
      } else if (match(line,/^Neighbor discovery proxy/)                \
                 && match(line,/Yes/)) {                                #
        flags=flags "P"                                                 #
      } else if (match(line,/^ from.*/)) {                              #
        if (line ~ src) {                                               #
          exit                                                          #
        } else {                                                        #
          flags=""                                                      #
        }                                                               #
      }                                                                 #
    }                                                                   #
  } END {                                                               #
    printf "%s", flags                                                  #
  }'
  return $?
}

#
get_ra_hoplimit() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_ra_hoplimit <ra_source>." 1>&2
    return 1
  fi
  awk -v src=$1 'BEGIN {                                                #
    hops=""                                                             #
  } {                                                                   #
    while (getline line) {                                              #
      if (match(line,/^Hop limit/)) {                                   #
        split(line,h," ")                                               #
        hops=h[4]                                                       #
      } else if (match(line,/^ from.*/)) {                              #
        if (line ~ src) {                                               #
          exit                                                          #
        } else {                                                        #
          hops=""                                                       #
        }                                                               #
      }                                                                 #
    }                                                                   #
  } END {                                                               #
    printf "%s", hops                                                   #
  }'
  return $?
}

#
get_ra_lifetime() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_ra_lifetime <ra_source>." 1>&2
    return 1
  fi
  awk -v src=$1 'BEGIN {                                                #
    time=""                                                             #
  } {                                                                   #
    while (getline line) {                                              #
      if (match(line,/^Router lifetime/)) {                             #
        split(line,t," ")                                               #
        time=t[4]                                                       #
      } else if (match(line,/^ from.*/)) {                              #
        if (line ~ src) {                                               #
          exit                                                          #
        } else {                                                        #
          time=""                                                       #
        }                                                               #
      }                                                                 #
    }                                                                   #
  } END {                                                               #
    printf "%s", time                                                   #
  }'
  return $?
}

#
get_ra_reachable() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_ra_reachable <ra_source>." 1>&2
    return 1
  fi
  awk -v src=$1 'BEGIN {                                                #
    time=""                                                             #
  } {                                                                   #
    while (getline line) {                                              #
      if (match(line,/^Reachable time/)) {                              #
        split(line,t," ")                                               #
        time=t[4]                                                       #
      } else if (match(line,/^ from.*/)) {                              #
        if (line ~ src) {                                               #
          exit                                                          #
        } else {                                                        #
          time=""                                                       #
        }                                                               #
      }                                                                 #
    }                                                                   #
  } END {                                                               #
    printf "%s", time                                                   #
  }'
  return $?
}

#
get_ra_retransmit() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_ra_retransmit <ra_source>." 1>&2
    return 1
  fi
  awk -v src=$1 'BEGIN {                                                #
    time=""                                                             #
  } {                                                                   #
    while (getline line) {                                              #
      if (match(line,/^Retransmit time/)) {                             #
        split(line,t," ")                                               #
        time=t[4]                                                       #
      } else if (match(line,/^ from.*/)) {                              #
        if (line ~ src) {                                               #
          exit                                                          #
        } else {                                                        #
          time=""                                                       #
        }                                                               #
      }                                                                 #
    }                                                                   #
  } END {                                                               #
    printf "%s", time                                                   #
  }'
  return $?
}

#
get_ra_prefs() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_ra_prefs <ra_source>." 1>&2
    return 1
  fi
  awk -v src=$1 'BEGIN {                                                #
    prefs=""                                                            #
  } {                                                                   #
    while (getline line) {                                              #
      if (match(line,/^ Prefix/)) {                                     #
        split(line,p," ")                                               #
        prefs=prefs ","p[3]                                             #
      } else if (match(line,/^ from.*/)) {                              #
        if (line ~ src) {                                               #
          exit                                                          #
        } else {                                                        #
          prefs=""                                                      #
        }                                                               #
      }                                                                 #
    }                                                                   #
  } END {                                                               #
    printf "%s", prefs                                                  #
  }'                                                                    |
  sed 's/^,//'
  return $?
}

#
get_ra_pref_flags() {
  if [ $# -ne 2 ]; then
    echo "ERROR: get_ra_pref_flags <ra_source> <ra_pref>." 1>&2
    return 1
  fi
  awk -v src=$1 -v pref=$2 'BEGIN {                                     #
    find=0                                                              #
    flags=""                                                            #
    split(pref,p,"/")                                                   #
  } {                                                                   #
    while (getline line) {                                              #
      if (find==1) {                                                    #
        if (match(line,/^  On-link/) && match(line,/Yes/)) {            #
          flags=flags "L"                                               #
        } else if (match(line,/^  Autonomous address conf./)            \
                   && match(line,/Yes/)) {                              #
          flags=flags "A"                                               #
        } else if (match(line,/^  Pref. time/)) {                       #
          find=0                                                        #
        }                                                               #
      } else if (match(line,/^ Prefix/) && line ~ p[1]) {               #
        find=1                                                          #
      } else if (match(line,/^ from.*/)) {                              #
        if (line ~ src) {                                               #
          exit                                                          #
        } else {                                                        #
          flags=""                                                      #
        }                                                               #
      }                                                                 #
    }                                                                   #
  } END {                                                               #
    printf "%s", flags                                                  #
  }'
  return $?
}

#
get_ra_pref_valid() {
  if [ $# -ne 2 ]; then
    echo "ERROR: get_ra_pref_valid <ra_source> <ra_pref>." 1>&2
    return 1
  fi
  awk -v src=$1 -v pref=$2 'BEGIN {                                     #
    find=0                                                              #
    time=""                                                             #
    split(pref,p,"/")                                                   #
  } {                                                                   #
    while (getline line) {                                              #
      if (find==1) {                                                    #
        if (match(line,/^  Valid time/)) {                              #
          split(line,t," ")                                             #
          time=t[4]                                                     #
          find=0                                                        #
        }                                                               #
      } else if (match(line,/^ Prefix/) && line ~ p[1]) {               #
        find=1                                                          #
      } else if (match(line,/^ from.*/)) {                              #
        if (line ~ src) {                                               #
          exit                                                          #
        } else {                                                        #
          flags=""                                                      #
        }                                                               #
      }                                                                 #
    }                                                                   #
  } END {                                                               #
    printf "%s", time                                                   #
  }'
  return $?
}

#
get_ra_pref_preferred() {
  if [ $# -ne 2 ]; then
    echo "ERROR: get_ra_pref_preferred <ra_source> <ra_pref>." 1>&2
    return 1
  fi
  awk -v src=$1 -v pref=$2 'BEGIN {                                     #
    find=0                                                              #
    time=""                                                             #
    split(pref,p,"/")                                                   #
  } {                                                                   #
    while (getline line) {                                              #
      if (find==1) {                                                    #
        if (match(line,/^  Pref. time/)) {                              #
          split(line,t," ")                                             #
          time=t[4]                                                     #
          find=0                                                        #
        }                                                               #
      } else if (match(line,/^ Prefix/) && line ~ p[1]) {               #
        find=1                                                          #
      } else if (match(line,/^ from.*/)) {                              #
        if (line ~ src) {                                               #
          exit                                                          #
        } else {                                                        #
          flags=""                                                      #
        }                                                               #
      }                                                                 #
    }                                                                   #
  } END {                                                               #
    printf "%s", time                                                   #
  }'
  return $?
}

#
get_ra_routes() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_ra_routes <ra_source>." 1>&2
    return 1
  fi
  awk -v src=$1 'BEGIN {                                                #
    routes=""                                                           #
  } {                                                                   #
    while (getline line) {                                              #
      if (match(line,/^ Route/)) {                                      #
        split(line,r," ")                                               #
        routes=routes ","r[3]                                           #
      } else if (match(line,/^ from.*/)) {                              #
        if (line ~ src) {                                               #
          exit                                                          #
        } else {                                                        #
          routes=""                                                     #
        }                                                               #
      }                                                                 #
    }                                                                   #
  } END {                                                               #
    printf "%s", routes                                                 #
  }'                                                                    |
  sed 's/^,//'
  return $?
}

#
get_ra_route_flag() {
  if [ $# -ne 2 ]; then
    echo "ERROR: get_ra_route_flag <ra_source> <ra_route>." 1>&2
    return 1
  fi
  awk -v src=$1 -v route=$2 'BEGIN {                                    #
    find=0                                                              #
    flag=""                                                             #
    split(route,r,"/")                                                  #
  } {                                                                   #
    while (getline line) {                                              #
      if (find==1) {                                                    #
        if (match(line,/^  Route preference/)) {                        #
          split(line,p," ")                                             #
          flag=p[4]                                                     #
          find=0                                                        #
        }                                                               #
      } else if (match(line,/^ Route/) && line ~ r[1]) {                #
        find=1                                                          #
      } else if (match(line,/^ from.*/)) {                              #
        if (line ~ src) {                                               #
          exit                                                          #
        } else {                                                        #
          flag=""                                                       #
        }                                                               #
      }                                                                 #
    }                                                                   #
  } END {                                                               #
    printf "%s", flag                                                   #
  }'
  return $?
}

#
get_ra_route_lifetime() {
  if [ $# -ne 2 ]; then
    echo "ERROR: get_ra_route_flag <ra_source> <ra_route>." 1>&2
    return 1
  fi
  awk -v src=$1 -v route=$2 'BEGIN {                                    #
    find=0                                                              #
    time=""                                                             #
    split(route,r,"/")                                                  #
  } {                                                                   #
    while (getline line) {                                              #
      if (find==1) {                                                    #
        if (match(line,/^  Route lifetime/)) {                          #
          split(line,t," ")                                             #
          time=t[4]                                                     #
          find=0                                                        #
        }                                                               #
      } else if (match(line,/^ Route/) && line ~ r[1]) {                #
        find=1                                                          #
      } else if (match(line,/^ from.*/)) {                              #
        if (line ~ src) {                                               #
          exit                                                          #
        } else {                                                        #
          time=""                                                       #
        }                                                               #
      }                                                                 #
    }                                                                   #
  } END {                                                               #
    printf "%s", time                                                   #
  }'
  return $?
}

#
get_ra_rdnsses() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_ra_rdnsses <ra_source>." 1>&2
    return 1
  fi
  awk -v src=$1 'BEGIN {                                                #
    rdnsses=""                                                          #
  } {                                                                   #
    while (getline line) {                                              #
      if (match(line,/^ Recursive DNS server/)) {                       #
        split(line,r," ")                                               #
        rdnsses=rdnsses ","r[5]                                         #
      } else if (match(line,/^ from.*/)) {                              #
        if (line ~ src) {                                               #
          exit                                                          #
        } else {                                                        #
          rdnsses=""                                                    #
        }                                                               #
      }                                                                 #
    }                                                                   #
  } END {                                                               #
    printf "%s", rdnsses                                                #
  }'                                                                    |
  sed 's/^,//'
  return $?
}

#
get_ra_rdnss_lifetime() {
  if [ $# -ne 2 ]; then
    echo "ERROR: get_ra_rdnss_flag <ra_source> <ra_route>." 1>&2
    return 1
  fi
  awk -v src=$1 -v rdnss=$2 'BEGIN {                                    #
    find=0                                                              #
    time=""                                                             #
  } {                                                                   #
    while (getline line) {                                              #
      if (find==1) {                                                    #
        if (match(line,/^  DNS server lifetime/)) {                     #
          split(line,t," ")                                             #
          time=t[5]                                                     #
          find=0                                                        #
        }                                                               #
      } else if (match(line,/^ Recursive DNS server/)                   \
                 && line ~ rdnss) {                                     #
        find=1                                                          #
      } else if (match(line,/^ from.*/)) {                              #
        if (line ~ src) {                                               #
          exit                                                          #
        } else {                                                        #
          time=""                                                       #
        }                                                               #
      }                                                                 #
    }                                                                   #
  } END {                                                               #
    printf "%s", time                                                   #
  }'
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
    rdisc6 -1 $1
    if [ -n "${a_flag}" -a -n "${v6addrs}" ]; then
      result=0
    fi
    if [ -n "${o_flag}" -o -n "${m_flag}" ]; then
      which dhcpcd > /dev/null 2>&1
      if [ $? -eq 0 ]; then
        dhcp_data=`dhcpcd -6 -U $1 | sed "s/'//g"`
      else
        dhcp_data=`cat /var/lib/dhcp/dhclient.$1.leases | sed 's/"//g'`
      fi
      echo "${dhcp_data}"
    fi
    if [ -n "${m_flag}" ]; then
      result=$(( result + 2 ))
      for addr in `echo ${v6addrs} | sed 's/,/ /g'`; do
        # simple comparision
        echo "${dhcp_data}"						|
        grep "dhcp6_ia_na1_ia_addr1=${addr}" > /dev/null 2>&1
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
  ip -6 addr show $1 scope global					|
  sed -n "s/^.*inet6 \(${pref}:[0-9a-f:]*\)\/.*$/\1/p"			|
  awk -F\n -v ORS=',' '{print}'						|
  sed 's/,$//'
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
  ip -6 route show dev $1						|
  sed -n "s/^default via \([0-9a-f:]*\).*$/\1%$1/p"			|
  uniq									|
  awk -v ORS=' ' '1; END{printf "\n"}'
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
  echo "$1"								|
  sed -n 's/^rtt.* \([0-9\.\/]*\) .*$/\1/p'				|
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
    "4" ) traceroute -n -w 2 -q 1 -m 20 $2; return $? ;;
    "6" ) traceroute6 -n -w 2 -q 1 -m 20 $2; return $? ;;
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
    "4" ) command="ping -i 0.2 -W 1"; dfopt="-M do"; header=28 ;;
    "6" ) command="ping6 -i 0.2 -W 1"; dfopt=""; header=48 ;;
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
  # Dig return codes are:
  # 0: Everything went well, including things like NXDOMAIN
  # 1: Usage error
  # 8: Couldn't open batch file
  # 9: No reply from server
  # 10: Internal error
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
for param in LOCKFILE MAX_RETRY IFTYPE DEVNAME PING_SRVS PING6_SRVS FQDNS GPDNS4 GPDNS6 V4WEB_SRVS V6WEB_SRVS; do
  if [ -z `eval echo '$'${param}` ]; then
    echo "ERROR: ${param} is null in configration file." 1>&2
    exit 1
  fi
done

# Check commands
for cmd in uuidgen iwgetid iwconfig; do
  which ${cmd} > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "ERROR: ${cmd} is not found." 1>&2
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
fi
sleep 5

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
  ssid=$(get_wifi_ssid ${devicename})
  if [ -n "${ssid}" ]; then
    write_json ${layer} "${IFTYPE}" ssid ${INFO} self "${ssid}" 0
  fi
  # Get Wi-Fi BSSID
  bssid=$(get_wifi_bssid ${devicename})
  if [ -n "${bssid}" ]; then
    write_json ${layer} "${IFTYPE}" bssid ${INFO} self ${bssid} 0
  fi
  # Get Wi-Fi channel
  channel=$(get_wifi_channel ${devicename})
  if [ -n "${channel}" ]; then
    write_json ${layer} "${IFTYPE}" channel ${INFO} self ${channel} 0
  fi
  # Get Wi-Fi RSSI
  rssi=$(get_wifi_rssi ${devicename})
  if [ -n "${rssi}" ]; then
    write_json ${layer} "${IFTYPE}" rssi ${INFO} self ${rssi} 0
  fi
  # Get Wi-Fi noise
  noise=$(get_wifi_noise ${devicename})
  if [ -n "${noise}" ]; then
    write_json ${layer} "${IFTYPE}" noise ${INFO} self ${noise} 0
  fi
  # Get Wi-Fi quality
  quarity=$(get_wifi_quality ${devicename})
  if [ -n "${quarity}" ]; then
    write_json ${layer} "${IFTYPE}" quarity ${INFO} self ${quarity} 0
  fi
  # Get Wi-Fi rate
  rate=$(get_wifi_rate ${devicename})
  if [ -n "${rate}" ]; then
    write_json ${layer} "${IFTYPE}" rate ${INFO} self ${rate} 0
  fi
  # Get Wi-Fi environment
  environment=$(get_wifi_environment ${devicename})
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
    echo "  quarity: ${quarity}"
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
v4ifconf=$(get_v4ifconf "${devicename}")
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
v6ifconf=$(get_v6ifconf ${devicename})
if [ -n "${v6ifconf}" ]; then
  write_json ${layer} IPv6 v6ifconf ${INFO} self ${v6ifconf} 0
fi

# Get IPv6 linklocal address
v6lladdr=$(get_v6lladdr ${devicename})
if [ -n "${v6lladdr}" ]; then
  write_json ${layer} IPv6 v6lladdr ${INFO} self ${v6lladdr} 0
fi

# Report phase 2 results (IPv6)
if [ "${VERBOSE}" = "yes" ]; then
  echo "  IPv6 conf: ${v6ifconf}"
  echo "  IPv6 lladdr: ${v6lladdr}"
fi

# Get IPv6 RA infomation
ra_info=$(get_ra_info ${devicename})

# Get IPv6 RA source addresses
ra_addrs=$(echo "${ra_info}" | get_ra_addrs)
if [ -n "${ra_addrs}" ]; then
  write_json ${layer} IPv6 ra_addrs ${INFO} self ${ra_addrs} 0
fi

if [ -z "${ra_info}" ]; then
  if [ "${VERBOSE}" = "yes" ]; then
    echo "   RA does not exist."
  fi
else
  count=0
  for addr in $(echo ${ra_addrs} | sed 's/,/ /g'); do
    if [ "${VERBOSE}" = "yes" ]; then
      echo "  IPv6 RA src addr: ${addr}"
    fi
    # Get IPv6 RA flags
    ra_flags=$(echo "${ra_info}" | get_ra_flags ${addr})
    if [ -z "${ra_flags}" ]; then
      ra_flags="none"
    fi
    if [ -n "${ra_flags}" ]; then
      write_json ${layer} RA ra_flags ${INFO} ${addr} ${ra_flags} ${count}
    fi
    if [ "${VERBOSE}" = "yes" ]; then
      echo "   IPv6 RA flags: ${ra_flags}"
    fi

    # Get IPv6 RA parameters
    ra_hoplimit=$(echo "${ra_info}" | get_ra_hoplimit ${addr})
    if [ -n "${ra_hoplimit}" ]; then
      write_json ${layer} RA ra_hoplimit ${INFO} ${addr} ${ra_hoplimit} ${count}
    fi
    if [ "${VERBOSE}" = "yes" ]; then
      echo "   IPv6 RA hoplimit: ${ra_hoplimit}"
    fi
    ra_lifetime=$(echo "${ra_info}" | get_ra_lifetime ${addr})
    if [ -n "${ra_lifetime}" ]; then
      write_json ${layer} RA ra_lifetime ${INFO} ${addr} ${ra_lifetime} ${count}
    fi
    if [ "${VERBOSE}" = "yes" ]; then
      echo "   IPv6 RA lifetime: ${ra_lifetime}"
    fi
    ra_reachable=$(echo "${ra_info}" | get_ra_reachable ${addr})
    if [ -n "${ra_reachable}" ]; then
      write_json ${layer} RA ra_reachable ${INFO} ${addr} ${ra_reachable} ${count}
    fi
    if [ "${VERBOSE}" = "yes" ]; then
      echo "   IPv6 RA reachable: ${ra_reachable}"
    fi
    ra_retransmit=$(echo "${ra_info}" | get_ra_retransmit ${addr})
    if [ -n "${ra_retransmit}" ]; then
      write_json ${layer} RA ra_retransmit ${INFO} ${addr} ${ra_retransmit} ${count}
    fi
    if [ "${VERBOSE}" = "yes" ]; then
      echo "   IPv6 RA retransmit: ${ra_retransmit}"
    fi

    # Get IPv6 RA prefixes
    ra_prefs=$(echo "${ra_info}" | get_ra_prefs ${addr})
    if [ -n "${ra_prefs}" ]; then
      write_json ${layer} RA ra_prefs ${INFO} ${addr} ${ra_prefs} ${count}
    fi

    s_count=0
    for pref in $(echo ${ra_prefs} | sed 's/,/ /g'); do
      if [ "${VERBOSE}" = "yes" ]; then
        echo "   IPv6 RA prefix: ${pref}"
      fi
      # Get IPv6 RA prefix flags
      ra_pref_flags=$(echo "${ra_info}" | get_ra_pref_flags ${addr} ${pref})
      if [ -n "${ra_pref_flags}" ]; then
        write_json ${layer} RA ra_pref_flags ${INFO} ${addr}-${pref} ${ra_pref_flags} ${s_count}
      fi
      if [ "${VERBOSE}" = "yes" ]; then
        echo "    flags: ${ra_pref_flags}"
      fi

      # Get IPv6 RA prefix parameters
      ra_pref_valid=$(echo "${ra_info}" | get_ra_pref_valid ${addr} ${pref})
      if [ -n "${ra_pref_valid}" ]; then
        write_json ${layer} RA ra_pref_valid ${INFO} ${addr}-${pref} ${ra_pref_valid} ${s_count}
      fi
      if [ "${VERBOSE}" = "yes" ]; then
        echo "    valid time: ${ra_pref_valid}"
      fi
      ra_pref_preferred=$(echo "${ra_info}" | get_ra_pref_preferred ${addr} ${pref})
      if [ -n "${ra_pref_preferred}" ]; then
        write_json ${layer} RA ra_pref_preferred ${INFO} ${addr}-${pref} ${ra_pref_preferred} ${s_count}
      fi
      if [ "${VERBOSE}" = "yes" ]; then
        echo "    preferred time: ${ra_pref_preferred}"
      fi

      # Get IPv6 prefix length
      ra_pref_len=$(get_prefixlen ${pref})
      if [ -n "${ra_pref_len}" ]; then
        write_json ${layer} RA ra_pref_len ${INFO} ${addr}-${pref} ${ra_pref_len} ${s_count}
      fi

      # Check IPv6 autoconf
      result_phase2_2=${FAIL}
      rcount=0
      while [ ${rcount} -lt "${MAX_RETRY}" ]; do
        # Get IPv6 address
        v6addrs=$(get_v6addrs ${devicename} ${pref})
        v6autoconf=$(check_v6autoconf ${devicename} ${v6ifconf} ${ra_flags} ${pref} ${ra_pref_flags})
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
        for addr in $(echo ${v6addrs} | sed 's/,/ /g'); do
          echo "   IPv6 addr: ${addr}"
        done
        echo "   intarface status (IPv6): ${result_phase2_2}"
      fi

      s_count=$(( s_count + 1 ))
    done

    # Get IPv6 RA routes
    ra_routes=$(echo "${ra_info}" | get_ra_routes ${addr})
    if [ -n "${ra_routes}" ]; then
      write_json ${layer} RA ra_routes ${INFO} ${addr} ${ra_routes} ${count}
    fi

    s_count=0
    for route in $(echo ${ra_routes} | sed 's/,/ /g'); do
      if [ "${VERBOSE}" = "yes" ]; then
        echo "   IPv6 RA route: ${route}"
      fi
      # Get IPv6 RA route flag
      ra_route_flag=$(echo "${ra_info}" | get_ra_route_flag ${addr} ${route})
      if [ -n "${ra_route_flag}" ]; then
        write_json ${layer} RA ra_route_flag ${INFO} ${addr}-${route} ${ra_route_flag} ${s_count}
      fi
      if [ "${VERBOSE}" = "yes" ]; then
        echo "    flag: ${ra_route_flag}"
      fi

      # Get IPv6 RA route parameters
      ra_route_lifetime=$(echo "${ra_info}" | get_ra_route_lifetime ${addr} ${route})
      if [ -n "${ra_route_lifetime}" ]; then
        write_json ${layer} RA ra_route_lifetime ${INFO} ${addr}-${route} ${ra_route_lifetime} ${s_count}
      fi
      if [ "${VERBOSE}" = "yes" ]; then
        echo "    lifetime: ${ra_route_lifetime}"
      fi

      s_count=$(( s_count + 1 ))
    done

    # Get IPv6 RA RDNSSes
    ra_rdnsses=$(echo "${ra_info}" | get_ra_rdnsses ${addr})
    if [ -n "${ra_rdnsses}" ]; then
      write_json ${layer} RA ra_rdnsses ${INFO} ${addr} ${ra_rdnsses} ${count}
    fi

    s_count=0
    for rdnss in $(echo ${ra_rdnsses} | sed 's/,/ /g'); do
      if [ "${VERBOSE}" = "yes" ]; then
        echo "   IPv6 RA rdnss: ${rdnss}"
      fi
      # Get IPv6 RA RDNSS lifetime
      ra_rdnss_lifetime=$(echo "${ra_info}" | get_ra_rdnss_lifetime ${addr} ${rdnss})
      if [ -n "${ra_rdnss_lifetime}" ]; then
        write_json ${layer} RA ra_rdnss_lifetime ${INFO} ${addr}-${rdnss} ${ra_rdnss_lifetime} ${s_count}
      fi
      if [ "${VERBOSE}" = "yes" ]; then
        echo "    lifetime: ${ra_rdnss_lifetime}"
      fi

      s_count=$(( s_count + 1 ))
    done

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

