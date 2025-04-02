#!/bin/bash

## apt install
echo "installing required packages..."
sudo apt update -y
sudo apt install -y uuid-runtime iw ndisc6 dnsutils curl traceroute

## for nodejs
echo "installing required packages for nodejs..."
mkdir -p trace-json
sudo apt install -y chromium-browser nodejs npm

echo "installing required node packages using npm..."
npm install

exit 0
