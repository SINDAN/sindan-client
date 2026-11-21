#!/bin/bash
# sindan_funcb.sh

## Basic functions

# Generate UUID.
function generate_uuid() {
  uuidgen
}

# Generate a hash value of privacy data.
# hash_result <type> <src>.
function hash_result() {
  if [ $# -ne 2 ]; then
    echo "ERROR: hash_result <type> <src>." 1>&2
    return 1
  fi
  local type="$1" src="$2"
  case "$type" in
    "ssid"|"bssid"|"wlan_ssid"|"wlan_bssid")
      if [ "$LOCAL_NETWORK_PRIVACY" = "yes" ]; then
        echo "$(echo "$src" | $CMD_HASH | cut -d' ' -f1):SHA1"
      else
        echo "$src"
      fi
      ;;
    "environment"|"wlan_environment")
      # XXX do something if "$LOCAL_NETWORK_PRIVACY" = "yes".
      if [ "$LOCAL_NETWORK_PRIVACY" = "yes" ]; then
        echo 'XXX'
      else
        echo "$src"
      fi
      ;;
    "mac_addr")
      if [ "$CLIENT_PRIVACY" = "yes" ]; then
        echo "$(echo "$src" | $CMD_HASH | cut -d' ' -f1):SHA1"
      else
        echo "$src"
      fi
      ;;
    "v4autoconf"|"v6autoconf")
      # XXX do something if "$CLIENT_PRIVACY" = "yes".
      if [ "$CLIENT_PRIVACY" = "yes" ]; then
        echo 'XXX'
      else
        echo "$src"
      fi
      ;;
    *) echo "$src" ;;
  esac
}

# Escape a string for use inside a JSON string literal (RFC 8259).
# The result is stored in the variable REPLY instead of being printed, so
# that callers do not need a subshell for every field.
# json_escape <string>
function json_escape() {
  local s="$1" hex c u
  # Work on bytes. The control character test below is then independent of
  # the caller's locale, and all bytes of multibyte (UTF-8) characters are
  # >= 0x80, so they pass through unchanged.
  local LC_ALL=C
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}
  s=${s//$'\r'/\\r}
  s=${s//$'\t'/\\t}
  # Escape the remaining control characters (0x01-0x1f except the ones
  # handled above, and 0x7f) as \u00XX. The test keeps the common case fast.
  # Otherwise one character code is replaced at a time with a native
  # expansion, which is much faster than looping over every character.
  if [[ $s == *[[:cntrl:]]* ]]; then
    for hex in 01 02 03 04 05 06 07 08 0b 0c 0e 0f 10 11 12 13 14 15 16 17 \
               18 19 1a 1b 1c 1d 1e 1f 7f; do
      printf -v c "\\x$hex"
      printf -v u '\\u00%s' "$hex"
      s=${s//"$c"/"$u"}
    done
  fi
  REPLY=$s
}

# Generate JSON data of campaign.
# write_json_campaign <uuid> <mac_addr> <os> <network_type> \
#                     <network_id> <hostname>.
function write_json_campaign() {
  if [ $# -ne 6 ]; then
    echo "ERROR: write_json_campaign <uuid> <mac_addr> <os>"		\
         "<network_type> <network_id> <hostname>." 1>&2
    echo "DEBUG(input data): $1, $2, $3, $4, $5, $6" 1>&2
    return 1
  fi
  local mac_addr network_id uuid os network_type hostname version
  mac_addr=$(hash_result mac_addr "$2")
  network_id=$(hash_result ssid "$5")
  # Every value is escaped: SSIDs, host names and OS names are free text.
  json_escape "$1"; uuid=$REPLY
  json_escape "$mac_addr"; mac_addr=$REPLY
  json_escape "$3"; os=$REPLY
  json_escape "$4"; network_type=$REPLY
  json_escape "$network_id"; network_id=$REPLY
  json_escape "$6"; hostname=$REPLY
  json_escape "$VERSION"; version=$REPLY
  printf '%s %s %s %s %s %s %s %s\n' \
    "{ \"log_campaign_uuid\" : \"$uuid\"," \
    "\"mac_addr\" : \"$mac_addr\"," \
    "\"os\" : \"$os\"," \
    "\"network_type\" : \"$network_type\"," \
    "\"ssid\" : \"$network_id\"," \
    "\"hostname\" : \"$hostname\"," \
    "\"version\" : \"$version\"," \
    "\"occurred_at\" : \"$(date -u '+%Y-%m-%d %T')\" }" \
    > log/campaign_"$(date -u '+%s')".json
  return $?
}

# Generate JSON data for measurement results.
# write_json <layer> <group> <type> <result> <target> <detail> <count>.
function write_json() {
  if [ $# -ne 7 ]; then
    echo "ERROR: write_json <layer> <group> <type> <result> <target>"	\
         "<detail> <count>. ($4)" 1>&2
    echo "DEBUG(input data): $1, $2, $3, $4, $5, $6, $7" 1>&2
    return 1
  fi
  local layer group type uuid result target detail
  detail=$(hash_result "$3" "$6")
  # Every value is escaped: the detail is raw command output and the target
  # may come from the configuration file.
  json_escape "$1"; layer=$REPLY
  json_escape "$2"; group=$REPLY
  json_escape "$3"; type=$REPLY
  json_escape "$UUID"; uuid=$REPLY
  json_escape "$4"; result=$REPLY
  json_escape "$5"; target=$REPLY
  json_escape "$detail"; detail=$REPLY
  local json base file n=0
  printf -v json '%s %s %s %s %s %s %s %s\n' \
    "{ \"layer\" : \"$layer\"," \
    "\"log_group\" : \"$group\"," \
    "\"log_type\" : \"$type\"," \
    "\"log_campaign_uuid\" : \"$uuid\"," \
    "\"result\" : \"$result\"," \
    "\"target\" : \"$target\"," \
    "\"detail\" : \"$detail\"," \
    "\"occurred_at\" : \"$(date -u '+%Y-%m-%d %T')\" }"
  # Never overwrite a log written in the same second with the same name:
  # noclobber makes the creation atomic, and a numeric suffix is added on
  # collision. Names without a collision keep the legacy format.
  base=log/sindan_"$1"_"$3"_"$7"_"$(date -u '+%s')"
  file=$base.json
  while ! ( set -o noclobber; printf '%s' "$json" > "$file" ) 2> /dev/null; do
    n=$(( n + 1 ))
    if [ "$n" -gt 100 ] || [ ! -e "$file" ]; then
      echo "ERROR: cannot write $file." 1>&2
      return 1
    fi
    file=${base}_$n.json
  done
  return $?
}

# Check if the value of a measurement is available: not empty and not the
# "TBD" placeholder of a probe that is not implemented on the platform.
# is_available <value>
function is_available() {
  [ -n "$1" ] && [ "$1" != "TBD" ]
}

