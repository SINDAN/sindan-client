#!/bin/bash
# setup_watchdog.sh - Turn on the hardware watchdog timer of a Raspberry Pi,
# so that the board restarts itself when the system hangs.
#
# Usage: ./setup_watchdog.sh
#
# It is safe to run the script more than once. Reboot to apply the settings.
#
# Environment variables (for testing, normally not needed):
#   SUDO         command to get root privileges (default: sudo, set it to an
#                empty string when running as root)
#   BOOT_CONFIG  boot configuration file (default: /boot/firmware/config.txt
#                if it exists, otherwise /boot/config.txt)
#   MODPROBE_CONF  option file of the watchdog module
#   SYSTEM_CONF  systemd configuration file
#   MODEL_FILE   file with the model name of the board

SUDO=${SUDO-sudo}
MODEL_FILE=${MODEL_FILE:-/proc/device-tree/model}
MODPROBE_CONF=${MODPROBE_CONF:-/etc/modprobe.d/bcm2835-wdt.conf}
SYSTEM_CONF=${SYSTEM_CONF:-/etc/systemd/system.conf}
if [ -z "${BOOT_CONFIG:-}" ]; then
  # Raspberry Pi OS Bookworm and later keep the file in /boot/firmware.
  if [ -f /boot/firmware/config.txt ]; then
    BOOT_CONFIG=/boot/firmware/config.txt
  else
    BOOT_CONFIG=/boot/config.txt
  fi
fi

# The module bcm2835_wdt is the watchdog of the Raspberry Pi only.
if ! grep -q "Raspberry Pi" "$MODEL_FILE" 2> /dev/null; then
  echo "ERROR: this is not a Raspberry Pi." 1>&2
  exit 1
fi

echo "setting up watchdog..."

# Watchdog Timer
if grep -Eq '^[[:space:]]*dtparam=watchdog=on' "$BOOT_CONFIG"; then
  echo " $BOOT_CONFIG: already set."
else
  # shellcheck disable=SC2086
  $SUDO tee -a "$BOOT_CONFIG" << EOF2 > /dev/null || exit 1

# Watchdog Timer
dtparam=watchdog=on
EOF2
  echo " $BOOT_CONFIG: added dtparam=watchdog=on."
fi

# shellcheck disable=SC2086
$SUDO tee "$MODPROBE_CONF" << EOF2 > /dev/null || exit 1
options bcm2835_wdt heartbeat=14 nowayout=0
EOF2
echo " $MODPROBE_CONF: written."

# Replace the default (commented out) line, or a line with another value.
# shellcheck disable=SC2086
$SUDO sed -i -E 's/^#?RuntimeWatchdogSec=.*/RuntimeWatchdogSec=14/' "$SYSTEM_CONF" || exit 1
if grep -q '^RuntimeWatchdogSec=14$' "$SYSTEM_CONF"; then
  echo " $SYSTEM_CONF: RuntimeWatchdogSec=14."
else
  echo "ERROR: $SYSTEM_CONF has no RuntimeWatchdogSec line. Set RuntimeWatchdogSec=14 in the [Manager] section." 1>&2
  exit 1
fi

echo "done. Reboot to apply the settings."
exit 0
