#!/bin/bash
# sindan_func0.sh

## Hardware Layer functions

# Get OS information.
function get_os_info() {
  if which system_profiler > /dev/null 2>&1; then
    system_profiler SPSoftwareDataType					|
    sed -n 's/^.*System Version: \(.*\)$/\1/p'
    return $?
  else
    echo "ERROR: system_profiler command not found." 1>&2
    return 1
  fi
}

# Get hostname.
function get_hostname() {
  if which hostname > /dev/null 2>&1; then
    hostname
  else
    uname -n
  fi
  return $?
}

# Get hardware information.
function get_hw_info() {
  if which system_profiler > /dev/null 2>&1; then
    system_profiler SPHardwareDataType					|
    sed -n -e 's/^ *Model Name: \(.*\)/\1/p'				\
     -e 's/^ *Chip: \(.*\)/ (\1)/p' | tr -d '\n'
    return $?
  else
    echo "ERROR: system_profiler command not found." 1>&2
    return 1
  fi
}

# Get CPU frequency infotmation.
function get_cpu_freq() {
  # This functionality is not implemented because powermetrics command 
  # requires root privileges.
  echo 'TBD'
  return $?
}

# Get CPU voltage information.
function get_cpu_volt() {
  # This functionality is not implemented because powermetrics command 
  # requires root privileges.
  echo 'TBD'
  return $?
}

# Get CPU temperature information.
function get_cpu_temp() {
  # This functionality is not implemented because powermetrics command 
  # requires root privileges.
  echo 'TBD'
  return $?
}

# Get system clock status.
function get_clock_state() {
  if which systemsetup > /dev/null 2>&1; then
    # requires root privileges
    if [[ $UID -eq 0 ]]; then
      systemsetup -gettime						| 
      sed -n 's/^.*Network Time: \(.*\)$/\1/p'
    else
      echo 'requires root privileges.'
    fi
  else
    echo 'TBD'
  fi
  return $?
}

# Get the time souece of the system clock.
function get_clock_src() {
  if [ -e /etc/ntp.conf ]; then
    cat /etc/ntp.conf | grep server | awk '{print $2}'
  else
    echo 'using unknown time synclonization service.'
  fi
  return $?
}

