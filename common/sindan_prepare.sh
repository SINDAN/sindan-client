#!/bin/bash
# sindan_prepare.sh
#
# Preparation of sindan.sh, which is the same on all platforms: check the
# configuration and the commands, manage the PID file, make the log
# directory and generate the UUID. It is read by sindan.sh after the
# function files. The platform specific requirements are given by sindan.sh:
#   OS_REQUIRED_PARAMS  parameters of sindan.conf that are needed in addition
#   OS_REQUIRED_CMDS    commands that are needed

# Check parameters
for param in PIDFILE MAX_RETRY IFTYPE PING4_SRVS PING6_SRVS FQDNS PDNS4_SRVS PDNS6_SRVS WEB4_SRVS WEB6_SRVS SSH4_SRVS SSH6_SRVS $OS_REQUIRED_PARAMS; do
  if [ -z "$(eval echo '$'"$param")" ]; then
    echo "ERROR: $param is null in configuration file." 1>&2
    exit 1
  fi
done

# Check commands
for cmd in $OS_REQUIRED_CMDS; do
  if ! which "$cmd" > /dev/null 2>&1; then
    echo "ERROR: $cmd is not found." 1>&2
    exit 1
  fi
done

# Set PID file
trap 'rm -f $PIDFILE; exit 0' INT EXIT

if [ -e "$PIDFILE" ]; then
  ppid=$(cat "$PIDFILE")
  if kill -0 "$ppid" > /dev/null 2>&1; then
    kill -9 -"$ppid"
    rm -f "$PIDFILE"
    echo "Warning: killed the previous job which was running."
  else
    echo "Warning: previous check appears to have not finished correctly."
  fi
fi
echo $$ >"$PIDFILE"

# Make log directory
mkdir -p log

# Generate UUID
uuid=$(generate_uuid)
UUID=$uuid
