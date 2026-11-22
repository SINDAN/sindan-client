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
