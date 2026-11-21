#!/bin/bash
# sendlog.sh
#
# Wrapper of the sendlog.sh shared by all platforms (../common/sendlog.sh).
# It is kept in the platform directory so that cron, systemd and
# keep_sendlog.sh can still call it here.

SINDAN_BASE=$(cd "$(dirname "$0")" && pwd) || exit 1
export SINDAN_BASE
exec bash "$SINDAN_BASE/../common/sendlog.sh" "$@"
