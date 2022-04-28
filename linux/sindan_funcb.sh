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
  type="$1"
  src="$2"
  case "$type" in
    "ssid"|"bssid")
      if [ "$LOCAL_NETWORK_PRIVACY" = "yes" ]; then
        echo "$(echo "$src" | $CMD_HASH | cut -d' ' -f1):SHA1"
      else
        echo "$src"
      fi
      ;;
    "environment")
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

# Generate JSON data of campaign.
# write_json_campaign <uuid> <mac_addr> <os> <network_type> <network_id>.
function write_json_campaign() {
  if [ $# -ne 5 ]; then
    echo "ERROR: write_json_campaign <uuid> <mac_addr> <os>"		\
         "<network_type> <network_id>." 1>&2
    echo "DEBUG(input data): $1, $2, $3, $4, $5" 1>&2
    return 1
  fi
  local mac_addr; local network_id
  mac_addr=$(hash_result mac_addr "$2")
  network_id=$(hash_result ssid "$5")
  echo "{ \"log_campaign_uuid\" : \"$1\","				\
       "\"mac_addr\" : \"$mac_addr\","					\
       "\"os\" : \"$3\","						\
       "\"network_type\" : \"$4\","					\
       "\"ssid\" : \"$network_id\","					\
       "\"version\" : \"$VERSION\","					\
       "\"occurred_at\" : \"$(date -u '+%Y-%m-%d %T')\" }"		\
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
  local detail
  detail=$(hash_result "$3" "$6")
  echo "{ \"layer\" : \"$1\","						\
       "\"log_group\" : \"$2\","					\
       "\"log_type\" : \"$3\","						\
       "\"log_campaign_uuid\" : \"$UUID\","				\
       "\"result\" : \"$4\","						\
       "\"target\" : \"$5\","						\
       "\"detail\" : \"$detail\","					\
       "\"occurred_at\" : \"$(date -u '+%Y-%m-%d %T')\" }"		\
  > log/sindan_"$1"_"$3"_"$7"_"$(date -u '+%s')".json
  return $?
}
