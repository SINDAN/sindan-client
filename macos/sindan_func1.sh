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

# Get SSID using on the interface.
# get_wlan_ssid <ifname>
function get_wlan_ssid() {
  $CMD_AIRPORT -I							|
  sed -n 's/^.*[^B]SSID: \(.*\).*$/\1/p'
  return $?
}

# Get BSSID using on the interface.
# get_wlan_bssid <ifname>
function get_wlan_bssid() {
  $CMD_AIRPORT -I							|
  sed -n 's/^.*BSSID: \([0-9a-fA-F:]*\).*$/\1/p'			|
  tr "[:upper:]" "[:lower:]" 
  return $?
}

# Get OUI of Access Point using on the interface.
# get_wlan_apoui <ifname>
function get_wlan_apoui() {
  $CMD_AIRPORT -I							|
  sed -n 's/^.*BSSID: \([0-9a-fA-F:]*\).*$/\1/p'			|
  cut -d: -f1-3								|
  tr "[:upper:]" "[:lower:]" 
  return $?
}

# Get channel of WLAN using on the interface.
# get_wlan_channel <ifname>
function get_wlan_channel() {
  $CMD_AIRPORT -I							|
  sed -n 's/^.*channel: \([0-9]*\).*$/\1/p'
  return $?
}

# Get RSSI of WLAN using on the interface.
# get_wlan_rssi <ifname>
function get_wlan_rssi() {
  $CMD_AIRPORT -I							|
  sed -n 's/^.*agrCtlRSSI: \([-0-9]*\).*$/\1/p'
  return $?
}

# Get noise of WLAN using on the interface.
# get_wlan_noise <ifname>
function get_wlan_noise() {
  $CMD_AIRPORT -I							|
  sed -n 's/^.*agrCtlNoise: \([-0-9]*\).*$/\1/p'
  return $?
}

# Get quality of WLAN using on the interface.
# get_wlan_quality <ifname>
function get_wlan_quality() {
  :
  #TBD
}

# Get current bit rate of WLAN using on the interface.
# get_wlan_rate <ifname>
function get_wlan_rate() {
  $CMD_AIRPORT -I							|
  sed -n 's/^.*lastTxRate: \([0-9]*\).*$/\1/p'
  return $?
}

# Get the list of access points in range of the interface.
# get_wlan_environment <ifname>
function get_wlan_environment() {
  $CMD_AIRPORT -s							|
  awk '{printf "%s,%s,%s,%s\n", $1, $2, $3, $4}'
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

