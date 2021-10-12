#!/bin/bash
# sindan.sh
# version 2.4.1
VERSION="2.4.1"

# read configurationfile
cd $(dirname $0)
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
  if [ $# -ne 5 ]; then
    echo "ERROR: write_json_campaign <uuid> <mac_addr> <os>"		\
         "<network_type> <network_id>." 1>&2
    echo "DEBUG(input data): $1, $2, $3, $4, $5" 1>&2
    return 1
  fi
  local mac_addr; local network_id
  mac_addr=$(hash_result mac_addr "$2")
  network_id=$(hash_result ssid "$5")
  echo "{ \"log_campaign_uuid\" : \"$1\","				\
       "\"mac_addr\" : \"$mac_addr\","					\
       "\"os\" : \"$3\","						\
       "\"network_type\" : \"$4\","					\
       "\"ssid\" : \"$network_id\","					\
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

## for hardware layer
#
get_os() {
  if which lsb_release > /dev/null 2>&1; then
    lsb_release -ds
  else
    grep PRETTY_NAME /etc/*-release					|
    awk -F\" '{print $2}'
  fi
  return $?
}

#
get_hw_info() {
  if [ -e /proc/device-tree/model ]; then
    awk 1 /proc/device-tree/model | tr -d '\0'
  else
    echo 'TBD'
  fi
  return $?
}

#
get_cpu_freq() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_cpu_freq <os>." 1>&2
    return 1
  fi
  if echo $1 | grep Raspbian > /dev/null 2>&1; then
    vcgencmd measure_clock arm						|
    awk -F= '{print $2}'
  else
    echo 'TBD'
  fi
  return $?
}

#
get_cpu_volt() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_cpu_volt <os>." 1>&2
    return 1
  fi
  if echo $1 | grep Raspbian > /dev/null 2>&1; then
    vcgencmd measure_volts core						|
    sed -n 's/^volt=\([0-9\.]*\).*$/\1/p'
  else
    echo 'TBD'
  fi
  return $?
}

#
get_cpu_temp() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_cpu_temp <os>." 1>&2
    return 1
  fi
  if echo $1 | grep Raspbian > /dev/null 2>&1; then
    vcgencmd measure_temp						|
    sed -n 's/^temp=\([0-9\.]*\).*$/\1/p'
  elif [ -f /sys/class/thermal/thermal_zone0/temp ]; then
    echo "scale=3; $(cat /sys/class/thermal/thermal_zone0/temp) / 1000" |
    bc
  else
    echo 'TBD'
  fi
  return $?
}

#
get_clock_state() {
  if which timedatectl > /dev/null 2>&1; then
    timedatectl								|
    sed -n 's/.*System clock synchronized: \([a-z]*\).*$/\1/p'
  else
    echo 'TBD'
  fi
  return $?
}

#
get_clock_src() {
  if which timedatectl > /dev/null 2>&1; then
    use_timesyncd=$(timedatectl |
      grep -e "NTP service: active" \
           -e "systemd-timesyncd.service active: yes")
    if [ -n "$use_timesyncd" ]; then
      systemctl status systemd-timesyncd				|
      grep Status							|
      sed 's/^[ \t]*//'
    else
      if [ -e /run/ntpd.pid ]; then
        ntpq -p | grep -e ^o -e ^*
      elif [ -e /run/chronyd.pid ]; then
        chronyc sources | grep "\^\*"
      else
        echo 'using unknown time synclonization service.'
      fi
    fi
  else
    echo 'TBD'
  fi
  return $?
}

## for datalink layer
#
get_devicename() {
  echo "$DEVNAME"
  return $?
}

#
do_ifdown() {
  if [ $# -ne 2 ]; then
    echo "ERROR: do_ifdown <devicename> <iftype>." 1>&2
    return 1
  fi
  if which nmcli > /dev/null 2>&1 &&
     [ "$(nmcli networking)" = "enabled" ]; then
    local wwan_dev
    if [ "$2" = "WWAN" ]; then
      wwan_dev=$(get_wwan_port "$1")
      nmcli device disconnect "$wwan_dev"
    else
      nmcli device disconnect "$1"
    fi
  elif which ifconfig > /dev/null 2>&1; then
    ifconfig "$1" down
  else
    ip link set "$1" down
  fi
  return $?
}

#
do_ifup() {
  if [ $# -ne 2 ]; then
    echo "ERROR: do_ifup <devicename> <iftype>." 1>&2
    return 1
  fi
  if which nmcli > /dev/null 2>&1 &&
     [ "$(nmcli networking)" = "enabled" ]; then
    local wwan_dev
    if [ "$2" = "WWAN" ]; then
      wwan_dev=$(get_wwan_port "$1")
      nmcli device connect "$wwan_dev"
    else
      nmcli device connect "$1"
    fi
  elif which ifconfig > /dev/null 2>&1; then
    ifconfig "$1" up
  else
    ip link set "$1" up
  fi
  return $?
}

#
get_ifstatus() {
  if [ $# -ne 2 ]; then
    echo "ERROR: get_ifstatus <devicename> <iftype>." 1>&2
    return 1
  fi
  local status; local path; local modem_info
  if [ "$2" = "WWAN" ]; then
    for path in $(mmcli -L | awk '{print $1}' | tr '\n' ' '); do
      modem_info=$(mmcli -m $path)
      if echo $modem_info | grep "$1" > /dev/null 2>&1; then
        status=$(echo "$modem_info"					| 
                 awk 'BEGIN {						#
                   find=0						#
                 } {							#
                   while (getline line) {				#
                     if (find==1 && match(line,/.*state:.*/)) {		#
                       split(line,s," ")				#
                       printf "%s", s[3]				#
                       exit						#
                     } else if (match(line,/^  Status.*/)) {		#
                       find=1						#
                     }							#
                   }							#
                 }'							|
                 sed 's/\x1b\[[0-9;]*m//g')
        break
      fi
    done
  else
    status=$(cat /sys/class/net/"$1"/operstate)
  fi
  if [ "$status" = "up" ] || [ "$status" = "connected" ]; then
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
  cat /sys/class/net/"$1"/mtu
  return $?
}

#
get_macaddr() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_macaddr <devicename>." 1>&2
    return 1
  fi
  < /sys/class/net/"$1"/address	tr "[:upper:]" "[:lower:]"
  return $?
}

#
get_mediatype() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_mediatype <devicename>." 1>&2
    return 1
  fi
  local speed; local duplex
  speed=$(cat /sys/class/net/"$1"/speed)
  duplex=$(cat /sys/class/net/"$1"/duplex)
  echo "${speed}_${duplex}"
  return $?
}

#
get_wifi_ssid() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_wifi_ssid <devicename>." 1>&2
    return 1
  fi
  iwgetid "$1" --raw
  return $?
}

#
get_wifi_bssid() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_wifi_bssid <devicename>." 1>&2
    return 1
  fi
  iwgetid "$1" --raw --ap						|
  tr "[:upper:]" "[:lower:]"
  return $?
}

#
get_wifi_apoui() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_wifi_bssid <devicename>." 1>&2
    return 1
  fi
  iwgetid "$1" --raw --ap						|
  cut -d: -f1-3								|
  tr "[:upper:]" "[:lower:]"
  return $?
}

#
get_wifi_channel() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_wifi_channel <devicename>." 1>&2
    return 1
  fi
  iwgetid "$1" --raw --channel
  return $?
}

#
get_wifi_rssi() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_wifi_rssi <devicename>." 1>&2
    return 1
  fi
  grep "$1" /proc/net/wireless						|
  awk '{print $4}'							|
  sed 's/.$//'
  return $?
}

#
get_wifi_noise() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_wifi_noise <devicename>." 1>&2
    return 1
  fi
  grep "$1" /proc/net/wireless						|
  awk '{print $5}'							|
  sed 's/.$//'
  return $?
}

#
get_wifi_quality() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_wifi_quality <devicename>." 1>&2
    return 1
  fi
  iwconfig "$1"								|
  sed -n 's/^.*Link Quality=\([0-9\/]*\).*$/\1/p'
  return $?
}

#
get_wifi_rate() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_wifi_rate <devicename>." 1>&2
    return 1
  fi
  iwconfig "$1"								|
  sed -n 's/^.*Bit Rate=\([0-9.]*\) Mb\/s.*$/\1/p'
  return $?
}

#
get_wifi_environment() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_wifi_environment <devicename>." 1>&2
    return 1
  fi
  echo "BSSID,Protocol,SSID,Channel,Quality,RSSI,Noise,BitRates"
  iwlist "$1" scanning							|
  awk 'BEGIN {								#
    find=0								#
  } {									#
    while (getline line) {						#
      if (find==1) {							#
        if (match(line,/Protocol:.*/)) {				#
          split(line,a,":")						#
          printf ",%s", a[2]						#
        } else if (match(line,/ESSID:.*/)) {				#
          split(line,a,"\"")						#
          printf ",%s", a[2]						#
        } else if (match(line,/Channel [0-9]*/)) {			#
          split(substr(line,RSTART,RLENGTH),a," ")			#
          printf ",%s", a[2]						#
        } else if (match(line,/Quality=.*/)) {				#
          gsub(/=/," ",line)						#
          split(line,a," ")						#
          printf ",%s,%s,%s", a[2], a[5], a[9]				#
        } else if (match(line,/Rates:[0-9.]* /)) {			#
          split(substr(line,RSTART,RLENGTH),a,":")			#
          printf ",%s\n", a[2]						#
          find=0							#
        }								#
      } else if (match(line,/Address:.*/)) {				#
        split(substr(line,RSTART,RLENGTH),a," ")			#
        printf "%s", tolower(a[2])					#
        find=1								#
      }									#
    }									#
  }'
  return $?
}

#
get_wwan_port() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_wwan_port <devicename>." 1>&2
    return 1
  fi
  for path in $(mmcli -L | awk '{print $1}' | tr '\n' ' '); do
    modem_info=$(mmcli -m $path)
    if echo $modem_info | grep "$1" > /dev/null 2>&1; then
      echo "$modem_info"						|
      awk 'BEGIN {							#
        find=0								#
      } {								#
        while (getline line) {						#
          if (find==1 && match(line,/.*primary port:.*/)) {		#
            split(line,s," ")						#
            printf "%s", s[4]						#
            exit							#
          } else if (match(line,/^  System.*/)) {			#
            find=1							#
          }								#
        }								#
      }'
      break
    fi
  done
}

#
get_wwan_info() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_wwan_info <devicename>." 1>&2
    return 1
  fi
  local modem_info; local bearer_info; local signal_info
  local threegpp_info
  for path in $(mmcli -L | awk '{print $1}' | tr '\n' ' '); do
    modem_info=$(mmcli -m $path)
    if echo $modem_info | grep "$1" > /dev/null 2>&1; then
      echo 'CELLULER INFO:'
      echo 'MODEM INFO:'
      echo "$modem_info"

      for bearer in $(echo "$modem_info"				|
                      sed -n 's/^.*Bearer\/\([0-9]*\).*$/\1/p'		|
                      tr '\n' ' '); do
        bearer_info=$(mmcli -b $bearer)
        if echo $bearer_info | grep "$1" > /dev/null 2>&1; then
          echo 'BEARER INFO:'
          echo "$bearer_info"
        fi
      done

      signal_info=$(mmcli -m $path --signal-get)
      if echo "$signal_info"						|
              grep "refresh rate: 0 seconds" > /dev/null 2>&1; then
        mmcli -m $path --signal-setup=10 > /dev/null 2>&1
        signal_info=$(mmcli -m $path --signal-get)
      fi
      echo 'SIGNAL INFO:'
      echo "$signal_info"

      threegpp_info=$(mmcli -m $path --location-get)
      echo '3GPP INFO:'
      echo "$threegpp_info"

      break
    fi
  done
}

#
get_wwan_value() {
  if [ $# -ne 4 ]; then
    echo "ERROR: get_wwan_value <type> <cat> <name> <pos>." 1>&2
    return 1
  fi
  # require get_wwan_info() data from STDIN.
  awk -v type="$1" -v cat="$2" -v name="$3" -v pos="$4" 'BEGIN {	#
    find=0								#
  } {									#
    while (getline line) {						#
      if (find==1 || find==2) {						#
        if (find==2 && line ~ name) {					#
          split(line,s," ")						#
          printf "%s", s[pos]						#
          exit								#
        } else if (line ~ cat) {					#
          if (line ~ name) {						#
            split(line,s," ")						#
            printf "%s", s[pos+1]					#
            exit							#
          }								#
          find=2							#
        }								#
      } else if (line ~ type) {						#
        find=1								#
      }									#
    }									#
  }'
  return $?
}

#
get_wwan_modemid() {
  get_wwan_value 'MODEM INFO:' General 'dbus path:' 4
  return $?
}

#
get_wwan_apn() {
  get_wwan_value 'BEARER INFO:' Properties 'apn:' 3
  return $?
}

#
get_wwan_iptype() {
  get_wwan_value 'BEARER INFO:' Properties 'ip type:' 4
  return $?
}

#
get_wwan_ifmtu() {
  get_wwan_value 'BEARER INFO:' 'IPv4 configuration' mtu: 3
  return $?
}

#
get_wwan_iftype() {
  get_wwan_value 'MODEM INFO:' Status 'access tech:' 4
  return $?
}

#
get_wwan_quality() {
  get_wwan_value 'MODEM INFO:' Status 'signal quality:' 4		|
  sed 's/%//'
  return $?
}

#
get_wwan_imei() {
  get_wwan_value 'MODEM INFO:' 3GPP imei: 3
  return $?
}

#
get_wwan_operator() {
  get_wwan_value 'MODEM INFO:' 3GPP 'operator name:' 4
  return $?
}

#
get_wwan_mmcmnc() {
  get_wwan_value 'MODEM INFO:' 3GPP 'operator id:' 4
  return $?
}

#
get_wwan_rssi() {
  get_wwan_value 'SIGNAL INFO:' LTE 'rssi:' 3
  return $?
}

#
get_wwan_rsrq() {
  get_wwan_value 'SIGNAL INFO:' LTE 'rsrq:' 3
  return $?
}

#
get_wwan_rsrp() {
  get_wwan_value 'SIGNAL INFO:' LTE 'rsrp:' 3
  return $?
}

#
get_wwan_snir() {
  get_wwan_value 'SIGNAL INFO:' LTE 's/n:' 3
  return $?
}

#
get_wwan_band() {
  :
  #TBD
}

#
get_wwan_cid() {
  get_wwan_value '3GPP INFO:' 3GPP 'cell id:' 4
  return $?
}

#
get_wwan_lac() {
  get_wwan_value '3GPP INFO:' 3GPP 'location area code:' 5
  return $?
}

#
get_wwan_tac() {
  get_wwan_value '3GPP INFO:' 3GPP 'tracking area code:' 5
  return $?
}

#
get_wwan_environment() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_wwan_environment <modemid>." 1>&2
    return 1
  fi
  echo "MMC,MNC,Name,Tech,Status"
  mmcli -m "$1" --3gpp-scan --timeout=60				|
  sed -n 's/.*\([0-9]\{3\}\)\([0-9]\{2\}\) - \(.*\) (\(.*\), \(.*\))/\1,\2,\3,\4,\5/p'
  return $?
}

## for interface layer
#
get_v4ifconf() {
  if [ $# -ne 2 ]; then
    echo "ERROR: get_v4ifconf <devicename> <iftype>." 1>&2
    return 1
  fi
  if [ -f /etc/dhcpcd.conf ]; then
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
  elif which nmcli > /dev/null 2>&1 &&
       [ "$(nmcli networking)" = "enabled" ]; then
    local wwan_dev; local conpath
    if [ "$2" = "WWAN" ]; then
      wwan_dev=$(get_wwan_port "$1")
      conpath=$(nmcli -g general.con-path device show "$wwan_dev")
    else
      conpath=$(nmcli -g general.con-path device show "$1")
    fi
    nmcli -g ipv4.method connection show "$conpath"
  else ## netplan
    echo 'TBD'
  fi
  return $?
}

#
get_v4addr() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_v4addr <devicename>." 1>&2
    return 1
  fi
  ip -4 addr show "$1"							|
  sed -n 's/^.*inet \([0-9.]*\)\/.*$/\1/p'
  return $?
}

#
get_netmask() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_netmask <devicename>." 1>&2
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

#
check_v4autoconf() {
  if [ $# -ne 2 ]; then
    echo "ERROR: check_v4autoconf <devicename> <v4ifconf>." 1>&2
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

#
get_v4routers() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_v4routers <devicename>." 1>&2
    return 1
  fi
  ip -4 route show dev "$1"						|
  sed -n 's/^default via \([0-9.]*\).*$/\1/p'
  return $?
}

#
get_v4nameservers() {
  sed -n 's/^nameserver \([0-9.]*\)$/\1/p' /etc/resolv.conf		|
  awk -v ORS=',' '1; END {printf "\n"}'					|
  sed 's/,$//'
  return $?
}

#
ip2decimal() {
  if [ $# -ne 1 ]; then
    echo "ERROR: ip2decimal <v4addr>." 1>&2
    return 1
  fi
  local o=()
  o=($(echo "$1" | sed 's/\./ /g'))
  echo $(( (o[0] << 24) | (o[1] << 16) | (o[2] << 8) | o[3] ))
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
    echo "ERROR: get_v6ifconf <devicename>." 1>&2
    return 1
  fi
  local v6ifconf
  if [ -f /etc/dhcpcd.conf ]; then
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
  elif which nmcli > /dev/null 2>&1 &&
       [ "$(nmcli networking)" = "enabled" ]; then
    local wwan_dev; local conpath
    if [ "$2" = "WWAN" ]; then
      wwan_dev=$(get_wwan_port "$1")
      conpath=$(nmcli -g general.con-path device show "$wwan_dev")
    else
      conpath=$(nmcli -g general.con-path device show "$1")
    fi
    nmcli -g ipv6.method connection show "$conpath"
  else ## netplan
    echo 'TBD'
  fi
  return $?
}

#
get_v6lladdr() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_v6lladdr <devicename>." 1>&2
    return 1
  fi
  ip -6 addr show "$1" scope link					|
  sed -n 's/^.*inet6 \(fe80[0-9a-f:]*\)\/.*$/\1/p'
  return $?
}

#
get_ra_info() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_ra_info <devicename>." 1>&2
    return 1
  fi
  rdisc6 -n "$1"
  return $?
}

#
get_ra_addrs() {
  # require get_ra_info() data from STDIN.
  grep '^ from'								|
  awk '{print $2}'							|
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

#
get_ra_hlim() {
  # require get_ra_info() data from STDIN.
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

#
get_ra_ltime() {
  # require get_ra_info() data from STDIN.
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

#
get_ra_reach() {
  # require get_ra_info() data from STDIN.
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

#
get_ra_retrans() {
  # require get_ra_info() data from STDIN.
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

#
get_ra_prefs() {
  # require get_ra_info() data from STDIN.
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

#
get_ra_pref_flags() {
  # require get_ra_info() data from STDIN.
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

#
get_ra_pref_vltime() {
  # require get_ra_info() data from STDIN.
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

#
get_ra_pref_pltime() {
  # require get_ra_info() data from STDIN.
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

#
get_ra_routes() {
  # require get_ra_info() data from STDIN.
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

#
get_ra_route_flag() {
  # require get_ra_info() data from STDIN.
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

#
get_ra_route_ltime() {
  # require get_ra_info() data from STDIN.
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

#
get_ra_rdnsses() {
  # require get_ra_info() data from STDIN.
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

#
get_ra_rdnss_ltime() {
  # require get_ra_info() data from STDIN.
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

#
check_v6autoconf() {
  if [ $# -ne 5 ]; then
    echo "ERROR: check_v6autoconf <devicename> <v6ifconf> <ra_flags>"	\
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

#
get_v6addrs() {
  if [ $# -le 1 ]; then
    # ra_prefix can be omitted in case of manual configuration.
    echo "ERROR: get_v6addrs <devicename> <ra_prefix>." 1>&2
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
  ip -6 addr show "$1" scope global					|
  grep "$2"								|
  sed -n "s/^.*inet6 [0-9a-f:]*\/\([0-9]*\).*$/\1/p"
  return $?
}

#
get_v6routers() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_v6routers <devicename>." 1>&2
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

#
get_v6nameservers() {
  sed -n 's/^nameserver \([0-9a-f:]*\)$/\1/p' /etc/resolv.conf		|
  awk -v ORS=',' '1; END{printf "\n"}'					|
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
  sed -n 's/^rtt.* \([0-9\.\/]*\) .*$/\1/p'				|
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
    "4" ) timeout -sKILL 30 traceroute -n -I -w 2 -q 1 -m 20 "$2"; return $? ;;
    "6" ) timeout -sKILL 30 traceroute6 -n -I -w 2 -q 1 -m 20 "$2"; return $? ;;
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
  if [ $# -ne 5 ]; then
    echo "ERROR: do_pmtud <version> <target_addr> <min_mtu> <src_addr>"		\
         "<max_mtu>." 1>&2
    return 1
  fi
  case $1 in
    "4" ) command="ping -i 0.2 -W 1"; dfopt="-M do"; header=28 ;;
    "6" ) command="ping6 -i 0.2 -W 1"; dfopt="-M do"; header=48 ;;
    * ) echo "ERROR: <version> must be 4 or 6." 1>&2; return 9 ;;
  esac
  if ! eval $command -c 1 $2 -I $5 > /dev/null; then
    echo 0
    return 1
  fi
  local version=$1
  local target=$2
  local min=$3
  local max=$4
  local src_addr=$5
  local mid=$(( ( min + max ) / 2 ))
  local result=0

  if [ "$min" -eq "$mid" ] || [ "$max" -eq "$mid" ]; then
    echo "$(( min + header ))"
    return 0
  fi
  if eval $command -c 1 -s $mid $dfopt $target -I $src_addr >/dev/null 2>/dev/null
  then
    result=$(do_pmtud "$version" "$target" "$mid" "$max" "$src_addr")
  else
    result=$(do_pmtud "$version" "$target" "$min" "$mid" "$src_addr")
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
  if [ $# -ne 7 ]; then
    echo "ERROR: cmdset_pmtud <layer> <version> <target_type>"		\
         "<target_addr> <ifmtu> <count> <src_addr>." 1>&2
    return 1
  fi
  local layer=$1
  local ver=$2
  local ipv=IPv${ver}
  local type=$3
  local target=$4
  local min_mtu=56
  local max_mtu=$5
  local count=$6
  local src_addr=$7
  local string=" pmtud to $ipv server: $target, from: $src_addr"
  local pmtu_result

  pmtu_result=$(do_pmtud "$ver" "$target" "$min_mtu" "$max_mtu" "$src_addr")
  if [ "$pmtu_result" -eq 0 ]; then
    write_json "$layer" "$ipv" "v${ver}pmtu_${type}" "$INFO" "$target"	\
               unmeasurable "$count"
    string="$string\n  pmtu: unmeasurable"
  else
    write_json "$layer" "$ipv" "v${ver}pmtu_${type}" "$INFO" "$target"	\
               "$pmtu_result" "$count"
    string="$string\n  pmtu: $pmtu_result byte"
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
do_portscan () {
  if [ $# -ne 3 ]; then
    echo "ERROR: do_portscan <verson> <target> <port>." 1>&2
    return 1
  fi
  case $1 in
    "4" ) nc -zv4 -w1 "$2" "$3" 2>&1 ; return $? ;;
    "6" ) nc -zv6 -w1 "$2" "$3" 2>&1 ; return $? ;;
    "*" ) echo "ERROR: <version> must be 4 or 6." 1>&2; return 9 ;;
  esac
}

cmdset_portscan () {
  if [ $# -ne 6 ]; then
    echo "ERROR: cmdset_portscan <layer> <version> <target_type>"	\
         "<target_addr> <target_port> <count>." 1>&2
    return 1
  fi
  local layer=$1
  local ver=$2
  local ipv="IPv${ver}"
  local type=$3
  local target=$4
  local port=$5
  local count=$6
  local result=$FAIL
  local string=" portscan to extarnal server: $target:$port by $ipv"
  local ps_ans

  if ps_ans=$(do_portscan "$ver" "$target" "$port"); then
    result=$SUCCESS
  else
    stat=$?
  fi
  write_json "$layer" "$ipv" "v${ver}portscan_${port}" "$result"	\
	     "$target" "$ps_ans" "$count"
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
do_speedindex() {
  if [ $# -ne 1 ]; then
    echo "ERROR: do_speedindex <target_url>." 1>&2
    return 1
  fi

  tracejson=trace-json/$(echo "$1" | sed 's/[.:/]/_/g').json
  node speedindex.js "$1" ${tracejson}
  return $?
}

#
cmdset_speedindex() {
  if [ $# -ne 5 ]; then
    echo "ERROR: cmdset_speedindex <layer> <version> <target_type>"	\
         "<target_addr> <count>." 1>&2
    return 1
  fi
  local layer=$1
  local ver=$2
  local type=$3
  local target=$4
  local count=$5
  local result=$FAIL
  local string=" speedindex to extarnal server: $target by $ver"
  local speedindex_ans

  if speedindex_ans=$(do_speedindex ${target}); then
    result=$SUCCESS
  else
    stat=$?
  fi
  write_json "$layer" "$ver" speedindex "$result" "$target"	\
             "$speedindex_ans" "$count"
  if [ "$result" = "$SUCCESS" ]; then
    string="$string\n  status: ok, speed index value: $speedindex_ans"
  else
    string="$string\n  status: ng ($stat)"
  fi
  if [ "$VERBOSE" = "yes" ]; then
    echo -e "$string"
  fi
}

#
do_speedtest() {
  if [ $# -ne 1 ]; then
    echo "ERROR: do_speedtest <target_url>." 1>&2
    return 1
  fi

  node speedtest.js "$1"
  return $?
}

#
get_speedtest_ipv4_rtt() {
  # require do_speedtest() data from STDIN.
  sed -n 's/IPv4_RTT://p'
  return $?
}

#
get_speedtest_ipv4_jit() {
  # require do_speedtest() data from STDIN.
  sed -n 's/IPv4_JIT://p'
  return $?
}

#
get_speedtest_ipv4_dl() {
  # require do_speedtest() data from STDIN.
  sed -n 's/IPv4_DL://p'
  return $?
}

#
get_speedtest_ipv4_ul() {
  # require do_speedtest() data from STDIN.
  sed -n 's/IPv4_UL://p'
  return $?
}

#
get_speedtest_ipv6_rtt() {
  # require do_speedtest() data from STDIN.
  sed -n 's/IPv6_RTT://p'
  return $?
}

#
get_speedtest_ipv6_jit() {
  # require do_speedtest() data from STDIN.
  sed -n 's/IPv6_JIT://p'
  return $?
}

#
get_speedtest_ipv6_dl() {
  # require do_speedtest() data from STDIN.
  sed -n 's/IPv6_DL://p'
  return $?
}

#
get_speedtest_ipv6_ul() {
  # require do_speedtest() data from STDIN.
  sed -n 's/IPv6_UL://p'
  return $?
}

#
cmdset_speedtest() {
  if [ $# -ne 5 ]; then
      echo "ERROR: cmdset_speedtest <layer> <version> <target_type>"	\
           "<target_addr> <count>." 1>&2
    return 1
  fi
  local layer=$1
  local ver=$2
  local type=$3
  local target=$4
  local count=$5
  local result=$FAIL
  local string=" speedtest to extarnal server: $target by $ver"
  local speedtest_ans
  local ipv4_rtt; local ipv4_jit; local ipv4_dl; local ipv4_ul
  local ipv6_rtt; local ipv6_jit; local ipv6_dl; local ipv6_ul

  if speedtest_ans=$(do_speedtest "$target"); then
    result=$SUCCESS
  else
    stat=$?
  fi
  if [ "$result" = "$SUCCESS" ]; then
    string="$string\n  status: ok"
    write_json "$layer" "$ver" speedtest "$result" "$target"	\
               "$speedtest_ans" "$count"
    if ipv4_rtt=$(echo "$speedtest_ans" | get_speedtest_ipv4_rtt); then
      write_json "$layer" IPv4 v4speedtest_rtt "$INFO" "$target"	\
                 "$ipv4_rtt" "$count"
      string="$string\n  IPv4 RTT: $ipv4_rtt ms"
    fi
    if ipv4_jit=$(echo "$speedtest_ans" | get_speedtest_ipv4_jit); then
      write_json "$layer" IPv4 v4speedtest_jitter "$INFO" "$target"	\
                 "$ipv4_jit" "$count"
      string="$string\n  IPv4 Jitter: $ipv4_jit ms"
    fi
    if ipv4_dl=$(echo "$speedtest_ans" | get_speedtest_ipv4_dl); then
      write_json "$layer" IPv4 v4speedtest_download "$INFO" "$target"	\
                 "$ipv4_dl" "$count"
      string="$string\n  IPv4 Download Speed: $ipv4_dl Mbps"
    fi
    if ipv4_ul=$(echo "$speedtest_ans" | get_speedtest_ipv4_ul); then
      write_json "$layer" IPv4 v4speedtest_upload "$INFO" "$target"	\
                 "$ipv4_ul" "$count"
      string="$string\n  IPv4 Upload Speed: $ipv4_ul Mbps"
    fi
    if ipv6_rtt=$(echo "$speedtest_ans" | get_speedtest_ipv6_rtt); then
      write_json "$layer" IPv6 v6speedtest_rtt "$INFO" "$target"	\
                 "$ipv6_rtt" "$count"
      string="$string\n  IPv6 RTT: $ipv6_rtt ms"
    fi
    if ipv6_jit=$(echo "$speedtest_ans" | get_speedtest_ipv6_jit); then
      write_json "$layer" IPv6 v6speedtest_jitter "$INFO" "$target"	\
                 "$ipv6_jit" "$count"
      string="$string\n  IPv6 Jitter: $ipv6_jit ms"
    fi
    if ipv6_dl=$(echo "$speedtest_ans" | get_speedtest_ipv6_dl); then
      write_json "$layer" IPv6 v6speedtest_download "$INFO" "$target"	\
                 "$ipv6_dl" "$count"
      string="$string\n  IPv6 Download Speed: $ipv6_dl Mbps"
    fi
    if ipv6_ul=$(echo "$speedtest_ans" | get_speedtest_ipv6_ul); then
      write_json "$layer" IPv6 v6speedtest_upload "$INFO" "$target"	\
                 "$ipv6_ul" "$count"
      string="$string\n  IPv6 Upload Speed: $ipv6_ul Mbps"
    fi
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
for param in LOCKFILE MAX_RETRY IFTYPE DEVNAME PING_SRVS PING6_SRVS FQDNS GPDNS4 GPDNS6 V4WEB_SRVS V6WEB_SRVS V4SSH_SRVS V6SSH_SRVS; do
  if [ -z $(eval echo '$'$param) ]; then
    echo "ERROR: $param is null in configration file." 1>&2
    exit 1
  fi
done

# Check commands
for cmd in uuidgen iwgetid iwconfig; do
  if ! which $cmd > /dev/null 2>&1; then
    echo "ERROR: $cmd is not found." 1>&2
    exit 1
  fi
done

####################
## Phase 0
echo "Phase 0: Hardware Layer checking..."
layer="hardware"

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
    echo "Warning: previous check appears to have not finished correctly."
  fi
fi

# Make log directory
mkdir -p log
mkdir -p trace-json

# Cleate UUID
UUID=$(cleate_uuid)

# Get OS version
os=$(get_os)

# Get hardware information
hw_info=$(get_hw_info)
if [ -n "$hw_info" ]; then
  write_json "$layer" common hw_info "$INFO" self "$hw_info" 0
fi

# Get CPU frequency
cpu_freq=$(get_cpu_freq "$os")
if [ -n "$cpu_freq" ]; then
  write_json "$layer" common cpu_freq "$INFO" self "$cpu_freq" 0
fi

# Get CPU voltage
cpu_volt=$(get_cpu_volt "$os")
if [ -n "$cpu_volt" ]; then
  write_json "$layer" common cpu_volt "$INFO" self "$cpu_volt" 0
fi

# Get CPU temperature
cpu_temp=$(get_cpu_temp "$os")
if [ -n "$cpu_temp" ]; then
  write_json "$layer" common cpu_temp "$INFO" self "$cpu_temp" 0
fi

# Get clock state
clock_state="synchronized=$(get_clock_state)"
if [ -n "$clock_state" ]; then
  write_json "$layer" common clock_state "$INFO" self "$clock_state" 0
fi

# Get clock source
clock_src=$(get_clock_src)
if [ -n "$clock_src" ]; then
  write_json "$layer" common clock_src "$INFO" self "$clock_src" 0
fi

# Report phase 0 results
if [ "$VERBOSE" = "yes" ]; then
  echo " hardware information:"
  echo "  os: $os"
  echo "  hw_info: $hw_info"
  echo "  cpu(freq: $cpu_freq Hz, volt: $cpu_volt V, temp: $cpu_temp 'C"
  echo "  clock_state: $clock_state"
  echo "  clock_src: $clock_src"
fi

echo " done."


####################
## Phase 1
echo "Phase 1: Datalink Layer checking..."
layer="datalink"

# Get devicename
devicename=$(get_devicename "$IFTYPE")

# Down, Up interface
if [ "$RECONNECT" = "yes" ]; then
  # Down target interface
  if [ "$VERBOSE" = "yes" ]; then
    echo " interface:$devicename down"
  fi
  do_ifdown "$devicename" "$IFTYPE"
  sleep 2

  # Start target interface
  if [ "$VERBOSE" = "yes" ]; then
    echo " interface:$devicename up"
  fi
  do_ifup "$devicename" "$IFTYPE"
  sleep 5
fi

# Get iftype
write_json "$layer" common iftype "$INFO" self "$IFTYPE" 0

# Check I/F status
result_phase1=$FAIL
rcount=0
while [ "$rcount" -lt "$MAX_RETRY" ]; do
  if ifstatus=$(get_ifstatus "$devicename" "$IFTYPE"); then
    result_phase1=$SUCCESS
    break
  fi
  sleep 5
  rcount=$(( rcount + 1 ))
done
if [ -n "$ifstatus" ]; then
  write_json "$layer" "$IFTYPE" ifstatus "$result_phase1" self		\
             "$ifstatus" 0
fi

if [ "$IFTYPE" != "WWAN" ]; then
  # Get MAC address
  mac_addr=$(get_macaddr "$devicename")

  # Get ifmtu
  ifmtu=$(get_ifmtu "$devicename")
  if [ -n "$ifmtu" ]; then
    write_json "$layer" "$IFTYPE" ifmtu "$INFO" self "$ifmtu" 0
  fi
fi

#
if [ "$IFTYPE" = "Wi-Fi" ]; then
  # Get Wi-Fi SSID
  ssid=$(get_wifi_ssid "$devicename")
  if [ -n "$ssid" ]; then
    write_json "$layer" "$IFTYPE" ssid "$INFO" self "$ssid" 0
  fi
  # Get Wi-Fi BSSID
  bssid=$(get_wifi_bssid "$devicename")
  if [ -n "$bssid" ]; then
    write_json "$layer" "$IFTYPE" bssid "$INFO" self "$bssid" 0
  fi
  # Get Wi-Fi AP's OUI
  wifiapoui=$(get_wifi_apoui "$devicename")
  if [ -n "$wifiapoui" ]; then
    write_json "$layer" "$IFTYPE" wifiapoui "$INFO" self "$wifiapoui" 0
  fi
  # Get Wi-Fi channel
  channel=$(get_wifi_channel "$devicename")
  if [ -n "$channel" ]; then
    write_json "$layer" "$IFTYPE" channel "$INFO" self "$channel" 0
  fi
  # Get Wi-Fi RSSI
  rssi=$(get_wifi_rssi "$devicename")
  if [ -n "$rssi" ]; then
    write_json "$layer" "$IFTYPE" rssi "$INFO" self "$rssi" 0
  fi
  # Get Wi-Fi noise
  noise=$(get_wifi_noise "$devicename")
  if [ -n "$noise" ]; then
    write_json "$layer" "$IFTYPE" noise "$INFO" self "$noise" 0
  fi
  # Get Wi-Fi quality
  quality=$(get_wifi_quality "$devicename")
  if [ -n "$quality" ]; then
    write_json "$layer" "$IFTYPE" quality "$INFO" self "$quality" 0
  fi
  # Get Wi-Fi rate
  rate=$(get_wifi_rate "$devicename")
  if [ -n "$rate" ]; then
    write_json "$layer" "$IFTYPE" rate "$INFO" self "$rate" 0
  fi
  # Get Wi-Fi environment
  environment=$(get_wifi_environment "$devicename")
  if [ -n "$environment" ]; then
    write_json "$layer" "$IFTYPE" environment "$INFO" self		\
               "$environment" 0
  fi
elif [ "$IFTYPE" = "WWAN" ]; then
  # Get WWAN infomation
  wwan_info=$(get_wwan_info "$devicename")
  if [ -n "$wwan_info" ]; then
    write_json "$layer" "$IFTYPE" info "$INFO" self "$wwan_info" 0

    # Get IMEI
    wwan_imei=$(echo "$wwan_info" | get_wwan_imei)
    # Get WWAN environment
    wwan_modemid=$(echo "$wwan_info" | get_wwan_modemid)
    wwan_environment=$(get_wwan_environment "$wwan_modemid")
    if [ -n "$wwan_environment" ]; then
      write_json "$layer" "$IFTYPE" environment "$INFO" self		\
                 "$wwan_environment" 0
    fi

    # Get ifmtu
    ifmtu=$(echo "$wwan_info" | get_wwan_ifmtu)
    if [ -n "$ifmtu" ]; then
      write_json "$layer" "$IFTYPE" ifmtu "$INFO" self "$ifmtu" 0
    else
      ifmtu=$(get_ifmtu "$devicename")
      if [ -n "$ifmtu" ]; then
        write_json "$layer" "$IFTYPE" ifmtu "$INFO" self "$ifmtu" 0
      fi
    fi

    # Get WWAN apn
    wwan_apn=$(echo "$wwan_info" | get_wwan_apn)
    if [ -n "$wwan_apn" ]; then
      write_json "$layer" "$IFTYPE" apn "$INFO" self "$wwan_apn" 0
    fi
    # Get WWAN iftype
    wwan_iftype=$(echo "$wwan_info" | get_wwan_iftype)
    if [ -n "$wwan_iftype" ]; then
      write_json "$layer" "$IFTYPE" iftype "$INFO" self "$wwan_iftype" 0
    fi
    # Get WWAN quality
    wwan_quality=$(echo "$wwan_info" | get_wwan_quality)
    if [ -n "$wwan_quality" ]; then
      write_json "$layer" "$IFTYPE" quality "$INFO" self "$wwan_quality" 0
    fi
    # Get WWAN operator
    wwan_operator=$(echo "$wwan_info" | get_wwan_operator)
    if [ -n "$wwan_operator" ]; then
      write_json "$layer" "$IFTYPE" operator "$INFO" self		\
                 "$wwan_operator" 0
    fi
    # Get WWAN mmcmnc
    wwan_mmcmnc=$(echo "$wwan_info" | get_wwan_mmcmnc)
    if [ -n "$wwan_mmcmnc" ]; then
      write_json "$layer" "$IFTYPE" mmcmnc "$INFO" self "$wwan_mmcmnc" 0
    fi
    # Get WWAN iptype
    wwan_iptype=$(echo "$wwan_info" | get_wwan_iptype)
    if [ -n "$wwan_iptype" ]; then
      write_json "$layer" "$IFTYPE" iptype "$INFO" self "$wwan_iptype" 0
    fi
    # Get WWAN rssi
    wwan_rssi=$(echo "$wwan_info" | get_wwan_rssi)
    if [ -n "$wwan_rssi" ]; then
      write_json "$layer" "$IFTYPE" rssi "$INFO" self "$wwan_rssi" 0
    fi
    # Get WWAN rsrq
    wwan_rsrq=$(echo "$wwan_info" | get_wwan_rsrq)
    if [ -n "$wwan_rsrq" ]; then
      write_json "$layer" "$IFTYPE" rsrq "$INFO" self "$wwan_rsrq" 0
    fi
    # Get WWAN rsrp
    wwan_rsrp=$(echo "$wwan_info" | get_wwan_rsrp)
    if [ -n "$wwan_rsrp" ]; then
      write_json "$layer" "$IFTYPE" rsrp "$INFO" self "$wwan_rsrp" 0
    fi
    # Get WWAN snir
    wwan_snir=$(echo "$wwan_info" | get_wwan_snir)
    if [ -n "$wwan_snir" ]; then
      write_json "$layer" "$IFTYPE" snir "$INFO" self "$wwan_snir" 0
    fi
    # Get WWAN cid
    wwan_cid=$(echo "$wwan_info" | get_wwan_cid)
    if [ -n "$wwan_cid" ]; then
      write_json "$layer" "$IFTYPE" cid "$INFO" self "$wwan_cid" 0
    fi
    # Get WWAN lac
    wwan_lac=$(echo "$wwan_info" | get_wwan_lac)
    if [ -n "$wwan_lac" ]; then
      write_json "$layer" "$IFTYPE" lac "$INFO" self "$wwan_lac" 0
    fi
    # Get WWAN tac
    wwan_tac=$(echo "$wwan_info" | get_wwan_tac)
    if [ -n "$wwan_tac" ]; then
      write_json "$layer" "$IFTYPE" tac "$INFO" self "$wwan_tac" 0
    fi
  fi
else
  # Get media type
  media=$(get_mediatype "$devicename")
  if [ -n "$media" ]; then
    write_json "$layer" "$IFTYPE" media "$INFO" self "$media" 0
  fi
fi

# Report phase 1 results
if [ "$VERBOSE" = "yes" ]; then
  echo " datalink information:"
  echo "  datalink status: $result_phase1"
  echo "  type: $IFTYPE, dev: $devicename"
  echo "  status: $ifstatus, mtu: $ifmtu byte"
  if [ "$IFTYPE" = "Wi-Fi" ]; then
    echo "  ssid: $ssid, ch: $channel, rate: $rate Mbps"
    echo "  bssid: $bssid"
    echo "  rssi: $rssi dBm, noise: $noise dBm"
    echo "  quality: $quality"
    echo "  environment:"
    echo "$environment"
  elif [ "$IFTYPE" = "WWAN" ]; then
    echo "  apn: $wwan_apn, iftype: $wwan_iftype, iptype: $wwan_iptype"
    echo "  operator: $wwan_operator, mmc/mnc: $wwan_mmcmnc"
    echo "  cid: $wwan_cid, lac: $wwan_lac, tac: $wwan_tac"
    echo "  rssi: $wwan_rssi dBm, rsrq: $wwan_rsrq dB, rsrp:"		\
         "$wwan_rsrp dBm, s/n: $wwan_snir dB"
    echo "  quality: $wwan_quality %"
    echo "  environment:"
    echo "$wwan_environment"
  else
    echo "  media: $media"
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
  v4ifconf=$(get_v4ifconf "$devicename" "$IFTYPE")
  if [ -n "$v4ifconf" ]; then
    write_json "$layer" IPv4 v4ifconf "$INFO" self "$v4ifconf" 0
  fi

  # Check IPv4 autoconf
  if [ "$IFTYPE" = "WWAN" ]; then
    result_phase2_1=$SUCCESS
    v4autoconf="$v4ifconf"
  else 
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
  fi
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
  v6ifconf=$(get_v6ifconf "$devicename")
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
      write_json "$layer" IPv6 v6autoconf "$result_phase2_2" self       \
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
          write_json "$layer" IPv6 pref_len "$INFO" "$addr" "$pref_len" \
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
        ra_hlim=$(echo "$ra_info" | get_ra_hlim "$saddr")
        if [ -n "$ra_hlim" ]; then
          write_json "$layer" RA ra_hlim "$INFO" "$saddr" "$ra_hlim"	\
                     "$count"
        fi
        ra_ltime=$(echo "$ra_info" | get_ra_ltime "$saddr")
        if [ -n "$ra_ltime" ]; then
          write_json "$layer" RA ra_ltime "$INFO" "$saddr" "$ra_ltime"	\
                     "$count"
        fi
        ra_reach=$(echo "$ra_info" | get_ra_reach "$saddr")
        if [ -n "$ra_reach" ]; then
          write_json "$layer" RA ra_reach "$INFO" "$saddr" "$ra_reach"	\
                     "$count"
        fi
        ra_retrans=$(echo "$ra_info" | get_ra_retrans "$saddr")
        if [ -n "$ra_retrans" ]; then
          write_json "$layer" RA ra_retrans "$INFO" "$saddr"		\
                     "$ra_retrans" "$count"
        fi

        # Report phase 2 results (IPv6-RA)
        if [ "$VERBOSE" = "yes" ]; then
          echo "  IPv6 RA src addr: $saddr"
          echo "   IPv6 RA flags: $ra_flags"
          echo "   IPv6 RA hoplimit: $ra_hlim"
          echo "   IPv6 RA lifetime: $ra_ltime"
          echo "   IPv6 RA reachable: $ra_reach"
          echo "   IPv6 RA retransmit: $ra_retrans"
        fi

        # Get IPv6 RA prefixes
        ra_prefs=$(echo "$ra_info" | get_ra_prefs "$saddr")
        if [ -n "$ra_prefs" ]; then
          write_json "$layer" RA ra_prefs "$INFO" "$saddr" "$ra_prefs"	\
                     "$count"
        fi

        s_count=0
        for pref in $(echo "$ra_prefs" | sed 's/,/ /g'); do
          # Get IPv6 RA prefix flags
          ra_pref_flags=$(echo "$ra_info"				|
                        get_ra_pref_flags "$saddr" "$pref")
          if [ -n "$ra_pref_flags" ]; then
            write_json "$layer" RA ra_pref_flags "$INFO"		\
                       "${saddr}-${pref}" "$ra_pref_flags" "$s_count"
          fi

          # Get IPv6 RA prefix parameters
          ra_pref_vltime=$(echo "$ra_info"				|
                         get_ra_pref_vltime "$saddr" "$pref")
          if [ -n "$ra_pref_vltime" ]; then
            write_json "$layer" RA ra_pref_vltime "$INFO"		\
                       "${saddr}-${pref}" "$ra_pref_vltime" "$s_count"
          fi
          ra_pref_pltime=$(echo "$ra_info"				|
                         get_ra_pref_pltime "$saddr" "$pref")
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
        ra_routes=$(echo "$ra_info" | get_ra_routes "$saddr")
        if [ -n "$ra_routes" ]; then
          write_json "$layer" RA ra_routes "$INFO" "$saddr"		\
                     "$ra_routes" "$count"
        fi

        s_count=0
        for route in $(echo "$ra_routes" | sed 's/,/ /g'); do
          # Get IPv6 RA route flag
          ra_route_flag=$(echo "$ra_info"				|
                        get_ra_route_flag "$saddr" "$route")
          if [ -n "$ra_route_flag" ]; then
            write_json "$layer" RA ra_route_flag "$INFO"		\
                       "${saddr}-${route}" "$ra_route_flag" "$s_count"
          fi

          # Get IPv6 RA route parameters
          ra_route_ltime=$(echo "$ra_info"				|
                            get_ra_route_ltime "$saddr" "$route")
          if [ -n "$ra_route_ltime" ]; then
            write_json "$layer" RA ra_route_ltime "$INFO"		\
                       "${saddr}-${route}" "$ra_route_ltime" "$s_count"
          fi

          # Report phase 2 results (IPv6-RA-Route)
          if [ "$VERBOSE" = "yes" ]; then
            echo "   IPv6 RA route: $route"
            echo "    flag: $ra_route_flag"
            echo "    lifetime: $ra_route_ltime"
          fi

          s_count=$(( s_count + 1 ))
        done

        # Get IPv6 RA RDNSSes
        ra_rdnsses=$(echo "$ra_info" | get_ra_rdnsses "$saddr")
        if [ -n "$ra_rdnsses" ]; then
          write_json "$layer" RA ra_rdnsses "$INFO" "$saddr"		\
                     "$ra_rdnsses" "$count"
        fi

        s_count=0
        for rdnss in $(echo "$ra_rdnsses" | sed 's/,/ /g'); do
          # Get IPv6 RA RDNSS lifetime
          ra_rdnss_ltime=$(echo "$ra_info"				|
                            get_ra_rdnss_ltime "$saddr" "$rdnss")
          if [ -n "$ra_rdnss_ltime" ]; then
            write_json "$layer" RA ra_rdnss_ltime "$INFO"		\
                       "${saddr}-${rdnss}" "$ra_rdnss_ltime" "$s_count"
          fi

          # Report phase 2 results (IPv6-RA-RDNSS)
          if [ "$VERBOSE" = "yes" ]; then
            echo "   IPv6 RA rdnss: $rdnss"
            echo "    lifetime: $ra_rdnss_ltime"
          fi

          s_count=$(( s_count + 1 ))
        done

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
      cmdset_pmtud "$layer" 4 srv "$target" "$ifmtu" "$count" "$v4addr" &
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
  
    oIFS="$IFS"
    IFS=','
    for v6addr in $v6addrs; do
      if [ "$MODE" = "client" ]; then
        # Check path MTU to extarnal IPv6 servers
        cmdset_pmtud "$layer" 6 srv "$target" "$ifmtu" "$count" "$v6addr" &
      fi
    done
    IFS="$oIFS"
    unset oIFS

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
  
  count=0
  for target in $(echo "$PS_SRVS4" | sed 's/,/ /g'); do
    for port in $(echo "$PS_PORTS" | sed 's/,/ /g'); do

      # Do portscan by IPv4
      cmdset_portscan "$layer" 4 pssrv "$target" "$port" "$count" &
    
    done
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

  count=0
  for target in $(echo "$PS_SRVS6" | sed 's/,/ /g'); do
    for port in $(echo "$PS_PORTS" | sed 's/,/ /g'); do
  
      # Do portscan by 6
      cmdset_portscan "$layer" 6 pssrv "$target" "$port" "$count" &

    done
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

    count=0
    for target in $(echo "$PS_SRVS4" | sed 's/,/ /g'); do
      for port in $(echo "$PS_PORTS" | sed 's/,/ /g'); do

        # Do portscan by IPv6
        cmdset_portscan "$layer" 6 pssrv "$target" "$port" "$count" &
    
      done
      count=$(( count + 1 ))
    done
  fi
fi

# dualstack performance measurements
if [ "$v4addr_type" = "private" ] || [ "$v4addr_type" = "grobal" ] ||	\
   [ -n "$v6addrs" ]; then

  # SPEEDINDEX
  if [ "$DO_SPEEDINDEX" = "yes" ]; then

    count=0
    for target in $(echo "$SI_SRVS" | sed 's/,/ /g'); do

      # Do speedindex
      cmdset_speedindex "$layer" Dualstack speedidsrv "$target" "$count"

      count=$(( count + 1 ))
    done
  fi

  # SPEEDTEST
  if [ "$DO_SPEEDTEST" = "yes" ]; then

    count=0
    for target in $(echo "$ST_SRVS" | sed 's/,/ /g'); do

      # Do speedtest
      cmdset_speedtest "$layer" Dualstack speedtssrv "$target" "$count"

      count=$(( count + 1 ))
    done
  fi
fi

wait
echo " done."


####################
## Phase 7
echo "Phase 7: Create campaign log..."

# Write campaign log file
if [ "$IFTYPE" = "Wi-Fi" ]; then
  write_json_campaign "$UUID" "$mac_addr" "$os" "$IFTYPE" "$ssid"
elif [ "$IFTYPE" = "WWAN" ]; then
  write_json_campaign "$UUID" "$wwan_imei" "$os" "$IFTYPE" "$wwan_apn"
else
  write_json_campaign "$UUID" "$mac_addr" "$os" "$IFTYPE" none
fi

# remove lock file
rm -f "$LOCKFILE"

echo " done."

exit 0

