#!/bin/bash

## setup watchdog
echo "seting up watchdog..."
sudo tee -a /boot/config.txt << EOF >/dev/null

# Watchdig Timer
dtparam=watchdog=on
EOF

sudo tee /etc/modprobe.d/bcm2835-wdt.conf << EOF >/dev/null
options bcm2835_wdt heartbeat=14 nowayout=0
EOF

sudo sed -i -e 's/#RuntimeWatchdogSec=0/RuntimeWatchdogSec=14/' /etc/systemd/system.conf

exit 0
