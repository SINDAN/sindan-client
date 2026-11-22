#!/bin/bash
# sindan_phase3_7.sh
#
# Phase 3 to 7 of sindan.sh (Localnet, Globalnet, DNS and Application Layer
# checking and the campaign log), which are the same on all platforms. This
# file is read by sindan.sh of each platform after Phase 2 and uses its
# variables (layer results, addresses, and so on). It ends the script with
# exit.

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
if is_usable_v4addr_type "$v4addr_type"; then
  count=0
  for target in $(echo "$PING4_SRVS" | sed 's/,/ /g'); do
    if [ "$MODE" = "probe" ]; then
      # Do ping to IPv4 routers
      if [ "$count" -eq 0 ]; then
        cmdset_ping_routers "$layer" 4 "$v4routers"
      fi
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
      if [ "$count" -eq 0 ]; then
        cmdset_ping_routers "$layer" 6 "$v6routers"
      fi
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

if is_usable_v4addr_type "$v4addr_type"; then
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
      if [ "$count" -eq 0 ]; then
        cmdset_ping_routers "$layer" 4 "$v4routers"
      fi

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

# Check DNS64 on all of the IPv6 nameservers
exist_dns64="no"
if [ -n "$v6addrs" ]; then
  exist_dns64=$(check_dns64_any "$v6nameservers")
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

    count=$(( count + 1 ))
  done

  count=0
  for target in $(echo "$PDNS6_SRVS" | sed 's/,/ /g'); do
    if [ "$MODE" = "probe" ]; then
      # Do ping to IPv6 routers
      if [ "$count" -eq 0 ]; then
        cmdset_ping_routers "$layer" 6 "$v6routers"
      fi

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

if is_usable_v4addr_type "$v4addr_type"; then
  count=0
  for target in $(echo "$WEB4_SRVS" | sed 's/,/ /g'); do
    if [ "$MODE" = "probe" ]; then
      # Do ping to IPv4 routers
      if [ "$count" -eq 0 ]; then
        cmdset_ping_routers "$layer" 4 "$v4routers"
      fi

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
      if [ "$count" -eq 0 ]; then
        cmdset_ping_routers "$layer" 6 "$v6routers"
      fi

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
        # The routers are already checked in the loop over WEB6_SRVS.
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
if is_usable_v4addr_type "$v4addr_type" ||
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
  write_json_campaign "$uuid" "$mac_addr" "$os_info" "$IFTYPE" \
                      "$wlan_ssid" "$hostname"
elif [ "$IFTYPE" = "WWAN" ]; then
  write_json_campaign "$uuid" "$wwan_imei" "$os_info" "$IFTYPE" \
                      "$wwan_apn" "$hostname"
else
  write_json_campaign "$uuid" "$mac_addr" "$os_info" "$IFTYPE" \
                      none "$hostname"
fi

# remove PID file
rm -f "$PIDFILE"

echo " done."

exit 0

