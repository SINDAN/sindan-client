#!/bin/bash

## apt install
echo "installing required packages..."
sudo apt update -y
sudo apt install -y uuid-runtime wireless-tools ndisc6 dnsutils curl traceroute

## librespeed-cli
echo "installing librespeed-cli..."
wget https://github.com/librespeed/speedtest-cli/releases/download/v1.0.10/librespeed-cli_1.0.10_linux_arm64.tar.gz
tar zxpf librespeed-cli_1.0.10_linux_arm64.tar.gz

exit 0
