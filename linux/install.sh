#!/bin/bash

## apt install
echo "installing required packages..."
sudo apt update -y
sudo apt install -y dnsutils uuid-runtime ndisc6

## for nodejs
echo "installing required packages for nodejs..."
mkdir -p trace-json
sudo apt install -y chromium-browser npm

echo "installing required node packages using npm..."
npm i puppeteer-core
npm i speedline

exit 0
