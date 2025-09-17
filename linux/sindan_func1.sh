#!/bin/bash
# sindan_func1.sh

## Datalink Layer functions

# Get the interface name.
function get_ifname() {
  echo "$DEVNAME"
  return $?
}

# Stop the interface.
# do_ifdown <ifname> <iftype>
function do_ifdown() {
  if [ $# -ne 2 ]; then
    echo "ERROR: do_ifdown <ifname> <iftype>." 1>&2
    return 1
  fi
  local wwan_dev
  if which nmcli > /dev/null 2>&1 &&
     [ "$(nmcli networking)" = "enabled" ]; then
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
  local wwan_dev
  if which nmcli > /dev/null 2>&1 &&
     [ "$(nmcli networking)" = "enabled" ]; then
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
  local status path modem_info
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

# Get ethernet media type of the interface.
# get_ether_mediatype <ifname>
function get_ether_mediatype() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_ether_mediatype <ifname>." 1>&2
    return 1
  fi
  local speed duplex
  speed=$(cat /sys/class/net/"$1"/speed)
  duplex=$(cat /sys/class/net/"$1"/duplex)
  echo "${speed}_${duplex}"
  return $?
}

# Get the WLAN interface information.
# get_wlan_info
function get_wlan_info() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_wlan_info <ifname>." 1>&2
    return 1
  fi
  iw dev "$1" info
  MAX_RETRIES=15
  RETRY_INTERVAL=1                                                      
  for ((i=1; i<=MAX_RETRIES; i++)); do
    output=$(iw dev "$1" link)
    # Check if “tx bitrate:” data is included.
    if echo "$output" | grep -q "tx bitrate:"; then
      echo "$output"
      exit 0
    fi
    sleep $RETRY_INTERVAL
  done
  return $?
} 

# Get WLAN SSID of the interface.
# require get_wlan_info() data from STDIN.
# get_wlan_ssid
function get_wlan_ssid() {
  grep "ssid "								|
  awk '{$1=""; print $0}'						|
  sed 's/^ *//'
  return $?
}

# Get WLAN BSSID of the interface.
# require get_wlan_info() data from STDIN.
# get_wlan_bssid
function get_wlan_bssid() {
  grep "addr "								|
  awk '{$1=""; print $0}'						|
  sed 's/^ *//'								|
  tr "[:upper:]" "[:lower:]"
  return $?
}

# Get WLAN Data Rate (Tx) of the interface.
# require get_wlan_info() data from STDIN.
# get_wlan_rate
function get_wlan_rate() {
  grep "tx bitrate: "							|
  awk '{print $3}'
  return $?
}

# Get WLAN MCS Index (Tx) of the interface.
# require get_wlan_info() data from STDIN.
# get_wlan_mcs
function get_wlan_mcs() {
  grep "tx bitrate: "							|
  grep -oE "(MCS) [0-9]*"						|
  awk '{print $2}'
  return $?
}

# Get Number of WLAN Spatial Stream (Tx) of the interface.
# require get_wlan_info() data from STDIN.
# get_wlan_nss
function get_wlan_nss() {
  grep "tx bitrate: "							|
  grep -oE "(NSS) [0-9]*"						|
  awk '{print $2}'
  return $?
}

# Get WLAN PHY Mode of the interface.
# require get_wlan_info() data from STDIN.
# get_wlan_mode
function get_wlan_mode() {
  local iw_data tx_bitrate freq
  iw_data="$(cat)"
  tx_bitrate=$(echo "$iw_data"						|
               grep "tx bitrate:"					|
               awk '{print $3, $4, $5, $6, $7}')
  freq=$(echo "$iw_data"						|
         grep "freq:"							|
         awk '{print $2}')

  if [[ $tx_bitrate =~ "EHT-MCS" ]]; then
    echo "7"
  elif [[ $tx_bitrate =~ "HE-MCS" ]]; then
    if [[ $freq -ge 5180 && $freq -le 5825 ]]; then
      echo "6"
    elif [[ $freq -ge 5955 && $freq -le 7115 ]]; then
      echo "6E"
    fi
  elif [[ $tx_bitrate =~ "VHT-MCS" ]]; then
    echo "5"
  elif [[ $tx_bitrate =~ "HT-MCS" ||
          $tx_bitrate =~ "MCS" ]]; then
    echo "4"
  elif [[ $tx_bitrate =~ "54.0 MBit/s" ||
          $tx_bitrate =~ "48.0 MBit/s" ||
          $tx_bitrate =~ "36.0 MBit/s" ||
          $tx_bitrate =~ "24.0 MBit/s" ||
          $tx_bitrate =~ "18.0 MBit/s" ||
          $tx_bitrate =~ "12.0 MBit/s" ||
          $tx_bitrate =~ "9.0 MBit/s" ||
          $tx_bitrate =~ "6.0 MBit/s" ]]; then
    echo "3"
  elif [[ $tx_bitrate =~ "11.0 MBit/s" ||
          $tx_bitrate =~ "5.5 MBit/s" ]]; then
    echo "2"
  elif [[ $tx_bitrate =~ "2.0 MBit/s" ||
          $tx_bitrate =~ "1.0 MBit/s" ]]; then
    echo "1"
  fi
  return $?
}

# Get WLAN Band of the interface.
# require get_wlan_info() data from STDIN.
# get_wlan_band
function get_wlan_band() {
  local freq
  freq=$(grep -oE "(freq:) [0-9]*" | awk '{print $2}')
  if [[ $freq -ge 2412 && $freq -le 2484 ]]; then
    echo "2.4"
  elif [[ $freq -ge 5180 && $freq -le 5825 ]]; then
    echo "5"
  elif [[ $freq -ge 5955 && $freq -le 7115 ]]; then
    echo "6"
  fi
  return $?
}

# Get WLAN Channel of the interface.
# require get_wlan_info() data from STDIN.
# get_wlan_channel
function get_wlan_channel() {
  grep -oE "(channel) [0-9]*"						|
  awk '{print $2}'
  return $?
}

# Get WLAN Channel BandWidth of the interface.
# require get_wlan_info() data from STDIN.
# get_wlan_chband
function get_wlan_chband() {
  grep "channel "							|
  grep -oE "(width:) [0-9]*"						|
  awk '{print $2}'
  return $?
}

# Get WLAN RSSI of the interface.
# get_wlan_rssi <ifname>
function get_wlan_rssi() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_wlan_rssi <ifname>." 1>&2
    return 1
  fi
  grep "$1" /proc/net/wireless						|
  awk '{print $4}'							|
  sed 's/\.$//'
  return $?
}

# Get WLAN Noise of the interface.
# get_wlan_noise <ifname>
function get_wlan_noise() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_wlan_noise <ifname>." 1>&2
    return 1
  fi
  grep "$1" /proc/net/wireless						|
  awk '{print $5}'							|
  sed 's/\.$//'
  return $?
}

# Get WLAN Link Quality of the interface.
# get_wlan_quality
function get_wlan_quality() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_wlan_quality <ifname>." 1>&2
    return 1
  fi
  grep "$1" /proc/net/wireless						|
  awk '{print $3}'							|
  sed 's/\.$//'
  return $?
}

# Get the list of WLAN access points in range of the interface.
# get_wlan_environment <ifname>
function get_wlan_environment() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_wlan_environment <ifname>." 1>&2
    return 1
  fi
  echo "BSSID,SSID,Mode,Band,Channel,Bandwidth,Security,RSSI"
  iw dev "$1" scan                                                      |
  awk 'BEGIN {
    bssid="";
    ssid="";
    mode="";
    band="";
    channel="";
    width="";
    security="Open";
    rssi="";
  }
  /^BSS / {
    if (bssid != "") {
      print bssid","ssid","mode","band","channel","width","security","rssi;
    }
    split($2,bssid_parts,"(");
    bssid=bssid_parts[1];
    ssid="";
    mode="";
    band="";
    channel="";
    width="";
    security="Open";
    rssi="";
  }
  /SSID:/ {
    if (ssid == "") {
      $1="";
      ssid=substr($0,2);
    }
  }
  /freq:/ {
    freq=$2;
    if (freq >= 2400 && freq < 2500) {
      band="2.4G";
      ch=int((freq - 2407) / 5);
    } else if (freq >= 5000 && freq < 6000) {
      band="5G";
      ch=int((freq - 5000) / 5);
    } else if (freq >= 5925 && freq <= 7125) {
      band="6G";
      ch=int((freq - 5950) / 5);
    } else {
      band="Unknown";
    }
    if (channel == "") {
      channel=ch;
    }
  }
  /signal:/ {
    rssi=$2;
  }
  /DS Parameter set: channel / {
    channel=$5;
  }
  /STA channel width: / {
    width=$5;
  }
  /channel width: / {
    split($5,width_parts,"(");
    width=width_parts[2];
  }
  /Authentication suites: / {
    split($0,suite_parts,": ");
    suite=suite_parts[2];
    if (suite == "PSK") {
      security="WPA2-Personal";
    } else if (suite == "PSK SAE") {
      security="WPA2/WPA3-Personal";
    } else if (suite == "SAE") {
      security="WPA3-Personal";
    } else if (suite == "IEEE 802.1X") {
      security="WPA2-Enterprise";
    }
  }
  /WPA:/ {
     if (security == "Open") security="WPA";
  }
  /WEP/ {
     security="WEP";
  }
  /HT / {
    mode="4";
  }
  /VHT / {
    mode="5";
  }
  /HE / {
    if (band == "6G") {
      mode="6E";
    } else {
      mode="6";
    }
  }
  /EHT / {
    mode="7";
  }
  /rate:/ {
    if (band == "2.4G" && $2 <= 11) {
      mode="1";
    } else if (band == "5G" && $2 <= 54) {
      mode="2";
    } else if (band == "2.4G" && $2 <= 54) {
      mode="3";
    }
  }
  END {
    if (bssid != "") {
      print bssid","ssid","mode","band","channel","width","security","rssi;
    }
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
  local modem_info bearer_info signal_info threegpp_info
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

# Get various WWAN information of the interface.
# require get_wwan_info() data from STDIN.
# get_wwan_value <type> <cat> <name> <pos>
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

# Get WWAN modem ID of the interface.
# get_wwan_modemid
function get_wwan_modemid() {
  get_wwan_value 'MODEM INFO:' General 'dbus path:' 4
  return $?
}

# Get WWAN APN (Access Point Name) of the interface.
# get_wwan_apn
function get_wwan_apn() {
  get_wwan_value 'BEARER INFO:' Properties 'apn:' 3
  return $?
}

# Get WWAN IP type of the interface.
# get_wwan_iptype
function get_wwan_iptype() {
  get_wwan_value 'BEARER INFO:' Properties 'ip type:' 4
  return $?
}

# Get WWAN MTU of the interface.
# get_wwan_ifmtu
function get_wwan_ifmtu() {
  get_wwan_value 'BEARER INFO:' 'IPv4 configuration' mtu: 3
  return $?
}

# Get WWAN RAT (Radio Access Technology) of the interface.
# get_wwan_rat
function get_wwan_rat() {
  get_wwan_value 'MODEM INFO:' Status 'access tech:' 4
  return $?
}

# Get WWAN signal quality of the interface.
# get_wwan_quality
function get_wwan_quality() {
  get_wwan_value 'MODEM INFO:' Status 'signal quality:' 4		|
  sed 's/%//'
  return $?
}

# Get WWAN IMEI (International Mobile Equipment Identity) of the interface.
# get_wwan_imei
function get_wwan_imei() {
  get_wwan_value 'MODEM INFO:' 3GPP imei: 3
  return $?
}

# Get WWAN operator name of the interface.
# get_wwan_operator
function get_wwan_operator() {
  get_wwan_value 'MODEM INFO:' 3GPP 'operator name:' 4
  return $?
}

# Get WWAN operator ID (MCC/MNC) of the interface.
# get_wwan_mccmnc
function get_wwan_mccmnc() {
  get_wwan_value 'MODEM INFO:' 3GPP 'operator id:' 4
  return $?
}

# Get WWAN RSSI of the interface.
# get_wwan_rssi
function get_wwan_rssi() {
  get_wwan_value 'SIGNAL INFO:' LTE 'rssi:' 3
  return $?
}

# Get WWAN RSRQ of the interface.
# get_wwan_rsrq
function get_wwan_rsrq() {
  get_wwan_value 'SIGNAL INFO:' LTE 'rsrq:' 3
  return $?
}

# Get WWAN RSRP of the interface.
# get_wwan_rsrp
function get_wwan_rsrp() {
  get_wwan_value 'SIGNAL INFO:' LTE 'rsrp:' 3
  return $?
}

# Get WWAN SNR of the interface.
# get_wwan_snir
function get_wwan_snir() {
  get_wwan_value 'SIGNAL INFO:' LTE 's/n:' 3
  return $?
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
  get_wwan_value '3GPP INFO:' 3GPP 'cell id:' 4
  return $?
}

# Get WWAN location area code of the interface.
# get_wwan_lac
function get_wwan_lac() {
  get_wwan_value '3GPP INFO:' 3GPP 'location area code:' 5
  return $?
}

# Get WWAN tracking area code of the interface.
# get_wwan_tac
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
  for path in $(mmcli -L | awk '{print $1}' | tr '\n' ' '); do
    mmcli -m $path --3gpp-scan --timeout=60				|
    sed -n 's/.*\([0-9]\{3\}\)\([0-9]\{2\}\) - \(.*\) (\(.*\), \(.*\))/\1,\2,\3,\4,\5/p'
  done
  return $?
}

