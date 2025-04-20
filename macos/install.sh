#!/bin/bash

URL_V3CLI="https://github.com/inonius/v3cli/releases/latest/download"

## brew update
echo "updating required packages..."
brew update

## for gtimeout
echo "installing required packages..."
brew install coreutils

## for v3cli
echo "installing v3cli (command line tool for iNonius Speed Test)..."
mkdir -p bin
case $(uname -m) in
  "arm64" ) v3cli="inonius_v3cli-darwin-arm64" ;;
  "x86_64" ) v3cli="inonius_v3cli-darwin-amd64" ;;
  * ) echo "ERROR: unknown CPU type." 1>&2 ;;
esac
curl -o bin/inonius_v3cli -fL ${URL_V3CLI}/${v3cli}
chmod +x bin/inonius_v3cli

exit 0
