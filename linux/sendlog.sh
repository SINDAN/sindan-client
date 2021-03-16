#!/bin/bash
# sendlog.sh
# version 1.4

# read configurationfile
cd $(dirname $0)
. ./sindan.conf

# Check LOCKFILE_SENDLOG parameter
if [ -z "$LOCKFILE_SENDLOG" ]; then
  echo "ERROR: LOCKFILE_SENDLOG is null at configration file." 1>&2
  exit 1
fi
trap 'rm -f $LOCKFILE_SENDLOG; exit 0' INT

if [ ! -e $LOCKFILE_SENDLOG ]; then
  echo $$ >"$LOCKFILE_SENDLOG"
else
  pid=`cat "$LOCKFILE_SENDLOG"`
  kill -0 "$pid" > /dev/null 2>&1
  if [ $? = 0 ]; then
    exit 0
  else
    echo $$ >"$LOCKFILE_SENDLOG"
    echo "Warning: previous check appears to have not finished correctly"
  fi
fi


#
# main
#

# upload campaign log
for file in `find log/ -name "campaign_*.json"`; do
  if [ "$VERBOSE" = "yes" ]; then
    echo " send $file to $URL_CAMPAIGN"
  fi
  status=`curl --max-time 5 -s -w %{http_code} -F json=@$file $URL_CAMPAIGN`
  if [ "$VERBOSE" = "yes" ]; then
    echo " status:$status"
  fi
  if [ "$status" = "200" ]; then
    rm -f $file
  fi
done

# upload sindan log
for file in `find log/ -name "sindan_*.json"`; do
  if [ "$VERBOSE" = "yes" ]; then
    echo " send $file to $URL_SINDAN"
  fi
  status=`curl --max-time 15 -s -w %{http_code} -F json=@$file $URL_SINDAN`
  if [ "$VERBOSE" = "yes" ]; then
    echo " status:$status"
  fi
  if [ "$status" = "200" ]; then
    rm -f $file
  fi
done

# remove lock file
rm -f $LOCKFILE_SENDLOG

exit 0

