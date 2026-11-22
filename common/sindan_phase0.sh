#!/bin/bash
# sindan_phase0.sh
#
# Phase 0 (Hardware Layer checking) of sindan.sh, which is the same on all
# platforms. The values that a platform cannot get are reported as "TBD" by
# the functions of sindan_func0.sh and are not recorded (see is_available).
# This file is read by sindan.sh after the preparation.

####################
## Phase 0
echo "Phase 0: Hardware Layer checking..."
layer="hardware"

# Get OS version
os_info=$(get_os_info)

# Get Host name
hostname=$(get_hostname)

# Get hardware information
hw_info=$(get_hw_info)
if is_available "$hw_info"; then
  write_json "$layer" common hw_info "$INFO" self "$hw_info" 0
fi

# Get CPU frequency
cpu_freq=$(get_cpu_freq)
if is_available "$cpu_freq"; then
  write_json "$layer" common cpu_freq "$INFO" self "$cpu_freq" 0
fi

# Get CPU voltage
cpu_volt=$(get_cpu_volt)
if is_available "$cpu_volt"; then
  write_json "$layer" common cpu_volt "$INFO" self "$cpu_volt" 0
fi

# Get CPU temperature
cpu_temp=$(get_cpu_temp)
if is_available "$cpu_temp"; then
  write_json "$layer" common cpu_temp "$INFO" self "$cpu_temp" 0
fi

# Get clock state
clock_state=$(get_clock_state)
if is_available "$clock_state"; then
  clock_state="synchronized=$clock_state"
  write_json "$layer" common clock_state "$INFO" self "$clock_state" 0
fi

# Get clock source
clock_src=$(get_clock_src)
if is_available "$clock_src"; then
  write_json "$layer" common clock_src "$INFO" self "$clock_src" 0
fi

# Report phase 0 results
if [ "$VERBOSE" = "yes" ]; then
  echo " hardware information:"
  echo "  os_info: $os_info"
  echo "  hostname: $hostname"
  echo "  hw_info: $hw_info"
  echo "  cpu(freq: $cpu_freq Hz, volt: $cpu_volt V, temp: $cpu_temp 'C)"
  echo "  clock_state: $clock_state"
  echo "  clock_src: $clock_src"
fi

echo " done."
