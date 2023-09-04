#!/bin/bash
# sindan.sh
# version 3.0.1
VERSION="3.0.1"

# read configuration file
cd $(dirname $0)
. ./sindan.conf

# read function files
cd $(dirname $0)
. ./sindan_funcb.sh
. ./sindan_func0.sh
. ./sindan_func1.sh
. ./sindan_func2.sh
. ./sindan_func3.sh
. ./sindan_func4.sh
. ./sindan_func5.sh
. ./sindan_func6.sh

#
# main
#

####################
## Preparation

# Check parameters
for param in PIDFILE MAX_RETRY IFTYPE PING_SRVS PING6_SRVS FQDNS GPDNS4 GPDNS6 V4WEB_SRVS V6WEB_SRVS V4SSH_SRVS V6SSH_SRVS DEVNAME; do
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

# Set PID file
trap 'rm -f $PIDFILE; exit 0' INT EXIT

if [ -e "$PIDFILE" ]; then
  ppid=$(cat "$PIDFILE")
  if kill -0 "$ppid" > /dev/null 2>&1; then
    kill -9 -"$ppid"
#    kill -9 `ps ho pid --ppid=$ppid`
    rm -f "$PIDFILE"
    echo "Warning: killed the previous job which was running."
  else
    echo "Warning: previous check appears to have not finished correctly."
  fi
fi
echo $$ >"$PIDFILE"

# Make log directory
mkdir -p log
mkdir -p trace-json

# Generate UUID
uuid=$(generate_uuid)
UUID=$uuid

####################
## Phase 0
echo "Phase 0: Hardware Layer checking..."
layer="hardware"

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

# Get ifname
ifname=$(get_ifname "$IFTYPE")

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
  write_json "$layer" "$IFTYPE" ifstatus "$result_phase1" self		\
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
  # Get Wi-Fi SSID
  ssid=$(get_wlan_ssid "$ifname")
  if [ -n "$ssid" ]; then
    write_json "$layer" "$IFTYPE" ssid "$INFO" self "$ssid" 0
  fi
  # Get Wi-Fi BSSID
  bssid=$(get_wlan_bssid "$ifname")
  if [ -n "$bssid" ]; then
    write_json "$layer" "$IFTYPE" bssid "$INFO" self "$bssid" 0
  fi
  # Get Wi-Fi AP's OUI
  wlanapoui=$(get_wlan_apoui "$ifname")
  if [ -n "$wlanapoui" ]; then
    write_json "$layer" "$IFTYPE" wlanapoui "$INFO" self "$wlanapoui" 0
  fi
  # Get Wi-Fi channel
  channel=$(get_wlan_channel "$ifname")
  if [ -n "$channel" ]; then
    write_json "$layer" "$IFTYPE" channel "$INFO" self "$channel" 0
  fi
  # Get Wi-Fi RSSI
  rssi=$(get_wlan_rssi "$ifname")
  if [ -n "$rssi" ]; then
    write_json "$layer" "$IFTYPE" rssi "$INFO" self "$rssi" 0
  fi
  # Get Wi-Fi noise
  noise=$(get_wlan_noise "$ifname")
  if [ -n "$noise" ]; then
    write_json "$layer" "$IFTYPE" noise "$INFO" self "$noise" 0
  fi
  # Get Wi-Fi quality
  quality=$(get_wlan_quality "$ifname")
  if [ -n "$quality" ]; then
    write_json "$layer" "$IFTYPE" quality "$INFO" self "$quality" 0
  fi
  # Get Wi-Fi rate
  rate=$(get_wlan_rate "$ifname")
  if [ -n "$rate" ]; then
    write_json "$layer" "$IFTYPE" rate "$INFO" self "$rate" 0
  fi
  # Get Wi-Fi environment
  environment=$(get_wlan_environment "$ifname")
  if [ -n "$environment" ]; then
    write_json "$layer" "$IFTYPE" environment "$INFO" self		\
               "$environment" 0
  fi
elif [ "$IFTYPE" = "WWAN" ]; then
  # Get WWAN infomation
  wwan_info=$(get_wwan_info "$ifname")
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
      ifmtu=$(get_ifmtu "$ifname")
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
  media=$(get_mediatype "$ifname")
  if [ -n "$media" ]; then
    write_json "$layer" "$IFTYPE" media "$INFO" self "$media" 0
  fi
fi

# Report phase 1 results
if [ "$VERBOSE" = "yes" ]; then
  echo " datalink information:"
  echo "  datalink status: $result_phase1"
  echo "  type: $IFTYPE, ifname: $ifname"
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
  v4ifconf=$(get_v4ifconf "$ifname" "$IFTYPE")
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
      if v4autoconf=$(check_v4autoconf "$ifname" "$v4ifconf"); then
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
  v4addr=$(get_v4addr "$ifname")
  if [ -n "$v4addr" ]; then
    write_json "$layer" IPv4 v4addr "$INFO" self "$v4addr" 0
  fi

  # Get IPv4 netmask
  netmask=$(get_netmask "$ifname")
  if [ -n "$netmask" ]; then
    write_json "$layer" IPv4 netmask "$INFO" self "$netmask" 0
  fi

  # Get IPv4 routers
  v4routers=$(get_v4routers "$ifname")
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
    echo "  IPv4 routers: $v4routers"
    echo "  IPv4 namesrv: $v4nameservers"
  fi
fi

## IPv6
if [ "$EXCL_IPv6" != "yes" ]; then
  # Get IPv6 I/F configurations
  v6ifconf=$(get_v6ifconf "$ifname")
  if [ -n "$v6ifconf" ]; then
    write_json "$layer" IPv6 v6ifconf "$INFO" self "$v6ifconf" 0
  fi

  # Get IPv6 linklocal address
  v6lladdr=$(get_v6lladdr "$ifname")
  if [ -n "$v6lladdr" ]; then
    write_json "$layer" IPv6 v6lladdr "$INFO" self "$v6lladdr" 0
  fi

  # Report phase 2 results (IPv6)
  if [ "$VERBOSE" = "yes" ]; then
    echo "  IPv6 conf: $v6ifconf"
    echo "  IPv6 lladdr: $v6lladdr"
  fi

  # Get IPv6 RA infomation
  ra_info=$(get_ra_info "$ifname")

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
      write_json "$layer" IPv6 v6autoconf "$result_phase2_2" self	\
                 "$v6autoconf" 0
      # Get IPv6 address
      v6addrs=$(get_v6addrs "$ifname" "")
      if [ -n "$v6addr" ]; then
        write_json "$layer" IPv6 v6addrs "$INFO" "$v6ifconf" "$v6addrs" 0
      fi
      s_count=0
      for addr in $(echo "$v6addrs" | sed 's/,/ /g'); do
        # Get IPv6 prefix length
        pref_len=$(get_prefixlen_from_ifinfo "$ifname" "$addr")
        if [ -n "$pref_len" ]; then
          write_json "$layer" IPv6 pref_len "$INFO" "$addr" "$pref_len"	\
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
            v6addrs=$(get_v6addrs "$ifname" "$pref")
            if v6autoconf=$(check_v6autoconf "$ifname" "$v6ifconf"	\
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
    v6routers=$(get_v6routers "$ifname")
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
      echo "  IPv6 namesrv: $v6nameservers"
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
if [ "$v4addr_type" = "private" ] || [ "$v4addr_type" = "global" ]; then
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
  
    for addr in $(echo "$v6addrs" | sed 's/,/ /g'); do
      if [ "$MODE" = "client" ]; then
        # Check path MTU to extarnal IPv6 servers
        cmdset_pmtud "$layer" 6 srv "$target" "$ifmtu" "$count" "$addr" &
      fi
    done

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

if [ "$v4addr_type" = "private" ] || [ "$v4addr_type" = "global" ]; then
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

if [ "$v4addr_type" = "private" ] || [ "$v4addr_type" = "global" ]; then
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
if [ "$v4addr_type" = "private" ] || [ "$v4addr_type" = "global" ] ||	\
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
  write_json_campaign "$uuid" "$mac_addr" "$os" "$IFTYPE" "$ssid"
elif [ "$IFTYPE" = "WWAN" ]; then
  write_json_campaign "$uuid" "$wwan_imei" "$os" "$IFTYPE" "$wwan_apn"
else
  write_json_campaign "$uuid" "$mac_addr" "$os" "$IFTYPE" none
fi

# remove PID file
rm -f "$PIDFILE"

echo " done."

exit 0

