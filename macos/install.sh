#!/bin/bash

## brew update
echo "updating required packages..."
brew update

## for gtimeout and jq
echo "installing required packages..."
brew install coreutils jq

## librespeed-cli
echo "installing librespeed-cli..."
wget https://github.com/librespeed/speedtest-cli/releases/download/v1.0.10/librespeed-cli_1.0.10_darwin_arm64.tar.gz
tar zxpf librespeed-cli_1.0.10_darwin_arm64.tar.gz

exit 0
