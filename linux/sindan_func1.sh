#!/bin/bash
# sindan_func1.sh

## Datalink Layer functions

# Get the interface name.
function get_ifname() {
  echo "$IFNAME"
  return $?
}

# Stop the interface.
# do_ifdown <ifname> <iftype>
function do_ifdown() {
  if [ $# -ne 2 ]; then
    echo "ERROR: do_ifdown <ifname> <iftype>." 1>&2
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

# Activate the interface.
# do_ifup <ifname> <iftype>
function do_ifup() {
  if [ $# -ne 2 ]; then
    echo "ERROR: do_ifup <ifname> <iftype>." 1>&2
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

# Get the interface status.
# get_ifstatus <ifname> <iftype>
function get_ifstatus() {
  if [ $# -ne 2 ]; then
    echo "ERROR: get_ifstatus <ifname> <iftype>." 1>&2
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

# Get MTU of the interface.
# get_ifmtu <ifname>
function get_ifmtu() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_ifmtu <ifname>." 1>&2
    return 1
  fi
  cat /sys/class/net/"$1"/mtu
  return $?
}

# Get MAC address on the interface.
# get_macaddr <ifname>
function get_macaddr() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_macaddr <ifname>." 1>&2
    return 1
  fi
  < /sys/class/net/"$1"/address	tr "[:upper:]" "[:lower:]"
  return $?
}

# Get media type of the interface.
# get_mediatype <ifname>
function get_mediatype() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_mediatype <ifname>." 1>&2
    return 1
  fi
  local speed; local duplex
  speed=$(cat /sys/class/net/"$1"/speed)
  duplex=$(cat /sys/class/net/"$1"/duplex)
  echo "${speed}_${duplex}"
  return $?
}

# Get SSID using on the interface.
# get_wlan_ssid <ifname>
function get_wlan_ssid() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_wlan_ssid <ifname>." 1>&2
    return 1
  fi
  iwgetid "$1" --raw
  return $?
}

# Get BSSID using on the interface.
# get_wlan_bssid <ifname>
function get_wlan_bssid() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_wlan_bssid <ifname>." 1>&2
    return 1
  fi
  iwgetid "$1" --raw --ap						|
  tr "[:upper:]" "[:lower:]"
  return $?
}

# Get OUI of Access Point using on the interface.
# get_wlan_apoui <ifname>
function get_wlan_apoui() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_wlan_apoui <ifname>." 1>&2
    return 1
  fi
  iwgetid "$1" --raw --ap						|
  cut -d: -f1-3								|
  tr "[:upper:]" "[:lower:]"
  return $?
}

# Get channel of WLAN using on the interface.
# get_wlan_channel <ifname>
function get_wlan_channel() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_wlan_channel <ifname>." 1>&2
    return 1
  fi
  iwgetid "$1" --raw --channel
  return $?
}

# Get RSSI of WLAN using on the interface.
# get_wlan_rssi <ifname>
function get_wlan_rssi() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_wlan_rssi <ifname>." 1>&2
    return 1
  fi
  grep "$1" /proc/net/wireless						|
  awk '{print $4}'							|
  sed 's/.$//'
  return $?
}

# Get noise of WLAN using on the interface.
# get_wlan_noise <ifname>
function get_wlan_noise() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_wlan_noise <ifname>." 1>&2
    return 1
  fi
  grep "$1" /proc/net/wireless						|
  awk '{print $5}'							|
  sed 's/.$//'
  return $?
}

# Get quality of WLAN using on the interface.
# get_wlan_quality <ifname>
function get_wlan_quality() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_wlan_quality <ifname>." 1>&2
    return 1
  fi
  iwconfig "$1"								|
  sed -n 's/^.*Link Quality=\([0-9\/]*\).*$/\1/p'
  return $?
}

# Get current bit rate of WLAN using on the interface.
# get_wlan_rate <ifname>
function get_wlan_rate() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_wlan_rate <ifname>." 1>&2
    return 1
  fi
  iwconfig "$1"								|
  sed -n 's/^.*Bit Rate=\([0-9.]*\) Mb\/s.*$/\1/p'
  return $?
}

# Get the list of access points in range of the interface.
# get_wlan_environment <ifname>
function get_wlan_environment() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_wlan_environment <ifname>." 1>&2
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

# Get port number of the WWAN interface.
# get_wwan_port <ifname>
function get_wwan_port() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_wwan_port <ifname>." 1>&2
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

# Get the WWAN interface information.
# get_wwan_info <ifname>
function get_wwan_info() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_wwan_info <ifname>." 1>&2
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

# Get various information of WWAN.
# get_wwan_value <type> <cat> <name> <pos>
# require get_wwan_info() data from STDIN.
function get_wwan_value() {
  if [ $# -ne 4 ]; then
    echo "ERROR: get_wwan_value <type> <cat> <name> <pos>." 1>&2
    return 1
  fi
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

# Get modem ID of WWAN.
function get_wwan_modemid() {
  get_wwan_value 'MODEM INFO:' General 'dbus path:' 4
  return $?
}

# Get APN of WWAN.
function get_wwan_apn() {
  get_wwan_value 'BEARER INFO:' Properties 'apn:' 3
  return $?
}

# Get IP type of WWAN.
function get_wwan_iptype() {
  get_wwan_value 'BEARER INFO:' Properties 'ip type:' 4
  return $?
}

# Get MTU of WWAN.
function get_wwan_ifmtu() {
  get_wwan_value 'BEARER INFO:' 'IPv4 configuration' mtu: 3
  return $?
}

# Get interface type of WWAN.
function get_wwan_iftype() {
  get_wwan_value 'MODEM INFO:' Status 'access tech:' 4
  return $?
}

# Get quality of WWAN.
function get_wwan_quality() {
  get_wwan_value 'MODEM INFO:' Status 'signal quality:' 4		|
  sed 's/%//'
  return $?
}

# Get IMEI of WWAN.
function get_wwan_imei() {
  get_wwan_value 'MODEM INFO:' 3GPP imei: 3
  return $?
}

# Get operator name of WWAN.
function get_wwan_operator() {
  get_wwan_value 'MODEM INFO:' 3GPP 'operator name:' 4
  return $?
}

# Get operator ID of WWAN.
function get_wwan_mmcmnc() {
  get_wwan_value 'MODEM INFO:' 3GPP 'operator id:' 4
  return $?
}

# Get RSSI of WWAN.
function get_wwan_rssi() {
  get_wwan_value 'SIGNAL INFO:' LTE 'rssi:' 3
  return $?
}

# Get RSRQ of WWAN.
function get_wwan_rsrq() {
  get_wwan_value 'SIGNAL INFO:' LTE 'rsrq:' 3
  return $?
}

# Get RSRP of WWAN.
function get_wwan_rsrp() {
  get_wwan_value 'SIGNAL INFO:' LTE 'rsrp:' 3
  return $?
}

# Get SNR of WWAN.
function get_wwan_snir() {
  get_wwan_value 'SIGNAL INFO:' LTE 's/n:' 3
  return $?
}

# Get band of WWAN.
function get_wwan_band() {
  :
  #TBD
}

# Get cell ID of WWAN.
function get_wwan_cid() {
  get_wwan_value '3GPP INFO:' 3GPP 'cell id:' 4
  return $?
}

# Get location area code of WWAN.
function get_wwan_lac() {
  get_wwan_value '3GPP INFO:' 3GPP 'location area code:' 5
  return $?
}

# Get.tracking area code of WWAN.
function get_wwan_tac() {
  get_wwan_value '3GPP INFO:' 3GPP 'tracking area code:' 5
  return $?
}

# Get list of available WWAN networks on the modem ID.
# get_wwan_environment <modemid>
function get_wwan_environment() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_wwan_environment <modemid>." 1>&2
    return 1
  fi
  echo "MMC,MNC,Name,Tech,Status"
  mmcli -m "$1" --3gpp-scan --timeout=60				|
  sed -n 's/.*\([0-9]\{3\}\)\([0-9]\{2\}\) - \(.*\) (\(.*\), \(.*\))/\1,\2,\3,\4,\5/p'
  return $?
}

