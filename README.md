 ![SINDAN Project](https://raw.githubusercontent.com/SINDAN/sindan-docker/screenshot/logo.png)

# sindan-client

## About SINDAN Project
Please visit website [sindan-net.com](https://www.sindan-net.com) for more details. (Japanese edition only)

> In order to detect network failure, SINDAN project evaluates the network status based on user-side observations, and aims to establish a method that enables network operators to troubleshoot quickly.

## Installation
This script is available for Linux, macOS, and Windows. The macOS version uses the standard commands of macOS, so no additional application is required. The Linux version requires the following packages.
- `dnsutils`, `uuid-runtime`, `jq` and `ndisc6`

## Usage

- `sindan.sh` - 
- `sendlog.sh` - 

## Configuration
The sindan.conf file is assumed to be located in the same directory as sindan.sh.

Parameters:
- `PIDFILE`=\<file\> - Specifies the file used to check whether the `sindan.sh` script is running.
- `LOCKFILE_SENDLOG`=\<file\> - Specifies the file used to check whether the `sendlog.sh` script is running.
- `FAIL`/`SUCCESS`/`INFO`=\<number\> - Specifies the numeric values for result status indicators.
- `MODE`=\<client or probe\> - Specifies the operation mode.
- `RECONNECT`=\<yes or no\> - If yes, performs reconnection during datalink layer measurement.
- `VERBOSE`=\<yes or no\> - If yes, enables detailed output from the `sindan.sh` script.
- `MAX_RETRY`=\<number\> - Specifies the maximum number of retries for checks at the data link and interface layers. Default is 10.
- `EXCL_IPv4`=\<yes or no\> - If yes, disables measurements using IPv4.
- `EXCL_IPv6`=\<yes or no\> - If yes, disables measurements using IPv6.
- `IFTYPE`=\<Wi-Fi or others\> - Specifies the type of interface used for measurement.
- `DEVNAME`=\<device\> - Specifies the name of the interface used for measurement (e.g., wlan0).
- `PROXY_URL`=\<url\> - Specifies the proxy server URL.
- `PING4_SRVS`=\<IPv4 address,\[...\]\> - Specifies external IPv4 server addresses for IPv4 reachability tests (comma-separated).
- `PING6_SRVS`=\<IPv6 address,\[...\]\> - Specifies external IPv6 server addresses for IPv6 reachability tests (comma-separated).
- `FQDNS`=\<fqdn,\[...\]\> - Specifies fully qualified domain names for DNS resolution tests (comma-separated).
- `PDNS4_SRVS`=\<server,\[...\]\> - Specifies external IPv4 DNS servers for name resolution (comma-separated).
- `PDNS6_SRVS`=\<server,\[...\]\> - Specifies external IPv6 DNS servers for name resolution (comma-separated).
- `WEB4_SRVS`=\<server,\[...\]\> - Specifies IPv4 web servers for HTTP connectivity checks (comma-separated).
- `WEB6_SRVS`=\<server,\[...\]\> - Specifies IPv6 web servers for HTTP connectivity checks (comma-separated).
- `SSH4_SRVS`=\<server_keytype,\[...\]\> - Specifies IPv4 SSH servers and key types for SSH connectivity checks (comma-separated).
- `SSH6_SRVS`=\<server_keytype,\[...\]\> - Specifies IPv6 SSH servers and key types for SSH connectivity checks (comma-separated).
- `PS4_SRVS`=\<server,\[...\]\> - Specifies IPv4 servers used for port scanning (comma-separated).
- `PS6_SRVS`=\<server,\[...\]\> - Specifies IPv6 servers used for port scanning (comma-separated).
- `PS_PORTS`=\<port,\[...\]\> - Specifies port numbers to be scanned (comma-separated).
- `DO_SPEEDTEST`=\<yes or no\> - If yes, performs a speed test.
- `ST_SRVS`=\<url\> - Specifies the server URL for speed test measurements.
- `URL_CAMPAIGN`=\<url\> - Specifies the URL for sending metadata (format: http://<server_name>:<port>/sindan.log_campaign).
- `URL_SINDAN`=\<url\> - Specifies the URL for sending measurement data (format: http://<server_name>:<port>/sindan.log).
- `LOCAL_NETWORK_PRIVACY`=\<yes or no\> - If yes, hashes or masks privacy-related information (e.g., BSSID) in wireless LAN data.
- `CLIENT_PRIVACY`=\<yes or no\> - If yes, hashes or masks client-side privacy data (e.g., MAC address).
- `CMD_HASH`=\<command path\> - Specifies the path to the command used for hashing privacy-related data.

## Authors
- **Yoshiaki KITAGUCHI** - *Maintein macOS/Linux version* [@kitaguch](https://github.com/kitaguch)
- **Tomohiro ISHIHARA** - *Maintein Windows version* - [@shored](https://github.com/shored)

See also the list of [contributors](https://github.com/SINDAN/sindan-client/graphs/contributors) who participated in this project.

## License
This project is licensed under the BSD 3-Clause "New" or "Revised" License - see the [LICENSE](LICENSE) file for details.
