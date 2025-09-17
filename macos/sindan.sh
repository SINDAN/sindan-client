#!/bin/bash
# sindan.sh
# version 6
VERSION="6.0.1"

# read configuration file
cd $(dirname $0)
source sindan.conf

# read function files
cd $(dirname $0)
source sindan_funcb.sh
source sindan_func0.sh
source sindan_func1.sh
source sindan_func2.sh
source sindan_func3.sh
source sindan_func4.sh
source sindan_func5.sh
source sindan_func6.sh

#
# main
#

####################
## Preparation

# Check parameters
for param in PIDFILE MAX_RETRY IFTYPE PING4_SRVS PING6_SRVS FQDNS PDNS4_SRVS PDNS6_SRVS WEB4_SRVS WEB6_SRVS SSH4_SRVS SSH6_SRVS; do
  if [ -z $(eval echo '$'$param) ]; then
    echo "ERROR: $param is null in configration file." 1>&2
    exit 1
  fi
done

# Check commands
for cmd in gtimeout; do
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
    rm -f "$PIDFILE"
    echo "Warning: killed the previous job which was running."
  else
    echo "Warning: previous check appears to have not finished correctly."
  fi
fi
echo $$ >"$PIDFILE"

# Make log directory
mkdir -p log

# Generate UUID
uuid=$(generate_uuid)
UUID=$uuid

####################
## Phase 0
echo "Phase 0: Hardware Layer checking..."
layer="hardware"

# Get OS version
os_info=$(get_os_info)

# Get Host name
hostname=$(get_hostname)

# Get hardware information
hw_info=$(get_hw_info)
if [ -n "$hw_info" ]; then
  write_json "$layer" common hw_info "$INFO" self "$hw_info" 0
fi

## Get CPU frequency
#cpu_freq=$(get_cpu_freq)
#if [ -n "$cpu_freq" ]; then
#  write_json "$layer" common cpu_freq "$INFO" self "$cpu_freq" 0
#fi

## Get CPU voltage
#cpu_volt=$(get_cpu_volt)
#if [ -n "$cpu_volt" ]; then
#  write_json "$layer" common cpu_volt "$INFO" self "$cpu_volt" 0
#fi

## Get CPU temperature
#cpu_temp=$(get_cpu_temp)
#if [ -n "$cpu_temp" ]; then
#  write_json "$layer" common cpu_temp "$INFO" self "$cpu_temp" 0
#fi

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
  echo "  os_info: $os_info"
  echo "  hostname: $hostname"
  echo "  hw_info: $hw_info"
#  echo "  cpu (freq: $cpu_freq Hz, volt: $cpu_volt V, temp: $cpu_temp 'C)"
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
  do_ifdown "$ifname"
  sleep 2

  # Start target interface
  if [ "$VERBOSE" = "yes" ]; then
    echo " interface:$ifname up"
  fi
  do_ifup "$ifname"
  sleep 5
fi

# Get iftype
write_json "$layer" common iftype "$INFO" self "$IFTYPE" 0

# Check I/F status
result_phase1=$FAIL
rcount=0
while [ "$rcount" -lt "$MAX_RETRY" ]; do
  if ifstatus=$(get_ifstatus "$ifname"); then
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
  # Get WLAN information
  wlan_info=$(get_wlan_info)

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
  wlan_nss="unsupported"
#  wlan_nss=$(get_wlan_nss "$ifname" <<< "$wlan_info")
#  if [ -n "$wlan_nss" ]; then
#    write_json "$layer" "$IFTYPE" wlan_nss "$INFO" self "$wlan_nss" 0
#  fi
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
  wlan_quality="unsupported"
#  wlan_quality=$(get_wlan_quality "$ifname" <<< "$wlan_info")
#  if [ -n "$quarity" ]; then
#    write_json "$layer" "$IFTYPE" wlan_quality "$INFO" self "$wlan_quality" 0
#  fi
  # Get WLAN environment
  wlan_environment=$(get_wlan_environment "$ifname" <<< "$wlan_info")
  if [ -n "$wlan_environment" ]; then
    write_json "$layer" "$IFTYPE" wlan_environment "$INFO" self		\
               "$wlan_environment" 0
  fi
elif [ "$IFTYPE" = "WWAN" ]; then
  .
  # TBD
else
  # Get media type
  ether_media=$(get_ether_mediatype "$ifname")
  if [ -n "$ether_media" ]; then
    write_json "$layer" "$IFTYPE" ether_media "$INFO" self		\
               "$ether_media" 0
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
    echo "IFTYPE: WWAN is not supported."
    # TBD
#    echo "  apn: $wwan_apn, rat: $wwan_rat, iptype: $wwan_iptype"
#    echo "  operator: $wwan_operator, mcc/mnc: $wwan_mccmnc"
#    echo "  cid: $wwan_cid, lac: $wwan_lac, tac: $wwan_tac"
#    echo "  rssi: $wwan_rssi dBm, rsrq: $wwan_rsrq dB, rsrp:"		\
#         "$wwan_rsrp dBm, s/n: $wwan_snir dB"
#    echo "  quality: $wwan_quality %"
#    echo "  environment:"
#    echo "$wwan_environment"
  else
    echo "  media: $ether_media"
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
  v4ifconf=$(get_v4ifconf "$IFTYPE")
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
  v6ifconf=$(get_v6ifconf "$IFTYPE")
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
    write_json "$layer" RA ra_addrs "$INFO" self "$ra_addrs" 0
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
#        ra_hlim=$(echo "$ra_info" | get_ra_hlim "$saddr")
#        if [ -n "$ra_hlim" ]; then
#          write_json "$layer" RA ra_hlim "$INFO" "$saddr" "$ra_hlim"	\
#                     "$count"
#        fi
#        ra_ltime=$(echo "$ra_info" | get_ra_ltime "$saddr")
#        if [ -n "$ra_ltime" ]; then
#          write_json "$layer" RA ra_ltime "$INFO" "$saddr" "$ra_ltime"	\
#                     "$count"
#        fi
#        ra_reach=$(echo "$ra_info" | get_ra_reach "$saddr")
#        if [ -n "$ra_reach" ]; then
#          write_json "$layer" RA ra_reach "$INFO" "$saddr" "$ra_reach"	\
#                     "$count"
#        fi
#        ra_retrans=$(echo "$ra_info" | get_ra_retrans "$saddr")
#        if [ -n "$ra_retrans" ]; then
#          write_json "$layer" RA ra_retrans "$INFO" "$saddr"		\
#                     "$ra_retrans" "$count"
#        fi

        # Report phase 2 results (IPv6-RA)
        if [ "$VERBOSE" = "yes" ]; then
          echo "  IPv6 RA src addr: $saddr"
          echo "   IPv6 RA flags: $ra_flags"
#          echo "   IPv6 RA hoplimit: $ra_hlim"
#          echo "   IPv6 RA lifetime: $ra_ltime"
#          echo "   IPv6 RA reachable: $ra_reach"
#          echo "   IPv6 RA retransmit: $ra_retrans"
        fi

        # Get IPv6 RA prefixes
        ra_prefs=$(echo "$ra_info" | get_ra_prefs "$saddr" "$ifname")
        if [ -n "$ra_prefs" ]; then
          write_json "$layer" RA ra_prefs "$INFO" "$saddr" "$ra_prefs"	\
                     "$count"
        fi

        s_count=0
        for pref in $(echo "$ra_prefs" | sed 's/,/ /g'); do
          # Get IPv6 RA prefix flags
          ra_pref_flags=$(echo "$ra_info"				|
                        get_ra_pref_flags "$saddr" "$pref" "$ifname")
          if [ -n "$ra_pref_flags" ]; then
            write_json "$layer" RA ra_pref_flags "$INFO"		\
                     "${saddr}-${pref}" "$ra_pref_flags" "$s_count"
          fi

          # Get IPv6 RA prefix parameters
          ra_pref_vltime=$(echo "$ra_info"				|
                       get_ra_pref_vltime "$saddr" "$pref" "$ifname")
          if [ -n "$ra_pref_vltime" ]; then
            write_json "$layer" RA ra_pref_vltime "$INFO"		\
                       "${saddr}-${pref}" "$ra_pref_vltime" "$s_count"
          fi
          ra_pref_pltime=$(echo "$ra_info"				|
                       get_ra_pref_pltime "$saddr" "$pref" "$ifname")
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
        #TBD

        # Get IPv6 RA RDNSSes
        #TBD

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
  for target in $(echo "$PING4_SRVS" | sed 's/,/ /g'); do
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
  for target in $(echo "$PDNS4_SRVS" | sed 's/,/ /g'); do
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
  for target in $(echo "$PDNS6_SRVS" | sed 's/,/ /g'); do
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
  for target in $(echo "$WEB4_SRVS" | sed 's/,/ /g'); do
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
  for target in $(echo "$SSH4_SRVS" | sed 's/,/ /g'); do
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
  for target in $(echo "$PS4_SRVS" | sed 's/,/ /g'); do
    for port in $(echo "$PS_PORTS" | sed 's/,/ /g'); do

      # Do portscan by IPv4
      cmdset_portscan "$layer" 4 pssrv "$target" "$port" "$count" &

    done
    count=$(( count + 1 ))
  done
fi

if [ -n "$v6addrs" ]; then
  count=0
  for target in $(echo "$WEB6_SRVS" | sed 's/,/ /g'); do
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
  for target in $(echo "$SSH6_SRVS" | sed 's/,/ /g'); do
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
  for target in $(echo "$PS6_SRVS" | sed 's/,/ /g'); do
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
    for target in $(echo "$WEB4_SRVS" | sed 's/,/ /g'); do
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
    for target in $(echo "$SSH4_SRVS" | sed 's/,/ /g'); do
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
    for target in $(echo "$PS4_SRVS" | sed 's/,/ /g'); do
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
  write_json_campaign "$uuid" "$mac_addr" "$os_info" "$IFTYPE"		\
                      "$wlan_ssid" "$hostname"
elif [ "$IFTYPE" = "WWAN" ]; then
  write_json_campaign "$uuid" "$wwan_imei" "$os_info" "$IFTYPE"		\
                      "$wwan_apn" "$hostname"
else
  write_json_campaign "$uuid" "$mac_addr" "$os_info" "$IFTYPE"		\
                      none "$hostname"
fi

# remove PID file
rm -f "$PIDFILE"

echo " done."

exit 0

