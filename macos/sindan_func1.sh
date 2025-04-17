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

# Get the WLAN interface informarion.
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

# Get WLAN SSID of the interface.
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

# Get WLAN BSSID of the interface.
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

# Get WLAN Bit Rate (Tx) of the interface.
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
          split(line,rate_parts," ")					#
          value=rate_parts[3]						#
          exit								#
        }								#
      }									#
    }									#
  } END {								#
    printf "%d", value							#
  }'
  return $?
}

# Get WLAN MCS Index (Tx) of the interface.
# require get_wlan_info() data from STDIN.
# get_wlan_mcs <ifname>
function get_wlan_mcs() {
  if [ $# -ne 1 ]; then 
    echo "ERROR: get_wlan_mcs <ifname>." 1>&2
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
          split(line,mcs_parts," ")					#
          value=mcs_parts[3]						#
          exit								#
        }								#
      }									#
    }									#
  } END {								#
    printf "%d", value							#
  }'
  return $?
}

# Get Number of WLAN Spatial Stream (Tx) of the interface.
# require get_wlan_info() data from STDIN.
# get_wlan_nss
function get_wlan_nss() {
  ::
  #TBD
}

# Get WLAN PHY Mode of the interface.
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
          split(line,mode_parts," ")					#
          if (mode_parts[3] ~ "be") { value="7" }			#
          else if (mode_parts[3] ~ "ax") { value="6" }			#
          else if (mode_parts[3] ~ "ac") { value="5" }			#
          else if (mode_parts[3] ~ "n") { value="4" }			#
          else if (mode_parts[3] ~ "g") { value="3" }			#
          else if (mode_parts[3] ~ "11a") { value="2" }			#
          else if (mode_parts[3] ~ "11b") { value="1" }			#
          else { value="unknown" }					#
          exit								#
        }								#
      }									#
    }									#
  } END {								#
    printf "%s", value							#
  }'
  return $?
}

# Get WLAN Band of the interface.
# require get_wlan_info() data from STDIN.
# get_wlan_band
function get_wlan_band() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_wlan_band <ifname>." 1>&2
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
        if (match(line,/^ +Channel:.*$/)) {				#
          split(line,channel_parts," ")					#
          value=channel_parts[3]					#
          gsub(/[^0-9.]/,"",value)					#
          exit								#
        }								#
      }									#
    }									#
  } END {								#
    printf "%d", value							#
  }'
  return $?
}

# Get WLAN Channel of the interface.
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
          split(line,channel_parts," ")					#
          value=channel_parts[2]					#
          exit								#
        }								#
      }									#
    }									#
  } END {								#
    printf "%d", value							#
  }'
  return $?
}

# Get WLAN Channel BandWidth of the interface.
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
          split(line,channel_parts," ")					#
          value=channel_parts[4]					#
          gsub(/[^0-9]/,"",value)					#
          exit								#
        }								#
      }									#
    }									#
  } END {								#
    printf "%d", value							#
  }'
  return $?
}

# Get WLAN RSSI of the interface.
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
          split(line,signal_parts," ")					#
          value=signal_parts[4]						#
          exit								#
        }								#
      }									#
    }									#
  } END {								#
    printf "%d", value							#
  }'
  return $?
}

# Get WLAN Noise of the interface.
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
          split(line,noise_parts," ")					#
          value=noise_parts[7]						#
          exit								#
        }								#
      }									#
    }									#
  } END {								#
    printf "%d", value							#
  }'
  return $?
}

# Get WLAN Link Quality of the interface.
# get_wlan_quality <ifname>
function get_wlan_quality() {
  :
  #TBD
}

# Get the list of access points in range of the interface.
# require get_wlan_info() data from STDIN.
# get_wlan_environment <ifname>
function get_wlan_environment() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_wlan_environment <ifname>." 1>&2
    return 1
  fi
  echo "BSSID,SSID,Mode,Band,Channel,Bandwidth,Security,RSSI"
  awk -v ifname="$1" 'BEGIN {						#
    find=0								#
    OFS=","								#
    bssid="unknown"							#
    ssid=""								#
    mode=""								#
    band=""								#
    channel=""								#
    width=""								#
    security="Open"							#
    rssi="unknown"							#
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
          split(line,mode_parts," ")					#
          if (mode_parts[3] ~ "be") { mode="7" }			#
          else if (mode_parts[3] ~ "ax") { mode="6" }			#
          else if (mode_parts[3] ~ "ac") { mode="5" }			#
          else if (mode_parts[3] ~ "n") { mode="4" }			#
          else if (mode_parts[3] ~ "g") { mode="3" }			#
          else if (mode_parts[3] ~ "11a") { mode="2" }			#
          else if (mode_parts[3] ~ "11b") { mode="1" }			#
          else { mode="unknown" }					#
        } else if (match(line,/^ +Channel:.*$/)) {			#
          split(line,channel_parts," ")					#
          channel=channel_parts[2]					#
          band=channel_parts[3]						#
          gsub(/[^0-9.]/,"",band)					#
          width=channel_parts[4]					#
          gsub(/[^0-9]/,"",width)					#
        } else if (match(line,/^ +Security:.*$/)) {			#
          split(line,security_parts,": ")				#
          security=security_parts[2]					#
          print bssid,ssid,mode,band,channel,width,security,rssi	#
          find=3							#
        } else if (match(line,/^ +MAC Address:.*$/)) {			#
          # this area is other interface section			#
          exit								#
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

# Get various WWAN information of the interface.
# require get_wwan_info() data from STDIN.
# get_wwan_value <type> <cat> <name> <pos>
function get_wwan_value() {
  :
  #TBD
}

# Get WWAN modem ID of the interface.
# get_wwan_modemid
function get_wwan_modemid() {
  :
  #TBD
}

# Get WWAN APN of the interface.
# get_wwan_apn
function get_wwan_apn() {
  :
  #TBD
}

# Get WWAN IP type of the interface.
# get_wwan_iptype
function get_wwan_iptype() {
  :
  #TBD
}

# Get WWAN MTU of the interface.
# get_wwan_ifmtu
function get_wwan_ifmtu() {
  :
  #TBD
}

# Get WWAN interface type.
# get_wwan_iftype
function get_wwan_iftype() {
  :
  #TBD
}

# Get WWAN quality of the interface.
# get_wwan_quality
function get_wwan_quality() {
  :
  #TBD
}

# Get WWAN IMEI of the interface.
# get_wwan_imei
function get_wwan_imei() {
  :
  #TBD
}

# Get WWAN operator name of the interface.
# get_wwan_operator
function get_wwan_operator() {
  :
  #TBD
}

# Get WWAN operator ID of the interface.
# get_wwan_mmcmnc
function get_wwan_mmcmnc() {
  :
  #TBD
}

# Get WWAN RSSI of the interface.
# get_wwan_rssi
function get_wwan_rssi() {
  :
  #TBD
}

# Get WWAN RSRQ of the interface.
# get_wwan_rsrq
function get_wwan_rsrq() {
  :
  #TBD
}

# Get WWAN RSRP of the interface.
# get_wwan_rsrp
function get_wwan_rsrp() {
  :
  #TBD
}

# Get WWAN SNR of the interface.
# get_wwan_snir
function get_wwan_snir() {
  :
  #TBD
}

# Get WWAN band of the interface.
# get_wwan_band
function get_wwan_band() {
  :
  #TBD
}

# Get WWAN cell ID of the interface.
# get_wwan_cid
function get_wwan_cid() {
  :
  #TBD
}

# Get WWAN location area code of the interface.
# get_wwan_lac
function get_wwan_lac() {
  :
  #TBD
}

# Get WWAN tracking area code of the interface.
# get_wwan_tac
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

