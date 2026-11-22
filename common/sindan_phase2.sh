#!/bin/bash
# sindan_phase2.sh
#
# Phase 2 (Interface Layer checking) of sindan.sh, which is the same on all
# platforms. The functions of sindan_func2_os.sh take the same arguments on
# every platform and may ignore the ones they do not need. The functions that
# a platform does not support print nothing, so no record is written (the RA
# parameters, routes and RDNSSes on macOS). This file is read by sindan.sh
# after Phase 1.

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
  write_json "$layer" IPv4 v4autoconf "$result_phase2_1" self "$v4autoconf" 0

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
    write_json "$layer" IPv4 v4nameservers "$INFO" self "$v4nameservers" 0
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
  v6ifconf=$(get_v6ifconf "$ifname" "$IFTYPE")
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

  # Get IPv6 RA information
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
      write_json "$layer" IPv6 v6autoconf "$result_phase2_2" self "$v6autoconf" 0
      # Get IPv6 address
      v6addrs=$(get_v6addrs "$ifname" "")
      if [ -n "$v6addrs" ]; then
        write_json "$layer" IPv6 v6addrs "$INFO" "$v6ifconf" "$v6addrs" 0
      fi
      s_count=0
      for addr in $(echo "$v6addrs" | sed 's/,/ /g'); do
        # Get IPv6 prefix length
        pref_len=$(get_prefixlen_from_ifinfo "$ifname" "$addr")
        if [ -n "$pref_len" ]; then
          write_json "$layer" IPv6 pref_len "$INFO" "$addr" "$pref_len" "$s_count"
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
        write_json "$layer" RA ra_flags "$INFO" "$saddr" "$ra_flags" "$count"

        # Get IPv6 RA router preference
        ra_pref=$(echo "$ra_info" | get_ra_pref "$saddr")
        if [ -z "$ra_pref" ]; then
          ra_pref="none"
        fi
        write_json "$layer" RA ra_pref "$INFO" "$saddr" "$ra_pref" "$count"

        # Get IPv6 RA parameters
        ra_hlim=$(echo "$ra_info" | get_ra_hlim "$saddr")
        if [ -n "$ra_hlim" ]; then
          write_json "$layer" RA ra_hlim "$INFO" "$saddr" "$ra_hlim" "$count"
        fi
        ra_ltime=$(echo "$ra_info" | get_ra_ltime "$saddr")
        if [ -n "$ra_ltime" ]; then
          write_json "$layer" RA ra_ltime "$INFO" "$saddr" "$ra_ltime" "$count"
        fi
        ra_reach=$(echo "$ra_info" | get_ra_reach "$saddr")
        if [ -n "$ra_reach" ]; then
          write_json "$layer" RA ra_reach "$INFO" "$saddr" "$ra_reach" "$count"
        fi
        ra_retrans=$(echo "$ra_info" | get_ra_retrans "$saddr")
        if [ -n "$ra_retrans" ]; then
          write_json "$layer" RA ra_retrans "$INFO" "$saddr" "$ra_retrans" "$count"
        fi

        # Report phase 2 results (IPv6-RA)
        if [ "$VERBOSE" = "yes" ]; then
          echo "  IPv6 RA src addr: $saddr"
          echo "   IPv6 RA flags: $ra_flags"
          echo "   IPv6 RA router preference: $ra_pref"
          echo "   IPv6 RA hoplimit: $ra_hlim"
          echo "   IPv6 RA lifetime: $ra_ltime"
          echo "   IPv6 RA reachable: $ra_reach"
          echo "   IPv6 RA retransmit: $ra_retrans"
        fi

        # Get IPv6 RA prefixes
        ra_prefs=$(echo "$ra_info" | get_ra_prefs "$saddr" "$ifname")
        if [ -n "$ra_prefs" ]; then
          write_json "$layer" RA ra_prefs "$INFO" "$saddr" "$ra_prefs" "$count"
        fi

        s_count=0
        for pref in $(echo "$ra_prefs" | sed 's/,/ /g'); do
          # Get IPv6 RA prefix flags
          ra_pref_flags=$(echo "$ra_info" |
                        get_ra_pref_flags "$saddr" "$pref" "$ifname")
          if [ -n "$ra_pref_flags" ]; then
            write_json "$layer" RA ra_pref_flags "$INFO" "${saddr}-${pref}" "$ra_pref_flags" "$s_count"
          fi

          # Get IPv6 RA prefix parameters
          ra_pref_vltime=$(echo "$ra_info" |
                         get_ra_pref_vltime "$saddr" "$pref" "$ifname")
          if [ -n "$ra_pref_vltime" ]; then
            write_json "$layer" RA ra_pref_vltime "$INFO" "${saddr}-${pref}" "$ra_pref_vltime" "$s_count"
          fi
          ra_pref_pltime=$(echo "$ra_info" |
                         get_ra_pref_pltime "$saddr" "$pref" "$ifname")
          if [ -n "$ra_pref_pltime" ]; then
            write_json "$layer" RA ra_pref_pltime "$INFO" "${saddr}-${pref}" "$ra_pref_pltime" "$s_count"
          fi

          # Get IPv6 prefix length
          ra_pref_len=$(get_prefixlen "$pref")
          if [ -n "$ra_pref_len" ]; then
            write_json "$layer" RA ra_pref_len "$INFO" "${saddr}-${pref}" "$ra_pref_len" "$s_count"
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
            if v6autoconf=$(check_v6autoconf "$ifname" "$v6ifconf" "$ra_flags" "$pref" "$ra_pref_flags"); then
              result_phase2_2=$SUCCESS
              break
            fi
            sleep 5

            rcount=$(( rcount + 1 ))
          done
          write_json "$layer" IPv6 v6addrs "$INFO" "$pref" "$v6addrs" "$count"
          write_json "$layer" IPv6 v6autoconf "$result_phase2_2" "$pref" "$v6autoconf" "$count"
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
          write_json "$layer" RA ra_routes "$INFO" "$saddr" "$ra_routes" "$count"
        fi

        s_count=0
        for route in $(echo "$ra_routes" | sed 's/,/ /g'); do
          # Get IPv6 RA route flag
          ra_route_flag=$(echo "$ra_info" |
                        get_ra_route_flag "$saddr" "$route")
          if [ -n "$ra_route_flag" ]; then
            write_json "$layer" RA ra_route_flag "$INFO" "${saddr}-${route}" "$ra_route_flag" "$s_count"
          fi

          # Get IPv6 RA route parameters
          ra_route_ltime=$(echo "$ra_info" |
                            get_ra_route_ltime "$saddr" "$route")
          if [ -n "$ra_route_ltime" ]; then
            write_json "$layer" RA ra_route_ltime "$INFO" "${saddr}-${route}" "$ra_route_ltime" "$s_count"
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
          write_json "$layer" RA ra_rdnsses "$INFO" "$saddr" "$ra_rdnsses" "$count"
        fi

        s_count=0
        for rdnss in $(echo "$ra_rdnsses" | sed 's/,/ /g'); do
          # Get IPv6 RA RDNSS lifetime
          ra_rdnss_ltime=$(echo "$ra_info" |
                            get_ra_rdnss_ltime "$saddr" "$rdnss")
          if [ -n "$ra_rdnss_ltime" ]; then
            write_json "$layer" RA ra_rdnss_ltime "$INFO" "${saddr}-${rdnss}" "$ra_rdnss_ltime" "$s_count"
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
