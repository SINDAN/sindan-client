#!/bin/bash
# sindan_func4_os.sh
#
# Commands of the Globalnet Layer functions that depend on the platform.
# Used by common/sindan_func4.sh.

# Run traceroute to the target address. The version is already checked.
# The traceroute is killed after 30 seconds.
# run_traceroute <version> <target_addr>
function run_traceroute() {
  case $1 in
    "4" ) timeout -sKILL 30 traceroute -n -I -w 2 -q 1 -m 20 "$2"; return $? ;;
    "6" ) timeout -sKILL 30 traceroute6 -n -I -w 2 -q 1 -m 20 "$2"; return $? ;;
  esac
}

# Set the ping command of the path MTU discovery.
# PMTUD_CMD: the command and its options (array)
# PMTUD_DFOPT: the option to set the Don't Fragment bit
# PMTUD_SRCOPT: the option to set the source address
# pmtud_setup <version>
function pmtud_setup() {
  PMTUD_DFOPT="-M do"
  PMTUD_SRCOPT="-I"
  case $1 in
    "4" ) PMTUD_CMD=(ping -W 1 -c 1) ;;
    "6" ) PMTUD_CMD=(ping6 -W 1 -c 1) ;;
  esac
}
