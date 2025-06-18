#!/bin/bash

URL_V3CLI="https://github.com/inonius/v3cli/releases/latest/download"

## apt install
echo "installing required packages..."
sudo apt update -y
sudo apt install -y uuid-runtime iw ndisc6 dnsutils curl traceroute jq netcat-openbsd

## for v3cli
echo "installing v3cli (command line tool for iNonius Speed Test)..."
mkdir -p bin
case $(uname -m) in
  "x86_64" ) v3cli="inonius_v3cli-linux-amd64" ;;
  "aarch64" ) v3cli="inonius_v3cli-linux-arm64" ;;
  * ) echo "ERROR: unknown CPU type." 1>&2 ;;
esac
curl -o bin/inonius_v3cli -fL ${URL_V3CLI}/${v3cli}
chmod +x bin/inonius_v3cli

exit 0
