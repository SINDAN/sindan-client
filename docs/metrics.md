# SINDAN Measurement Metrics
## Layer

| Layer Name ||
|---|---|
| hardware layer | Collect hardware and other relevant information to determine the status of client terminals for which network measurements are to be performed. |
| datalink layer | This corresponds to Layer 2 of the OSI reference model and is the measurement layer for verifying connectivity with neighboring devices. It checks whether a link can be established by monitoring the network interfaces' up/down status. In wireless networks, it measures up to the point where association is established, while also collecting connection parameters required for link-up. |
| interface layer | This layer verifies the IP address configuration at Layer 3 of the OSI reference model. For IPv4, it checks automatic address assignment via DHCP. For IPv6, it verifies address assignment via SLAAC using RA or via DHCPv6. |
| localnet layer | This layer checks IP reachability within the same segment (local network). While this layer also includes local network service discovery using mDNS (Bonjour, Avahi) and LLMNR (Windows), currently, only the reachability of the default gateway and name servers is verified. |
| globalnet layer | This layer verifies IP reachability to external servers outside the organization. In addition to reachability checks (such as round-trip time (RTT) using ping and path analysis using traceroute), path MTU is also measured. |
| dns layer | Name resolution, which translates domain names into IP addresses, is a critical function for application usage, and this layer is responsible for verifying it. In dual-stack environments, name resolution must be checked for both IPv4 and IPv6, as behavior can vary depending on the resolver API provided by the operating system. Therefore, DNS resolution is performed using both the name servers obtained via DHCP/DHCPv6/RA and any specified public DNS servers. |
| app layer | This layer corresponds to Layer 5 and above of the OSI reference model; currently, only the application layer is being evaluated. It verifies whether application-layer communication with external servers outside the organization is possible, and also measures throughput using the iNonius speed test site. |

## Metrics

| Layer | Metric | Description |
|---|---|---|
| hardware | os | OS information. [campaign] |
| hardware | hw_info | Hardware information (currently Raspberry Pi only). |
| hardware | cpu_freq | CPU frequency information (unit: Hz). |
| hardware | cpu_volt | CPU operating voltage (unit: V). |
| hardware | cpu_temp | CPU temperature (in °C). |
| hardware | clock_state | Check if the system time is synchronized (yes or no). |
| hardware | clock_src | Time source information if time is synchronized. |
| datalink | mac_addr | MAC address of the interface (in lower case). [campaign] |
| datalink | ifstatus | Check link status at Layer 2 of the OSI reference model. In wireless networks, verify that the association has been established. [type: boolean] |
| datalink | iftype | Information indicating the interface type. |
| datalink | ifmtu | MTU (Maximum Transmission Unit) size of the interface (unit: Bytes). |
| datalink | ether_media | Information such as communication speed and mode is determined by the auto-negotiation function when the link is established. |
| datalink | wlan_ssid | SSID of the connected wireless LAN. [campaign] |
| datalink | wlan_bssid | BSSID of the access point associated with the wireless LAN. |
| datalink | wlan_rate | Transmission data rate of the wireless LAN (unit: Mbps). |
| datalink | wlan_mcs | Transmission MCS index of the wireless LAN. |
| datalink | wlan_nss | Number of wireless LAN transmission spatial streams. |
| datalink | wlan_mode | PHY mode (Wi-Fi generation) of the wireless LAN. |
| datalink | wlan_band | Frequency band of the wireless LAN. |
| datalink | wlan_channel | Wireless LAN channel information. |
| datalink | wlan_chband | Channel bandwidth of the wireless LAN (unit: Hz). |
| datalink | wlan_rssi | RSSI (Received Signal Strength Indicator) of the wireless LAN (unit: dBm; negative value). |
| datalink | wlan_noise | Noise level of the wireless LAN (unit: dBm; negative value). |
| datalink | wlan_quality | Wireless LAN link quality as defined by the Linux device driver (calculation method unknown). |
| datalink | wlan_environment | List of nearby access points and observed SSIDs. |
| datalink | wwan_imei | IMEI (International Mobile Equipment Identity) of the cellular connection, used for terminal identification in cellular networks (as an alternative to MAC addresses). |
| datalink | wwan_apn | APN (Access Point Name) of the cellular connection. |
| datalink | wwan_rat | RAT (Radio Access Technology) of the cellular connection. |
| datalink | wwan_quality | Signal quality of the cellular connection. |
| datalink | wwan_operator | Name of the cellular network operator. |
| datalink | wwan_mccmnc | Mobile Country Code (MCC) and Mobile Network Code (MNC) of the cellular connection. |
| datalink | wwan_iptype | Type of IP address used by the cellular connection. |
| datalink | wwan_rssi | RSSI (Received Signal Strength Indicator) of the cellular connection (unit: dBm). |
| datalink | wwan_rsrq | RSRQ (Reference Signal Received Quality) of the cellular connection (unit: dB). |
| datalink | wwan_rsrp | RSRP (Reference Signal Received Power) of the cellular connection (unit: dBm). |
| datalink | wwan_snir | Signal-to-noise ratio (SNR) of the cellular connection (unit: dB). |
| datalink | wwan_cid | Cell ID (CID) of the cellular connection. |
| datalink | wwan_lac | LAC (Location Area Code) of the cellular connection. |
| datalink | wwan_tac | TAC (Tracking Area Code) of the cellular connection. |
| datalink | wwan_environment | List of nearby base stations. |
| interface | v4ifconf | IPv4 configuration of the interface. |
| interface | v4autoconf | Checks whether the IPv4 address is set automatically via DHCP and confirms successful configuration. [type: boolean] |
| interface | v4addr | IPv4 address assigned to the interface. |
| interface | netmask | IPv4 netmask of the interface. |
| interface | v4routers | IPv4 default routers. |
| interface | v4namesrvs | IPv4 DNS servers. |
| interface | v6ifconf | IPv6 configuration of the interface. |
| interface | v6lladdr | IPv6 link-local address of the interface. |
| interface | v6autoconf | Checks whether the IPv6 address is set automatically via SLAAC or DHCPv6 and confirms successful configuration. [type: boolean] |
| interface | v6addrs | IPv6 addresses assigned to the interface. |
| interface | pref_len | IPv6 prefix length of the interface. |
| interface | ra_addrs | Source address of the Router Advertisement (RA). |
| interface | ra_flags | Flags included in the RA. |
| interface | ra_hlim | Hop Limit specified in the RA. |
| interface | ra_ltime | Router lifetime specified in the RA. |
| interface | ra_reach | Reachable time specified in the RA. |
| interface | ra_retrans | Retransmission timer specified in the RA. |
| interface | ra_prefs | Prefix information included in the RA. |
| interface | ra_pref_flags | Flags in the prefix information of the RA. |
| interface | ra_pref_vltime | Valid lifetime in the prefix information of the RA. |
| interface | ra_pref_pltime | Preferred lifetime in the prefix information of the RA. |
| interface | ra_pref_len | Prefix length in the prefix information of the RA. |
| interface | ra_routes | Route information included in the RA. |
| interface | ra_route_flag | Flags in the route information of the RA. |
| interface | ra_route_ltime | Route lifetime in the RA route information. |
| interface | ra_rdnsses | Recursive DNS Server (RDNSS) information from the RA. |
| interface | ra_rdnss_ltime | Lifetime of the RDNSS information in the RA. |
| interface | v6routers | IPv6 default routers. |
| interface | v6namesrvs | IPv6 DNS servers. |
| localnet | v4alive_router | Checks the reachability of the IPv4 default router using ICMP. A successful response indicates reachability. [type: boolean] |
| localnet | v4rtt_router_min | Minimum round-trip time (RTT) to the IPv4 default router (unit: ms). |
| localnet | v4rtt_router_ave | Average RTT to the IPv4 default router (unit: ms). |
| localnet | v4rtt_router_max | Maximum RTT to the IPv4 default router (unit: ms). |
| localnet | v4rtt_router_dev | Standard deviation of RTT to the IPv4 default router (unit: ms). |
| localnet | v4loss_router | Packet loss rate to the IPv4 default router (unit: %). |
| localnet | v4alive_namesrv | Checks the reachability of the IPv4 name server using ICMP. A successful response indicates reachability. [type: boolean] |
| localnet | v4rtt_namesrv_min | Minimum RTT to the IPv4 name server (unit: ms). |
| localnet | v4rtt_namesrv_ave | Average RTT to the IPv4 name server (unit: ms). |
| localnet | v4rtt_namesrv_max | Maximum RTT to the IPv4 name server (unit: ms). |
| localnet | v4rtt_namesrv_dev | Standard deviation of RTT to the IPv4 name server (unit: ms). |
| localnet | v4loss_namesrv | Packet loss rate to the IPv4 name server (unit: %). |
| localnet | v6alive_router | Checks the reachability of the IPv6 default router using ICMP. A successful response indicates reachability. [type: boolean] |
| localnet | v6rtt_router_min | Minimum RTT to the IPv6 default router (unit: ms). |
| localnet | v6rtt_router_ave | Average RTT to the IPv6 default router (unit: ms). |
| localnet | v6rtt_router_max | Maximum RTT to the IPv6 default router (unit: ms). |
| localnet | v6rtt_router_dev | Standard deviation of RTT to the IPv6 default router (unit: ms). |
| localnet | v6loss_router | Packet loss rate to the IPv6 default router (unit: %). |
| localnet | v6alive_namesrv | Checks the reachability of the IPv6 name server using ICMP. A successful response indicates reachability. [type: boolean] |
| localnet | v6rtt_namesrv_min | Minimum RTT to the IPv6 name server (unit: ms). |
| localnet | v6rtt_namesrv_ave | Average RTT to the IPv6 name server (unit: ms). |
| localnet | v6rtt_namesrv_max | Maximum RTT to the IPv6 name server (unit: ms). |
| localnet | v6rtt_namesrv_dev | Standard deviation of RTT to the IPv6 name server (unit: ms). |
| localnet | v6loss_namesrv | Packet loss rate to the IPv6 name server (unit: %). |
| globalnet | v4alive_srv | Checks the reachability of the IPv4 external server using ICMP. A successful response indicates reachability. [type: boolean] |
| globalnet | v4rtt_srv_min | Minimum RTT to the IPv4 external server (unit: ms). |
| globalnet | v4rtt_srv_ave | Average RTT to the IPv4 external server (unit: ms). |
| globalnet | v4rtt_srv_max | Maximum RTT to the IPv4 external server (unit: ms). |
| globalnet | v4rtt_srv_dev | Standard deviation of RTT to the IPv4 external server (unit: ms). |
| globalnet | v4rtt_srv_min | Packet loss rate to the IPv4 external server (unit: %). |
| globalnet | v4path_detail_srv | Detailed IPv4 routing path information to the external server. Stores the full output of the traceroute command. |
| globalnet | v4path_srv | IPv4 routing path to the external server, expressed as comma-separated router entries. |
| globalnet | v4pmtu_srv | Path MTU to the IPv4 external server, determined using ICMP (unit: Bytes). |
| globalnet | v6rtt_srv_min | Minimum RTT to the IPv6 external server (unit: ms). |
| globalnet | v6rtt_srv_ave | Average RTT to the IPv6 external server (unit: ms). |
| globalnet | v6rtt_srv_max | Maximum RTT to the IPv6 external server (unit: ms). |
| globalnet | v6rtt_srv_dev | Standard deviation of RTT to the IPv6 external server (unit: ms). |
| globalnet | v6rtt_srv_min | Packet loss rate to the IPv6 external server (unit: %). |
| globalnet | v6path_detail_srv | Detailed IPv6 routing path information to the external server. Stores the full output of the traceroute command. |
| globalnet | v6path_srv | IPv6 routing path to the external server, expressed as comma-separated router entries. |
| globalnet | v6pmtu_srv | Path MTU to the IPv6 external server, determined using ICMP (unit: Bytes). |
| dns | --- | Type: A / AAAA, Query: dual.sindan-net.com (dualstack) / v4only.sindan-net.com (IPv4 only) / v6only.sindan-net.com (IPv6 only), name server: local DNS server / public DNS server |
| dns | v4dnsqry_#{type}_#{query} | Performs a DNS query for the #{type} record of #{query} using an IPv4 name server. The result of the dig command is stored. [type: boolean] |
| dns | v4dnsans_#{type}_#{query} | The answer section of the #{type} record returned by the IPv4 name server for #{query}. If there is no response, this is assumed to be empty. |
| dns | v4dnsttl_#{type}_#{query} | TTL (Time to Live) value of the #{type} record response from the IPv4 name server for #{query} (unit: sec). If not present, this is assumed to be empty. |
| dns | v4dnsrtt_#{type}_#{query} | Response time for the #{type} record query to the IPv4 name server for #{query} (unit: ms). If not present, this is assumed to be empty. |
| dns | v6dnsqry_#{type}_#{query} | Performs a DNS query for the #{type} record of #{query} using an IPv6 name server. The result of the dig command is stored. [type: boolean] |
| dns | v6dnsans_#{type}_#{query} | The answer section of the #{type} record returned by the IPv6 name server for #{query}. If there is no response, this is assumed to be empty. |
| dns | v6dnsttl_#{type}_#{query} | TTL (Time to Live) value of the #{type} record response from the IPv6 name server for #{query} (unit: sec). If not present, this is assumed to be empty. |
| dns | v6dnsrtt_#{type}_#{query} | Response time for the #{type} record query to the IPv6 name server for #{query} (unit: ms). If not present, this is assumed to be empty. |
| app | v4http_websrv | Verify HTTP communication to the target IPv4 web server using IPv4. [type: boolean] |
| app | v4ssh_sshsrv | Verify SSH communication to the target IPv4 server using IPv4. [type: boolean] |
| app | v4portscan_#{port} | Perform a port scan to the target IPv4 server using IPv4. The target port number is specified in `PS_PORTS`. [type: boolean] |
| app | v6http_websrv | Verify HTTP communication to the target IPv6 web server using IPv6. [type: boolean] |
| app | v6ssh_sshsrv | Verify SSH communication to the target IPv6 server using IPv6. [type: boolean] |
| app | v6portscan_#{port} | Perform a port scan to the target IPv6 server using IPv6. The target port number is specified in `PS_PORTS`. [type: boolean] |
| app | speedtest | Perform the iNonius speed test (throughput measurement using HTTPS) to the target server and store the resulting JSON data. [type: boolean] |
| app | v4speedtest_rtt | RTT over IPv4 in the iNonius speed test (unit: ms). |
| app | v4speedtest_jitte | Jitter over IPv4 in the iNonius speed test (unit: ms). |
| app | v4speedtest_download | Download throughput over IPv4 in the iNonius speed test (unit: Mbps). |
| app | v4speedtest_upload | Upload throughput over IPv4 in the iNonius speed test (unit: Mbps). |
| app | v4speedtest_time | Measurement timestamp in Unix time (IPv4) recorded during the iNonius speed test. |
| app | v4speedtest_ip | Source IPv4 addresses observed during the iNonius speed test. |
| app | v4speedtest_port | Source port number (IPv4 communication) observed during the iNonius speed test. |
| app | v4speedtest_org | ISP information (IPv4) observed during the iNonius speed test. |
| app | v4speedtest_mss | IPv4 Maximum Segment Size (MSS) observed during the iNonius speed test (unit: Bytes). |
| app | v6speedtest_rtt | RTT over IPv6 in the iNonius speed test (unit: ms). |
| app | v6speedtest_jitte | Jitter over IPv6 in the iNonius speed test (unit: ms). |
| app | v6speedtest_download | Download throughput over IPv6 in the iNonius speed test (unit: Mbps). |
| app | v6speedtest_upload | Upload throughput over IPv6 in the iNonius speed test (unit: Mbps). |
| app | v6speedtest_time | Measurement timestamp in Unix time (IPv6) recorded during the iNonius speed test. |
| app | v6speedtest_ip | Source IPv6 addresses observed during the iNonius speed test. |
| app | v6speedtest_port | Source port number (IPv6 communication) observed during the iNonius speed test. |
| app | v6speedtest_org | ISP information (IPv6) observed during the iNonius speed test. |
| app | v6speedtest_mss | IPv6 MSS observed during the iNonius speed test (unit: Bytes). |
