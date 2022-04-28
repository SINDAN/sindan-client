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
    "4" ) timeout -sKILL 30 traceroute -n -I -w 2 -q 1 -m 20 "$2"; return $? ;;
    "6" ) timeout -sKILL 30 traceroute6 -n -I -w 2 -q 1 -m 20 "$2"; return $? ;;
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
# do_pmtud <version> <target_addr> <min_mtu> <src_addr> <max_mtu>
function do_pmtud() {
  if [ $# -ne 5 ]; then
    echo "ERROR: do_pmtud <version> <target_addr> <min_mtu> <src_addr>"	\
         "<max_mtu>." 1>&2
    return 1
  fi
  case $1 in
    "4" ) command="ping -i 0.2 -W 1"; dfopt="-M do"; header=28 ;;
    "6" ) command="ping6 -i 0.2 -W 1"; dfopt="-M do"; header=48 ;;
    * ) echo "ERROR: <version> must be 4 or 6." 1>&2; return 9 ;;
  esac
  if ! eval $command -c 1 $2 -I $5 > /dev/null; then
    echo 0
    return 1
  fi
  local version=$1
  local target=$2
  local min=$3
  local max=$4
  local src_addr=$5
  local mid=$(( ( min + max ) / 2 ))

  while [ "$min" -ne "$mid" ] && [ "$max" -ne "$mid" ]; do
    if eval $command -c 1 -s $mid $dfopt $target -I $src_addr >/dev/null 2>/dev/null
    then
      min=$mid
    else
      max=$mid
    fi
    mid=$((( min + max ) / 2))
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
  local layer=$1
  local ver=$2
  local ipv=IPv${ver}
  local type=$3
  local target=$4
  local count=$5
  local result=$FAIL
  local string=" traceroute to $ipv $type: $target"
  local path_result; local path_data

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
  local layer=$1
  local ver=$2
  local ipv=IPv${ver}
  local type=$3
  local target=$4
  local min_mtu=56
  local max_mtu=$5
  local count=$6
  local src_addr=$7
  local string=" pmtud to $ipv server: $target, from: $src_addr"
  local pmtu_result

  pmtu_result=$(do_pmtud "$ver" "$target" "$min_mtu" "$max_mtu" "$src_addr")
  if [ "$pmtu_result" -eq 0 ]; then
    write_json "$layer" "$ipv" "v${ver}pmtu_${type}" "$INFO" "$target"	\
               "unmeasurable,$src_addr" "$count"
    string="$string\n  pmtu: unmeasurable"
  else
    write_json "$layer" "$ipv" "v${ver}pmtu_${type}" "$INFO" "$target"	\
               "$pmtu_result,$src_addr" "$count"
    string="$string\n  pmtu: $pmtu_result byte"
  fi
  if [ "$VERBOSE" = "yes" ]; then
    echo -e "$string"
  fi
}

