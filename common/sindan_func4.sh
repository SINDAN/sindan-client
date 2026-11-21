#!/bin/bash
# sindan_func4.sh
#
# The commands that differ between the platforms (traceroute and ping
# options) are in sindan_func4_os.sh of each platform directory, which must be
# read before this file.

## Globalnet Layer functions

# Do traceroute command to the target address.
# do_traceroute <version> <target_addr>
function do_traceroute() {
  if [ $# -ne 2 ]; then
    echo "ERROR: do_traceroute <version> <target_addr>." 1>&2
    return 1
  fi
  case $1 in
    "4" | "6" ) run_traceroute "$1" "$2"; return $? ;;
    * ) echo "ERROR: <version> must be 4 or 6." 1>&2; return 9 ;;
  esac
}

# Get trace path of traceroute command.
# require do_traceroute() data from STDIN.
function get_tracepath() {
  grep -v traceroute							|
  awk '{print $2}'							|
  awk -F\n -v ORS=',' '{print}'						|
  sed 's/,$//'
  return $?
}

# Do Path MTU discovery to the target address.
# do_pmtud <version> <target_addr> <min_mtu> <max_mtu> <src_addr>
function do_pmtud() {
  if [ $# -ne 5 ]; then
    echo "ERROR: do_pmtud <version> <target_addr> <min_mtu> <max_mtu>"	\
         "<src_addr>." 1>&2
    return 1
  fi
  local ver=$1 target=$2 min=$3 max=$4 src=$5
  local mid header
  case $ver in
    "4" ) header=28 ;;
    "6" ) header=48 ;;
    * ) echo "ERROR: <version> must be 4 or 6." 1>&2; return 9 ;;
  esac
  # Set PMTUD_CMD (array), PMTUD_DFOPT and PMTUD_SRCOPT for the platform.
  pmtud_setup "$ver"
  if ! "${PMTUD_CMD[@]}" $PMTUD_SRCOPT $src $target > /dev/null; then
    echo 0
    return 1
  fi
  while [ $(( max - min )) -gt 1 ]; do
    mid=$(( ( min + max ) / 2 ))
    if "${PMTUD_CMD[@]}" -s $mid $PMTUD_DFOPT $PMTUD_SRCOPT $src $target       \
         >/dev/null 2>/dev/null
    then
      min=$mid
    else
      max=$mid
    fi
  done
  echo "$(( min + header ))"
  return 0
}

# Check the state of traceroute command to the target address.
# cmdset_trace <layer> <version> <target_type> <target_addr> <count>
function cmdset_trace() {
  if [ $# -ne 5 ]; then
    echo "ERROR: cmdset_trace <layer> <version> <target_type>"		\
         "<target_addr> <count>." 1>&2
    return 1
  fi
  local layer=$1 ver=$2 type=$3 target=$4 count=$5
  local ipv result string path_result path_data
  ipv=IPv${ver}
  result=$FAIL
  string=" traceroute to $ipv $type: $target"
  # Enable pipefail inside the command substitution only. Without it the
  # status of the pipeline is the status of sed, which hides the failure of
  # traceroute itself (an error, or the kill by the 30 s timeout).
  if path_result=$(set -o pipefail
                   do_traceroute "$ver" "$target" | sed 's/\*/-/g'); then
    result=$SUCCESS
  fi
  write_json "$layer" "$ipv" "v${ver}path_detail_${type}" "$INFO"	\
             "$target" "$path_result" "$count"
  if [ "$result" = "$SUCCESS" ]; then
    path_data=$(echo "$path_result" | get_tracepath)
    write_json "$layer" "$ipv" "v${ver}path_${type}" "$INFO"		\
               "$target" "$path_data" "$count"
    string="$string\n  path: $path_data"
  else
    string="$string\n  status: ng"
  fi
  if [ "$VERBOSE" = "yes" ]; then
    echo -e "$string"
  fi
}

# Check Path MTU to the target address.
# cmdset_pmtud <layer> <version> <target_type> <target_addr> \
#              <ifmtu> <count> <src_addr>
function cmdset_pmtud() {
  if [ $# -ne 7 ]; then
    echo "ERROR: cmdset_pmtud <layer> <version> <target_type>"		\
         "<target_addr> <ifmtu> <count> <src_addr>." 1>&2
    return 1
  fi
  local layer=$1 ver=$2 type=$3 target=$4 max=$5 count=$6 src=$7
  local ipv min string pmtu_result
  ipv=IPv${ver}
  min=56
  string=" pmtud to $ipv server: $target, from: $src"
  pmtu_result=$(do_pmtud "$ver" "$target" "$min" "$max" "$src")
  if [ "$pmtu_result" -eq 0 ]; then
    write_json "$layer" "$ipv" "v${ver}pmtu_${type}" "$INFO" "$target"	\
               "unmeasurable,$src" "$count"
    string="$string\n  pmtu: unmeasurable"
  else
    write_json "$layer" "$ipv" "v${ver}pmtu_${type}" "$INFO" "$target"	\
               "$pmtu_result,$src" "$count"
    string="$string\n  pmtu: $pmtu_result byte"
  fi
  if [ "$VERBOSE" = "yes" ]; then
    echo -e "$string"
  fi
}

