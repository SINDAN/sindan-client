#!/bin/bash
# sindan_func0.sh

## Hardware Layer functions

# Get OS information.
function get_os() {
  sw_vers								|
  awk -F: '{sub(/\t/,""); print $2}'					|
  awk -v ORS=' ' '1; END {printf "\n"}'
  return $?
}

# Get hardware information.		yet
function get_hw_info() {
  if [ -e /proc/device-tree/model ]; then
    awk 1 /proc/device-tree/model | tr -d '\0'
  else
    echo 'TBD'
  fi
  return $?
}

# Get CPU frequency infotmation.		yet
function get_cpu_freq() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_cpu_freq <os>." 1>&2
    return 1
  fi
  if echo $1 | grep Raspbian > /dev/null 2>&1; then
    vcgencmd measure_clock arm						|
    awk -F= '{print $2}'
  else
    echo 'TBD'
  fi
  return $?
}

# Get CPU voltage information.		yet
function get_cpu_volt() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_cpu_volt <os>." 1>&2
    return 1
  fi
  if echo $1 | grep Raspbian > /dev/null 2>&1; then
    vcgencmd measure_volts core						|
    sed -n 's/^volt=\([0-9\.]*\).*$/\1/p'
  else
    echo 'TBD'
  fi
  return $?
}

# Get CPU temperature information.		yet
function get_cpu_temp() {
  if [ $# -ne 1 ]; then
    echo "ERROR: get_cpu_temp <os>." 1>&2
    return 1
  fi
  if echo $1 | grep Raspbian > /dev/null 2>&1; then
    vcgencmd measure_temp						|
    sed -n 's/^temp=\([0-9\.]*\).*$/\1/p'
  elif [ -f /sys/class/thermal/thermal_zone0/temp ]; then
    echo "scale=3; $(cat /sys/class/thermal/thermal_zone0/temp) / 1000" |
    bc
  else
    echo 'TBD'
  fi
  return $?
}

# Get system clock status.		yet
function get_clock_state() {
  if which timedatectl > /dev/null 2>&1; then
    timedatectl								|
    sed -n 's/.*System clock synchronized: \([a-z]*\).*$/\1/p'
  else
    echo 'TBD'
  fi
  return $?
}

# Get the time souece of the system clock.		yet
function get_clock_src() {
  if which timedatectl > /dev/null 2>&1; then
    use_timesyncd=$(timedatectl |
      grep -e "NTP service: active" \
           -e "systemd-timesyncd.service active: yes")
    if [ -n "$use_timesyncd" ]; then
      systemctl status systemd-timesyncd				|
      grep Status							|
      sed 's/^[ \t]*//'
    else
      if [ -e /run/ntpd.pid ]; then
        ntpq -p | grep -e ^o -e ^*
      elif [ -e /run/chronyd.pid ]; then
        chronyc sources | grep "\^\*"
      else
        echo 'using unknown time synclonization service.'
      fi
    fi
  else
    echo 'TBD'
  fi
  return $?
}

