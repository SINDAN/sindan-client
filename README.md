 ![SINDAN Project](https://raw.githubusercontent.com/SINDAN/sindan-docker/screenshot/logo.png)

# sindan-client

## About SINDAN Project
Please visit website [sindan-net.com](https://www.sindan-net.com) for more details. (Japanese edition only)

> In order to detect network failure, SINDAN project evaluates the network status based on user-side observations, and aims to establish a method that enables network operators to troubleshoot quickly.

## Installation
This script is available for Linux, macOS, and Windows. The macOS version uses the standard commands of macOS, so no additional application is required. The Linux version requires the following packages.
- `dnsutils`, `uuid-runtime`, and `ndisc6`

## Usage

- `sindan.sh` - 
- `sendlog.sh` - 
- `sindan.conf` - 
- `sindan-config` - 

## Configuration
The sindan.conf file is assumed to be located in the same directory as sindan.sh.

Parameters:
- `LOCKFILE`=\<file\> - Specifies a file name for checking the operation of sindan.sh script.
- `LOCKFILE_SENDLOG`=\<file\> - Specifies a file name for checking the operation of sendlog.sh script.
- `FAIL`/`SUCCESS`/`INFO`=\<number\> - Specifies a value of result parameters.
- `MODE`=\<client or probe\> - Specifies the operation mode.
- `RECONNECT`=\<yes or no\> - If yes, do reconnect at L2 measurement.
- `VERBOSE`=\<yes or no\> - If yes, output detailed information from sindan.sh script.
- `MAX_RETRY`=\<number\> - Specifies the maximum number to retry check at the datalink and the interface layer. Default is 10.
- `EXCL_IPv4`=\<yes or no\> - If yes, do not perform measurement with IPv4.
- `EXCL_IPv6`=\<yes or no\> - If yes, do not perform measurement with IPv6.
- `IFTYPE`=\<Wi-Fi or others\> - Specifies the type of measurement interface.
- `DEVNAME`=\<device\> - Specifies the name of measurement interface (e.g. ra0).
- `SSID`=\<ssid\> - Specifies a SSID to be measured (not used in the current version).
- `SSID_KEY`=\<passphrase\> - Specifies a passphrase for SSID to be measured (not used in the current version).
- `PING_SRVS`=\<IPv4 address,\[...\]\> - Specifies external the server's IPv4 addresses for IPv4 reachability confirmation (separated by commas).
- `PING6_SRVS`=\<IPv6 address,\[...\]\> - Specifies external the server's IPv6 addresses for IPv6 reachability confirmation (separated by commas).
- `FQDNS`=\<fqdn,\[...\]\> - Specifies the FQDNs used for name resolution (separated by commas).
- `GPDNS4`=\<server,\[...\]\> - Specifies the external IPv4 DNS servers used for name resolution (separated by commas).
- `GPDNS6`=\<server,\[...\]\> - Specifies the external IPv6 DNS servers used for name resolution (separated by commas).
- `V4WEB_SRVS`=\<server,\[...\]\> - Specifies the IPv4 web servers used for HTTP communication confirmation (separated by commas).
- `V6WEB_SRVS`=\<server,\[...\]\> - Specifies the IPv6 web servers used for HTTP communication confirmation (separated by commas).
- `V4SSH_SRVS`=\<server_keytype,\[...\]\> - Specifies the IPv4 SSH servers and key types used for SSH communication confirmation (separated by commas).
- `V6SSH_SRVS`=\<server_keytype,\[...\]\> - Specifies the IPv6 SSH servers and key types used for SSH communication confirmation (separated by commas).
- `DO_SPEEDTEST`=\<yes or no\> - If yes, do speedtest measurement (available on Linux version only).
- `DO_SPEEDINDEX`=\<yes or no\> - If yes, do speedindex measurement (available on Linux version only).
- `ST_SRVS`=\<url\> - Specifies the URL for the speedtest measurement (available on Linux version only).
- `SI_SRVS`=\<url\> - Specifies the URL for the speedindex measurement (available on Linux version only).
- `URL_CAMPAIGN`=\<url\> - Specifies the URL for sending the metadata (format is http://<server_name>:<port>/sindan.log_campaign).
- `URL_SINDAN`=\<url\> - Specifies the URL for sending the measurement data (format is http://<server_name>:<port>/sindan.log).
- `LOCAL_NETWORK_PRIVACY`=\<yes or no\> - If yes, hash or mask the privacy information (e.g., BSSID) in the wireless LAN environment information.
- `CLIENT_PRIVACY`=\<yes or no\> - If yes, hash or mask the privacy information (e.g., MAC address of the interface) of the computer.
- `CMD_HASH`=\<command path\> - Specifies a command path for hashing privacy data.

Parameters for NFDF monitering (not include in the current version):
- `COMMUNICATION_DEVICE`=\<device\> - Specifies the interface name for SINDAN measurement. Default is DEVNAME.
- `MONITOR_DEVIDE`=\<device\> - Specifies the the interface name for NFDF monitering.
- `MONITOR_REFRESH_TIME`=\<number\> - Specifies the update frequency of NFDF monitering file (unit: seconds). Default is 300.

## Authors
- **Yoshiaki KITAGUCHI** - *Maintein macOS/Linux version* [@kitaguch](https://github.com/kitaguch)
- **Tomohiro ISHIHARA** - *Maintein Windows version* - [@shored](https://github.com/shored)

See also the list of [contributors](https://github.com/SINDAN/sindan-client/graphs/contributors) who participated in this project.

## License
This project is licensed under the BSD 3-Clause "New" or "Revised" License - see the [LICENSE](LICENSE) file for details.
