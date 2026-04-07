# SINDAN client Windows

This document summarizes how to use the Windows version of the SINDAN client and its current limitations.

## Notes

- The Windows version has fewer features than the Linux/macOS versions.
- If possible, using the Linux/macOS versions is recommended.

## Usage

1. Open PowerShell and move to the `windows` directory.
2. Edit `sindan.conf` for your environment.
3. Run the diagnostics.
4. Send the generated JSON logs.

Example:

```powershell
cd .\windows
.\sindan.ps1
.\sendlog.ps1
```

Log output:

- Diagnostic logs are written to `windows/log/*.json`.
- If `DEBUG_LOG=yes`, debug logs are written to `windows/log/sindan_debug_*.log`.

## Configuration file

The configuration file is `windows/sindan.conf`. Key parameters:

- `IFTYPE`: Target interface name. Usually `Wi-Fi`.
- `RECONNECT`: If `yes`, performs interface down/up.
- `PING_SRVS`, `PING6_SRVS`: Reachability test targets.
- `FQDNS`, `GPDNS4`, `GPDNS6`: DNS test targets.
- `V4WEB_SRVS`, `V6WEB_SRVS`: HTTP test targets.
- `CAMPAIGN_ENDPOINT`, `SENDLOG_ENDPOINT`: Log upload endpoints.
- `DO_SPEEDTEST`: Runs speedtest when set to `yes`.
- `SPEEDTEST_CMD`: speedtest command name or path.
- `ST_SRVS`: Comma-separated speedtest server IDs. Empty means auto-select.

## Installing speedtest

On Windows, the easiest way is to use `winget`.

1. Install speedtest CLI:

```powershell
winget install --id Ookla.Speedtest.CLI --exact --source winget
```

2. Verify installation:

```powershell
speedtest --version
```

3. Example configuration in `sindan.conf`:

```conf
DO_SPEEDTEST=yes
SPEEDTEST_CMD=speedtest
ST_SRVS=
```

Notes:

- On first use, `winget` may ask you to accept terms.
- If `winget` is restricted (for example on corporate devices), use an alternative method based on your policy.

## Not implemented / limitations

Major gaps in the current Windows version compared to Linux/macOS:

- PID file based duplicate-run control and previous-process termination.
- Retry-based checks using `MAX_RETRY`.
- Some detailed Wi-Fi metrics: `wlan_bssid`, `wlan_mcs`, `wlan_nss`, `wlan_mode`, `wlan_band`, `wlan_chband`, `wlan_quality`, `wlan_environment`.
- WWAN metric set (APN/RAT/RSRP/RSRQ, etc.).
- Detailed IPv6 RA parsing and `v6autoconf` validation.
- IPv6 PMTUD (currently treated as not implemented).
- Probe-equivalent DNS phase checks (ping/traceroute to nameservers, DNS64 detection).
- SSH reachability and port scan checks in the application layer.
- `MODE=probe/client` behavior switching.
- Campaign log file generation at the end of execution.
