# Installation Guide

## Required Packages

Run `install.sh` in this directory. It installs the packages below with apt and downloads `inonius_v3cli` (the command line tool of the iNonius speed test) to `bin/`.

```
$ ./install.sh
```

- **uuid-runtime** (for uuidgen)
- **iw** (for iw)
- **ndisc6** (for rdisc6)
- **dnsutils** (for dig)
- **curl** (for curl)
- **traceroute** (for traceroute)
- **jq** (for jq)
- **netcat-openbsd** (for nc)

## Scheduling

### with crontab

Suppose current directory is `/home/pi/sindan-client/linux`

```
*/5 * * * * root /home/pi/sindan-client/linux/sindan.sh  1>/dev/null 2>/dev/null
*/3 * * * * root /home/pi/sindan-client/linux/sendlog.sh 1>/dev/null 2>/dev/null
```

### with systemd.timer (recommended)

```
$ cd systemd
$ sudo make install    # Install sindan-client
$ sudo make uninstall  # Uninstall sindan-client
```

## Other scripts

### sindan-config (configuration tool)

`sindan-config` is a menu driven tool (whiptail) that edits `sindan.conf` without an editor. It is made for a Raspberry Pi, where the tool `raspi-config` is used in the same way. It needs `whiptail` and `lua`, which `install.sh` does not install (`sudo apt install whiptail lua5.4`).

Run it in this directory. It changes `./sindan.conf` of the current directory, and creates the file if it does not exist.

```
$ ./sindan-config
```

The menu sets `MODE`, `RECONNECT`, `VERBOSE`, `MAX_RETRY`, the interface (`IFTYPE` and `DEVNAME`), the target servers (`PING4_SRVS`, `PING6_SRVS`, `PDNS4_SRVS`, `PDNS6_SRVS`, `WEB4_SRVS`, `WEB6_SRVS`) and the upload server (`URL_CAMPAIGN`, `URL_SINDAN`). The other parameters have to be edited in `sindan.conf`.

`sindan-config` keeps the `readonly` prefix of a line of `sindan.conf.example` when it changes the value. The retry count has to be a number and the device name must not be empty. If `lua` or `whiptail` is missing, the tool prints the packages to install and stops. When the update of `sindan.conf` fails, the file is left as it was.

### setup_watchdog.sh (Raspberry Pi only)

`setup_watchdog.sh` turns on the hardware watchdog timer of a Raspberry Pi, so that the board restarts itself when the system hangs. It uses `sudo` and does the following.

- Adds `dtparam=watchdog=on` to the boot configuration file (`config.txt`).
- Creates `/etc/modprobe.d/bcm2835-wdt.conf` (`heartbeat=14`, `nowayout=0`).
- Sets `RuntimeWatchdogSec=14` in `/etc/systemd/system.conf`.

Run it once, and reboot to apply the settings. It is safe to run it again: a setting that is already there is not added twice.

```
$ ./setup_watchdog.sh
```

Notes:
- The script stops with an error if the board is not a Raspberry Pi, because the `bcm2835_wdt` module is the watchdog of the Raspberry Pi only.
- It edits `/boot/firmware/config.txt` if that file exists (Raspberry Pi OS Bookworm and later), and `/boot/config.txt` otherwise.
- It replaces an existing `RuntimeWatchdogSec` line of `/etc/systemd/system.conf`, also when it has another value.
