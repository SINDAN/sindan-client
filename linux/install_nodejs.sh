#!/bin/bash
### INSTALL nodejs Script

cd ~/sindan-client/linux
mkdir -p trace-json
sudo apt update -y
sudo apt install -y chromium-browser
sudo apt install -y npm
npm i puppeteer-core
npm i speedline

