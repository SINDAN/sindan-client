#!/bin/bash
# sindan_func3.sh

## Localnet Layer functions

# Do ping command to the target address.
# do_ping <version> <target_addr>
function do_ping() {
  if [ $# -ne 2 ]; then
    echo "ERROR: do_ping <version> <target_addr>." 1>&2
    return 1
  fi
  case $1 in
    "4" ) ping -i 0.2 -c 10 "$2"; return $? ;;
    "6" ) ping6 -i 0.2 -c 10 "$2"; return $? ;;
    * ) echo "ERROR: <version> must be 4 or 6." 1>&2; return 9 ;;
  esac
}

# Get RTT of ping command.
# require do_ping() data from STDIN.
function get_rtt() {
  sed -n 's/^round-trip.* \([0-9\.\/]*\) .*$/\1/p'			|
  sed 's/\// /g'
  return $?
}

# Get paket loss rate of ping command.
# require do_ping() data from STDIN.
function get_loss() {
  # require do_ping() data from STDIN.
  sed -n 's/^.* \([0-9.]*\)\% packet loss.*$/\1/p'
  return $?
}

# Check the state of ping command to the target address.
# cmdset_ping <layer> <version> <target_type> \
#             <target_addr> <count>
function cmdset_ping() {
  if [ $# -ne 5 ]; then
    echo "ERROR: cmdset_ping <layer> <version> <target_type>"		\
         "<target_addr> <count>." 1>&2
    return 1
  fi
  local layer=$1
  local ver=$2
  local ipv=IPv${ver}
  local type=$3
  local target=$4
  local count=$5
  local rtt_type=(min ave max dev)
  local result=$FAIL
  local string=" ping to $ipv $type: $target"
  local ping_result; local rtt_data; local rtt_loss

  if ping_result=$(do_ping "$ver" "$target"); then
    result=$SUCCESS
  fi
  write_json "$layer" "$ipv" "v${ver}alive_${type}" "$result" "$target"	\
             "$ping_result" "$count"
  if [ "$result" = "$SUCCESS" ]; then
    rtt_data=($(echo "$ping_result" | get_rtt))
    for i in 0 1 2 3; do
      write_json "$layer" "$ipv" "v${ver}rtt_${type}_${rtt_type[$i]}"	\
                 "$INFO" "$target" "${rtt_data[$i]}" "$count"
    done
    rtt_loss=$(echo "$ping_result" | get_loss)
    write_json "$layer" "$ipv" "v${ver}loss_${type}" "$INFO" "$target"	\
               "$rtt_loss" "$count"
    string="$string\n  status: ok"
    string="$string, rtt: ${rtt_data[1]} msec, loss: $rtt_loss %"
  else
    string="$string\n  status: ng"
  fi
  if [ "$VERBOSE" = "yes" ]; then
    echo -e "$string"
  fi
}

