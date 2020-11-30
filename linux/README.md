# Installation Guide

## Required Packages

### via apt

- **uuid-runtime** (for uuidgen)
- **wireless-tools** (for iwgetid, iwconfig)
- **ndisc6** (for rdisc6)
- **dnsutils** (for dig)
- **curl** (for curl)
- **chromium-browser**, **npm** (for nodejs)

```
$ sudo apt install uuid-runtime wireless-tools ndisc6 dnsutils curl chromium-browser npm
```

### via npm

- **puppeteer-core**
- **speedline**

```
$ sudo npm install puppeteer-core speedline
```

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
