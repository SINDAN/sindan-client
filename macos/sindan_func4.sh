#!/bin/bash
# sindan_func4.sh

## Globalnet Layer functions

# Do traceroute command to the target address.
# do_traceroute <version> <target_addr>
function do_traceroute() {
  if [ $# -ne 2 ]; then
    echo "ERROR: do_traceroute <version> <target_addr>." 1>&2
    return 1
  fi
  case $1 in
    "4" ) traceroute -n -I -w 2 -q 1 -m 20 "$2" 2>/dev/null; return $? ;;
    "6" ) traceroute6 -n -I -w 2 -q 1 -m 20 "$2" 2>/dev/null; return $? ;;
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
  local mid dfopt header
  local -a cmd
  case $ver in
    "4" ) cmd=(ping -t 1 -c 1); dfopt="-D"; header=28 ;;
    "6" ) cmd=(gtimeout -sKILL 3 ping6 -c 1); dfopt=""; header=48 ;;
    * ) echo "ERROR: <version> must be 4 or 6." 1>&2; return 9 ;;
  esac
  if ! "${cmd[@]}" -S $src $target >/dev/null; then
    echo 0
    return 1
  fi
  while [ $(( max - min )) -gt 1 ]; do
    mid=$(( ( min + max ) / 2 ))
    if "${cmd[@]}" -s $mid $dfopt -S $src $target >/dev/null 2>/dev/null
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
  if path_result=$(do_traceroute "$ver" "$target" | sed 's/\*/-/g'); then
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

