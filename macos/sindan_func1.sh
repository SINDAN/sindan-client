#!/bin/bash
# sindan_func1.sh

## Datalink Layer functions

# Get the interface name.
# get_ifname <iftype>
function get_ifname() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_devicename <iftype>." 1>&2
    return 1
  fi
  networksetup -listnetworkserviceorder					|
  sed -n "s/^.*: $1, Device: \([a-z0-9]*\))$/\1/p"
  return $?
}

# Stop the interface.
# do_ifdown <ifname> <iftype>
function do_ifdown() {
  if [ $# -ne 1 ]; then
    echo "ERROR: do_ifdown <devicename>." 1>&2
    return 1
  fi
  networksetup -setairportpower "$1" off
  return $?
}

# Activate the interface.
# do_ifup <ifname> <iftype>
function do_ifup() {
  if [ $# -ne 1 ]; then
    echo "ERROR: do_ifup <devicename>." 1>&2
    return 1
  fi
  networksetup -setairportpower "$1" on
  return $?
}

# Get the interface status.
# get_ifstatus <ifname> <iftype>
function get_ifstatus() {
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

# Get MTU of the interface.
# get_ifmtu <ifname>
function get_ifmtu() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_ifmtu <devicename>." 1>&2
    return 1
  fi
  ifconfig "$1"								|
  sed -n 's/^.*mtu \([0-9]*\)$/\1/p'
  return $?
}

# Get MAC address on the interface.
# get_macaddr <ifname>
function get_macaddr() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_macaddr <devicename>." 1>&2
    return 1
  fi
  ifconfig "$1"								|
  sed -n 's/^.*ether \([0-9a-fA-F:]*\).*$/\1/p'				|
  tr "[:upper:]" "[:lower:]"
  return $?
}

# Get media type of the interface.
# get_mediatype <ifname>
function get_mediatype() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_mediatype <devicename>." 1>&2
    return 1
  fi
  ifconfig "$1"								|
  sed -n 's/^.*media: \(.*\)$/\1/p'
  return $?
}

# Get Wireless LAN informarion on the interface.
# get_wlan_info
function get_wlan_info() {
  if which system_profiler > /dev/null 2>&1; then
    system_profiler SPAirPortDataType
    return $?
  else
    echo "ERROR: system_profiler command not found." 1>&2
    return 1
  fi
}

# Get SSID using on the interface.
# require get_wlan_info() data from STDIN.
# get_wlan_ssid <ifname>
function get_wlan_ssid() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_wlan_ssid <ifname>." 1>&2
    return 1
  fi
  awk -v ifname="$1" 'BEGIN {						#
    find=0								#
    value=""								#
  } {									#
    while (getline line) {						#
      if (match(line,/^ +Interfaces:$/)) {				#
        find=1								#
      } else if (find == 1) {						#
        if (line ~ "(^ +)"ifname":$") {					#
          find=2							#
        }								#
      } else if (find == 2) {						#
        if (match(line,/^ +Current Network Information:$/)) {		#
          getline line							#
          gsub(/^ +|:$/,"",line)					#
          value=line							#
          exit								#
        }								#
      }									#
    }									#
  } END {								#
    printf "%s", value							#
  }'
  return $?
}

# Get BSSID using on the interface.
# get_wlan_bssid <ifname>
function get_wlan_bssid() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_wlan_bssid <ifname>." 1>&2
    return 1
  fi
  ioreg -l -n AirPortDriver						|
  sed -n 's/.*"IO80211BSSID" = <\([^"]*\)>.*/\1/p'			|
  fold -w2								|
  paste -sd: -
  return $?
}

# Get WLAN MCS Index using on the interface.
# require get_wlan_info() data from STDIN.
# get_wlan_mcsi <ifname>
function get_wlan_mcsi() {
  if [ $# -ne 1 ]; then 
    echo "ERROR: get_wlan_mcsi <ifname>." 1>&2
    return 1
  fi
  awk -v ifname="$1" 'BEGIN {						#
    find=0								#
    value=""								#
  } {									#
    while (getline line) {						#
      if (match(line,/^ +Interfaces:$/)) {				#
        find=1								#
      } else if (find == 1) {						#
        if (line ~ "(^ +)"ifname":$") {					#
          find=2							#
          gsub(/^ +|:$/,"",line)					#
        }								#
      } else if (find == 2) {						#
        if (match(line,/^ +Current Network Information:$/)) {		#
          find=3							#
        }								#
      } else if (find == 3) {						#
        if (match(line,/^ +MCS Index:.*$/)) {				#
          split(line,v," ")						#
          value=v[3]							#
          exit								#
        }								#
      }									#
    }									#
  } END {								#
    printf "%d", value							#
  }'
  return $?
}

# Get WLAN mode using on the interface.
# require get_wlan_info() data from STDIN.
# get_wlan_mode <ifname>
function get_wlan_mode() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_wlan_mode <ifname>." 1>&2
    return 1
  fi
  awk -v ifname="$1" 'BEGIN {						#
    find=0								#
    value=""								#
  } {									#
    while (getline line) {						#
      if (match(line,/^ +Interfaces:$/)) {				#
        find=1								#
      } else if (find == 1) {						#
        if (line ~ "(^ +)"ifname":$") {					#
          find=2							#
          gsub(/^ +|:$/,"",line)					#
        }								#
      } else if (find == 2) {						#
        if (match(line,/^ +Current Network Information:$/)) {		#
          find=3							#
        }								#
      } else if (find == 3) {						#
        if (match(line,/^ +PHY Mode:.*$/)) {				#
          split(line,v," ")						#
          value=v[3]							#
          exit								#
        }								#
      }									#
    }									#
  } END {								#
    printf "%s", value							#
  }'
  return $?
}

# Get Channel using on the interface.
# require get_wlan_info() data from STDIN.
# get_wlan_channel <ifname>
function get_wlan_channel() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_wlan_channel <ifname>." 1>&2
    return 1
  fi
  if which ioreg > /dev/null 2>&1; then
    ioreg -l -n AirPortDriver						|
    sed -n 's/.*"IO80211Channel" = \([0-9]*\)/\1/p'
    return $?
  fi
  awk -v ifname="$1" 'BEGIN {						#
    find=0								#
    value=""								#
  } {									#
    while (getline line) {						#
      if (match(line,/^ +Interfaces:$/)) {				#
        find=1								#
      } else if (find == 1) {						#
        if (line ~ "(^ +)"ifname":$") {					#
          find=2							#
          gsub(/^ +|:$/,"",line)					#
        }								#
      } else if (find == 2) {						#
        if (match(line,/^ +Current Network Information:$/)) {		#
          find=3							#
        }								#
      } else if (find == 3) {						#
        if (match(line,/^ +Channel:.*$/)) {				#
          split(line,v," ")						#
          value=v[2]							#
          exit								#
        }								#
      }									#
    }									#
  } END {								#
    printf "%d", value							#
  }'
  return $?
}

# Get Channel BandWidth using on the interface.
# require get_wlan_info() data from STDIN.
# get_wlan_chband <ifname>
function get_wlan_chband() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_wlan_chband <ifname>." 1>&2
    return 1
  fi
  if which ioreg > /dev/null 2>&1; then
    ioreg -l -n AirPortDriver						|
    sed -n 's/.*"IO80211ChannelBandwidth" = \([0-9]*\)/\1/p'
    return $?
  fi
  awk -v ifname="$1" 'BEGIN {						#
    find=0								#
    value=""								#
  } {									#
    while (getline line) {						#
      if (match(line,/^ +Interfaces:$/)) {				#
        find=1								#
      } else if (find == 1) {						#
        if (line ~ "(^ +)"ifname":$") {					#
          find=2							#
          gsub(/^ +|:$/,"",line)					#
        }								#
      } else if (find == 2) {						#
        if (match(line,/^ +Current Network Information:$/)) {		#
          find=3							#
        }								#
      } else if (find == 3) {						#
        if (match(line,/^ +Channel:.*$/)) {				#
          split(line,v," ")						#
          split(v[4],num,"MHz")						#
          value=num[1]							#
          exit								#
        }								#
      }									#
    }									#
  } END {								#
    printf "%d", value							#
  }'
  return $?
}

# Get RSSI using on the interface.
# require get_wlan_info() data from STDIN.
# get_wlan_rssi <ifname>
function get_wlan_rssi() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_wlan_rssi <ifname>." 1>&2
    return 1
  fi
  awk -v ifname="$1" 'BEGIN {						#
    find=0								#
    value=""								#
  } {									#
    while (getline line) {						#
      if (match(line,/^ +Interfaces:$/)) {				#
        find=1								#
      } else if (find == 1) {						#
        if (line ~ "(^ +)"ifname":$") {					#
          find=2							#
          gsub(/^ +|:$/,"",line)					#
        }								#
      } else if (find == 2) {						#
        if (match(line,/^ +Current Network Information:$/)) {		#
          find=3							#
        }								#
      } else if (find == 3) {						#
        if (match(line,/^ +Signal \/ Noise:.*$/)) {			#
          split(line,v," ")						#
          value=v[4]							#
          exit								#
        }								#
      }									#
    }									#
  } END {								#
    printf "%d", value							#
  }'
  return $?
}

# Get Noise using on the interface.
# require get_wlan_info() data from STDIN.
# get_wlan_noise <ifname>
function get_wlan_noise() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_wlan_noise <ifname>." 1>&2
    return 1
  fi
  awk -v ifname="$1" 'BEGIN {						#
    find=0								#
    value=""								#
  } {									#
    while (getline line) {						#
      if (match(line,/^ +Interfaces:$/)) {				#
        find=1								#
      } else if (find == 1) {						#
        if (line ~ "(^ +)"ifname":$") {					#
          find=2							#
          gsub(/^ +|:$/,"",line)					#
        }								#
      } else if (find == 2) {						#
        if (match(line,/^ +Current Network Information:$/)) {		#
          find=3							#
        }								#
      } else if (find == 3) {						#
        if (match(line,/^ +Signal \/ Noise:.*$/)) {			#
          split(line,v," ")						#
          value=v[7]							#
          exit								#
        }								#
      }									#
    }									#
  } END {								#
    printf "%d", value							#
  }'
  return $?
}

# Get quality of WLAN using on the interface.
# get_wlan_quality <ifname>
function get_wlan_quality() {
  :
  #TBD
}

# Get Rate using on the interface.
# require get_wlan_info() data from STDIN.
# get_wlan_rate <ifname>
function get_wlan_rate() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_wlan_rate <ifname>." 1>&2
    return 1
  fi
  awk -v ifname="$1" 'BEGIN {						#
    find=0								#
    value=""								#
  } {									#
    while (getline line) {						#
      if (match(line,/^ +Interfaces:$/)) {				#
        find=1								#
      } else if (find == 1) {						#
        if (line ~ "(^ +)"ifname":$") {					#
          find=2							#
          gsub(/^ +|:$/,"",line)					#
        }								#
      } else if (find == 2) {						#
        if (match(line,/^ +Current Network Information:$/)) {		#
          find=3							#
        }								#
      } else if (find == 3) {						#
        if (match(line,/^ +Transmit Rate:.*$/)) {			#
          split(line,v," ")						#
          value=v[3]							#
          exit								#
        }								#
      }									#
    }									#
  } END {								#
    printf "%d", value							#
  }'
  return $?
}

# Get the list of access points in range of the interface.
# require get_wlan_info() json data from STDIN.
# get_wlan_environment <ifname>
function get_wlan_environment() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_wlan_environment <ifname>." 1>&2
    return 1
  fi
  echo "SSID,PHY Mode,Channel,Band,Width,Network Type,Security"
  awk -v ifname="$1" 'BEGIN {						#
    find=0								#
    OFS=","								#
  } {									#
    while (getline line) {						#
      if (match(line,/^ +Interfaces:$/)) {				#
        find=1								#
      } else if (find == 1) {						#
        if (line ~ "(^ +)"ifname":$") {					#
          find=2							#
        }								#
      } else if (find == 2) {						#
        if (match(line,/^ +Other Local Wi-Fi Networks:$/)) {		#
          find=3							#
        }								#
      } else if ((find == 3) && (line ~ /^ +.*:$/)) {			#
        gsub(/^ +|:$/,"",line)						#
        ssid=line							#
        find=4								#
      } else if (find == 4) {						#
        if (match(line,/^ +PHY Mode:.*$/)) {				#
          split(line,m," ")						#
          mode=m[3]							#
        } else if (match(line,/^ +Channel:.*$/)) {			#
          split(line,c," ")						#
          channel=c[2]							#
          band=c[3]							#
          width=c[4]							#
          gsub(/[(),]/, "", band)					#
          gsub(/[(),]/, "", width)					#
        } else if (match(line,/^ +Network Type:.*$/)) {			#
          split(line,t," ")						#
          type=t[3]							#
        } else if (match(line,/^ +Security:.*$/)) {			#
          split(line,s,": ")						#
          security=s[2]							#
          print ssid,mode,channel,band,width,type,security		#
          find=3							#
        } else if (match(line,/^ +MAC Address:.*$/)) {			#
          # this area is other interface section			#
          exit								#
        } else {							#
          # this filed is not required					#
          next								#
        }								#
      }									#
    }									#
  }'
  return $?
}

# Get port number of the WWAN interface.
# get_wwan_port <ifname>
function get_wwan_port() {
  :
  #TBD
}

# Get the WWAN interface information.
# get_wwan_info <ifname>
function get_wwan_info() {
  :
  #TBD
}

# Get various information of WWAN.
# get_wwan_value <type> <cat> <name> <pos>
# require get_wwan_info() data from STDIN.
function get_wwan_value() {
  :
  #TBD
}

# Get modem ID of WWAN.
function get_wwan_modemid() {
  :
  #TBD
}

# Get APN of WWAN.
function get_wwan_apn() {
  :
  #TBD
}

# Get IP type of WWAN.
function get_wwan_iptype() {
  :
  #TBD
}

# Get MTU of WWAN.
function get_wwan_ifmtu() {
  :
  #TBD
}

# Get interface type of WWAN.
function get_wwan_iftype() {
  :
  #TBD
}

# Get quality of WWAN.
function get_wwan_quality() {
  :
  #TBD
}

# Get IMEI of WWAN.
function get_wwan_imei() {
  :
  #TBD
}

# Get operator name of WWAN.
function get_wwan_operator() {
  :
  #TBD
}

# Get operator ID of WWAN.
function get_wwan_mmcmnc() {
  :
  #TBD
}

# Get RSSI of WWAN.
function get_wwan_rssi() {
  :
  #TBD
}

# Get RSRQ of WWAN.
function get_wwan_rsrq() {
  :
  #TBD
}

# Get RSRP of WWAN.
function get_wwan_rsrp() {
  :
  #TBD
}

# Get SNR of WWAN.
function get_wwan_snir() {
  :
  #TBD
}

# Get band of WWAN.
function get_wwan_band() {
  :
  #TBD
}

# Get cell ID of WWAN.
function get_wwan_cid() {
  :
  #TBD
}

# Get location area code of WWAN.
function get_wwan_lac() {
  :
  #TBD
}

# Get.tracking area code of WWAN.
function get_wwan_tac() {
  :
  #TBD
}

# Get list of available WWAN networks on the modem ID.
# get_wwan_environment <modemid>
function get_wwan_environment() {
  :
  #TBD
}

