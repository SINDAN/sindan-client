 ![SINDAN Project](https://raw.githubusercontent.com/SINDAN/sindan-docker/screenshot/logo.png)

# sindan-client

## About SINDAN Project
Please visit website [sindan-net.com](https://www.sindan-net.com) for more details. (Japanese edition only)

> In order to detect network failure, SINDAN project evaluates the network status based on user-side observations, and aims to establish a method that enables network operators to troubleshoot quickly.

## Installation
This script is available for Linux, macOS, and Windows. For Linux and macOS, run `install.sh` in the `linux` or `macos` directory. It installs the required packages and downloads `inonius_v3cli` (the command line tool of the iNonius speed test) to `bin/`.

- Linux: `uuid-runtime`, `iw`, `ndisc6`, `dnsutils`, `curl`, `traceroute`, `jq` and `netcat-openbsd` (installed with apt). See [linux/README.md](linux/README.md) for scheduling.
- macOS: the standard commands of macOS and `gtimeout` of `coreutils` (installed with Homebrew).
- Windows: see [windows/README.md](windows/README.md).

## Usage
Copy `sindan.conf.example` in the `linux` or `macos` directory to `sindan.conf`, edit it (see Configuration), and run the following scripts in that directory.

- `sindan.sh` - Runs the measurement of all layers (hardware, datalink, interface, localnet, globalnet, dns and app) and writes the results as JSON files to `log/`.
- `sendlog.sh` - Sends the JSON files in `log/` to `URL_CAMPAIGN` and `URL_SINDAN`, and removes the files that the server accepted (HTTP status 200).

## Directory layout
- `linux/`, `macos/` - the scripts and `sindan.conf.example` of each platform. Run `sindan.sh` and `sendlog.sh` from here.
- `common/` - the functions and the `sendlog.sh` implementation shared by Linux and macOS. They are read by the scripts in `linux/` and `macos/` through the relative path `../common`, so keep the directories of a checkout together.
- `*_os.sh` in `linux/` and `macos/` - the parts of the function files that depend on the platform.
- `tests/` - tests of the shell scripts. Run `tests/run_tests.sh` (needs bash and python3 or jq). `tests/check_bash32.sh` looks for bash 4+ constructs that do not work on macOS. Both run in CI (`.github/workflows/ci.yml`) together with ShellCheck.

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
