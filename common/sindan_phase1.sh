#!/bin/bash
# sindan_phase1.sh
#
# Phase 1 (Datalink Layer checking) of sindan.sh, which is the same on all
# platforms. The functions of sindan_func1.sh take the same arguments on
# every platform and may ignore the ones they do not need. The functions that
# a platform does not support print nothing, so no record is written:
# get_wlan_nss and get_wlan_quality on macOS, get_wwan_info on macOS.
# WLAN_ENVIRONMENT_FIRST, set by sindan.sh, selects when the WLAN environment
# is taken. This file is read by sindan.sh after Phase 0.

####################
## Phase 1
echo "Phase 1: Datalink Layer checking..."
layer="datalink"

# Get ifname
ifname=$(get_ifname "$IFTYPE")

# The WLAN environment is taken before the interface is restarted on Linux
# (WLAN_ENVIRONMENT_FIRST=yes) and from the WLAN information on macOS.
if [ "$IFTYPE" = "Wi-Fi" ] && [ "$WLAN_ENVIRONMENT_FIRST" = "yes" ]; then
  # Get WLAN environment
  wlan_environment=$(get_wlan_environment "$ifname")
  if [ -n "$wlan_environment" ]; then
    write_json "$layer" "$IFTYPE" wlan_environment "$INFO" self \
               "$wlan_environment" 0
  fi
fi

# Down, Up interface
if [ "$RECONNECT" = "yes" ]; then
  # Down target interface
  if [ "$VERBOSE" = "yes" ]; then
    echo " interface:$ifname down"
  fi
  do_ifdown "$ifname" "$IFTYPE"
  sleep 2

  # Start target interface
  if [ "$VERBOSE" = "yes" ]; then
    echo " interface:$ifname up"
  fi
  do_ifup "$ifname" "$IFTYPE"
  sleep 5
fi

# Get iftype
write_json "$layer" common iftype "$INFO" self "$IFTYPE" 0

# Check I/F status
result_phase1=$FAIL
rcount=0
while [ "$rcount" -lt "$MAX_RETRY" ]; do
  if ifstatus=$(get_ifstatus "$ifname" "$IFTYPE"); then
    result_phase1=$SUCCESS
    break
  fi
  sleep 5
  rcount=$(( rcount + 1 ))
done
if [ -n "$ifstatus" ]; then
  write_json "$layer" "$IFTYPE" ifstatus "$result_phase1" self \
             "$ifstatus" 0
fi

if [ "$IFTYPE" != "WWAN" ]; then
  # Get MAC address
  mac_addr=$(get_macaddr "$ifname")

  # Get ifmtu
  ifmtu=$(get_ifmtu "$ifname")
  if [ -n "$ifmtu" ]; then
    write_json "$layer" "$IFTYPE" ifmtu "$INFO" self "$ifmtu" 0
  fi
fi

#
if [ "$IFTYPE" = "Wi-Fi" ]; then
  # Get WLAN information
  wlan_info=$(get_wlan_info "$ifname")

  # Get WLAN ssid
  wlan_ssid=$(get_wlan_ssid "$ifname" <<< "$wlan_info")
  if [ -n "$wlan_ssid" ]; then
    write_json "$layer" "$IFTYPE" wlan_ssid "$INFO" self "$wlan_ssid" 0
  fi
  # Get WLAN bssid
  wlan_bssid=$(get_wlan_bssid "$ifname" <<< "$wlan_info")
  if [ -n "$wlan_bssid" ]; then
    write_json "$layer" "$IFTYPE" wlan_bssid "$INFO" self "$wlan_bssid" 0
  fi
  # Get WLAN tx rate
  wlan_rate=$(get_wlan_rate "$ifname" <<< "$wlan_info")
  if [ -n "$wlan_rate" ]; then
    write_json "$layer" "$IFTYPE" wlan_rate "$INFO" self "$wlan_rate" 0
  fi
  # Get WLAN tx mcs index
  wlan_mcs=$(get_wlan_mcs "$ifname" <<< "$wlan_info")
  if [ -n "$wlan_mcs" ]; then
    write_json "$layer" "$IFTYPE" wlan_mcs "$INFO" self "$wlan_mcs" 0
  fi
  # Get WLAN tx nss
  wlan_nss=$(get_wlan_nss "$ifname" <<< "$wlan_info")
  if [ -n "$wlan_nss" ]; then
    write_json "$layer" "$IFTYPE" wlan_nss "$INFO" self "$wlan_nss" 0
  fi
  # Get WLAN mode
  wlan_mode=$(get_wlan_mode "$ifname" <<< "$wlan_info")
  if [ -n "$wlan_mode" ]; then
    write_json "$layer" "$IFTYPE" wlan_mode "$INFO" self "$wlan_mode" 0
  fi
  # Get WLAN band
  wlan_band=$(get_wlan_band "$ifname" <<< "$wlan_info")
  if [ -n "$wlan_band" ]; then
    write_json "$layer" "$IFTYPE" wlan_band "$INFO" self "$wlan_band" 0
  fi
  # Get WLAN channel
  wlan_channel=$(get_wlan_channel "$ifname" <<< "$wlan_info")
  if [ -n "$wlan_channel" ]; then
    write_json "$layer" "$IFTYPE" wlan_channel "$INFO" self "$wlan_channel" 0
  fi
  # Get WLAN channel bandwidth
  wlan_chband=$(get_wlan_chband "$ifname" <<< "$wlan_info")
  if [ -n "$wlan_chband" ]; then
    write_json "$layer" "$IFTYPE" wlan_chband "$INFO" self "$wlan_chband" 0
  fi
  # Get WLAN rssi
  wlan_rssi=$(get_wlan_rssi "$ifname" <<< "$wlan_info")
  if [ -n "$wlan_rssi" ]; then
    write_json "$layer" "$IFTYPE" wlan_rssi "$INFO" self "$wlan_rssi" 0
  fi
  # Get WLAN noise
  wlan_noise=$(get_wlan_noise "$ifname" <<< "$wlan_info")
  if [ -n "$wlan_noise" ]; then
    write_json "$layer" "$IFTYPE" wlan_noise "$INFO" self "$wlan_noise" 0
  fi
  # Get WLAN quality
  wlan_quality=$(get_wlan_quality "$ifname" <<< "$wlan_info")
  if [ -n "$wlan_quality" ]; then
    write_json "$layer" "$IFTYPE" wlan_quality "$INFO" self "$wlan_quality" 0
  fi
  if [ "$WLAN_ENVIRONMENT_FIRST" != "yes" ]; then
    # Get WLAN environment
    wlan_environment=$(get_wlan_environment "$ifname" <<< "$wlan_info")
    if [ -n "$wlan_environment" ]; then
      write_json "$layer" "$IFTYPE" wlan_environment "$INFO" self \
                 "$wlan_environment" 0
    fi
  fi
elif [ "$IFTYPE" = "WWAN" ]; then
  # Get WWAN infomation
  wwan_info=$(get_wwan_info "$ifname")
  if [ -n "$wwan_info" ]; then
    write_json "$layer" "$IFTYPE" wwan_info "$INFO" self "$wwan_info" 0

    # Get IMEI
    wwan_imei=$(echo "$wwan_info" | get_wwan_imei)
    # Get WWAN environment
    wwan_modemid=$(echo "$wwan_info" | get_wwan_modemid)
    wwan_environment=$(get_wwan_environment "$wwan_modemid")
    if [ -n "$wwan_environment" ]; then
      write_json "$layer" "$IFTYPE" wwan_environment "$INFO" self \
                 "$wwan_environment" 0
    fi

    # Get ifmtu
    ifmtu=$(echo "$wwan_info" | get_wwan_ifmtu)
    if [ -n "$ifmtu" ]; then
      write_json "$layer" "$IFTYPE" ifmtu "$INFO" self "$ifmtu" 0
    else
      ifmtu=$(get_ifmtu "$ifname")
      if [ -n "$ifmtu" ]; then
        write_json "$layer" "$IFTYPE" ifmtu "$INFO" self "$ifmtu" 0
      fi
    fi

    # Get WWAN apn
    wwan_apn=$(echo "$wwan_info" | get_wwan_apn)
    if [ -n "$wwan_apn" ]; then
      write_json "$layer" "$IFTYPE" wwan_apn "$INFO" self "$wwan_apn" 0
    fi
    # Get WWAN rat
    wwan_rat=$(echo "$wwan_info" | get_wwan_rat)
    if [ -n "$wwan_rat" ]; then
      write_json "$layer" "$IFTYPE" wwan_rat "$INFO" self "$wwan_rat" 0
    fi
    # Get WWAN quality
    wwan_quality=$(echo "$wwan_info" | get_wwan_quality)
    if [ -n "$wwan_quality" ]; then
      write_json "$layer" "$IFTYPE" wwan_quality "$INFO" self "$wwan_quality" 0
    fi
    # Get WWAN operator
    wwan_operator=$(echo "$wwan_info" | get_wwan_operator)
    if [ -n "$wwan_operator" ]; then
      write_json "$layer" "$IFTYPE" wwan_operator "$INFO" self "$wwan_operator" 0
    fi
    # Get WWAN mcc/mnc
    wwan_mccmnc=$(echo "$wwan_info" | get_wwan_mccmnc)
    if [ -n "$wwan_mccmnc" ]; then
      write_json "$layer" "$IFTYPE" wwan_mccmnc "$INFO" self "$wwan_mccmnc" 0
    fi
    # Get WWAN iptype
    wwan_iptype=$(echo "$wwan_info" | get_wwan_iptype)
    if [ -n "$wwan_iptype" ]; then
      write_json "$layer" "$IFTYPE" wwan_iptype "$INFO" self "$wwan_iptype" 0
    fi
    # Get WWAN rssi
    wwan_rssi=$(echo "$wwan_info" | get_wwan_rssi)
    if [ -n "$wwan_rssi" ]; then
      write_json "$layer" "$IFTYPE" wwan_rssi "$INFO" self "$wwan_rssi" 0
    fi
    # Get WWAN rsrq
    wwan_rsrq=$(echo "$wwan_info" | get_wwan_rsrq)
    if [ -n "$wwan_rsrq" ]; then
      write_json "$layer" "$IFTYPE" wwan_rsrq "$INFO" self "$wwan_rsrq" 0
    fi
    # Get WWAN rsrp
    wwan_rsrp=$(echo "$wwan_info" | get_wwan_rsrp)
    if [ -n "$wwan_rsrp" ]; then
      write_json "$layer" "$IFTYPE" wwan_rsrp "$INFO" self "$wwan_rsrp" 0
    fi
    # Get WWAN snir
    wwan_snir=$(echo "$wwan_info" | get_wwan_snir)
    if [ -n "$wwan_snir" ]; then
      write_json "$layer" "$IFTYPE" wwan_snir "$INFO" self "$wwan_snir" 0
    fi
    # Get WWAN cid
    wwan_cid=$(echo "$wwan_info" | get_wwan_cid)
    if [ -n "$wwan_cid" ]; then
      write_json "$layer" "$IFTYPE" wwan_cid "$INFO" self "$wwan_cid" 0
    fi
    # Get WWAN lac
    wwan_lac=$(echo "$wwan_info" | get_wwan_lac)
    if [ -n "$wwan_lac" ]; then
      write_json "$layer" "$IFTYPE" wwan_lac "$INFO" self "$wwan_lac" 0
    fi
    # Get WWAN tac
    wwan_tac=$(echo "$wwan_info" | get_wwan_tac)
    if [ -n "$wwan_tac" ]; then
      write_json "$layer" "$IFTYPE" wwan_tac "$INFO" self "$wwan_tac" 0
    fi
  fi
else
  # Get media type
  ether_media=$(get_ether_mediatype "$ifname")
  if [ -n "$ether_media" ]; then
    write_json "$layer" "$IFTYPE" ether_media "$INFO" self "$ether_media" 0
  fi
fi

# Report phase 1 results
if [ "$VERBOSE" = "yes" ]; then
  echo " datalink information:"
  echo "  datalink status: $result_phase1"
  echo "  type: $IFTYPE, ifname: $ifname"
  echo "  status: $ifstatus, mtu: $ifmtu byte"
  if [ "$IFTYPE" = "Wi-Fi" ]; then
    echo "  ssid: $wlan_ssid, band: $wlan_band GHz, ch: $wlan_channel ($wlan_chband MHz)"
    echo "  mode: Wi-Fi $wlan_mode, mcs index: $wlan_mcs, nss: $wlan_nss, rate: $wlan_rate Mbps"
    echo "  bssid: $wlan_bssid"
    echo "  rssi: $wlan_rssi dBm, noise: $wlan_noise dBm, quality: $wlan_quality"
    echo "  environment:"
    echo "$wlan_environment"
  elif [ "$IFTYPE" = "WWAN" ]; then
    if [ -z "$wwan_info" ]; then
      # Not supported on macOS, or the modem gave no information.
      echo "  WWAN information is not available."
    else
      echo "  apn: $wwan_apn, rat: $wwan_rat, iptype: $wwan_iptype"
      echo "  operator: $wwan_operator, mcc/mnc: $wwan_mccmnc"
      echo "  cid: $wwan_cid, lac: $wwan_lac, tac: $wwan_tac"
      echo "  rssi: $wwan_rssi dBm, rsrq: $wwan_rsrq dB, rsrp: $wwan_rsrp dBm, s/n: $wwan_snir dB"
      echo "  quality: $wwan_quality %"
      echo "  environment:"
      echo "$wwan_environment"
    fi
  else
    echo "  media: $ether_media"
  fi
fi

echo " done."
