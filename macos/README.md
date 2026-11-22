# Installation Guide

## Required Packages

Run `install.sh` in this directory. It installs `coreutils` (for `gtimeout`) with Homebrew and downloads `inonius_v3cli` (the command line tool of the iNonius speed test) to `bin/`. The other commands are the standard ones of macOS.

```
$ ./install.sh
```

## Running periodically

macOS has no cron-like scheduler set up by this repository. Two small scripts run the measurement and the upload in an endless loop. Run them in this directory, each in its own terminal (or in the background).

- `keep_sindan.sh` - runs `./sindan.sh`, waits 15 seconds, and repeats.
- `keep_sendlog.sh` - runs `sh ./sendlog.sh`, waits 15 seconds, and repeats.

```
$ ./keep_sindan.sh
$ ./keep_sendlog.sh
```

Notes:
- The scripts use relative paths, so run them from this directory.
- `sindan.sh` and `sendlog.sh` do not run twice at the same time. They check `PIDFILE` and `LOCKFILE_SENDLOG` of `sindan.conf`.
- The interval is the pause between runs, so the period of the measurement is 15 seconds plus the time of one run. Press Ctrl-C to stop a loop.
- To start them at login or after a reboot, use `launchd` or another tool of your choice.
