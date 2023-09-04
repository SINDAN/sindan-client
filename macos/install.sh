#!/bin/bash

## brew update
echo "updating required packages..."
brew update

## for gtimeout
echo "installing required packages..."
brew install coreutils

## for nodejs
echo "installing required packages for nodejs..."
mkdir -p trace-json
brew install node

echo "installing required node packages using npm..."
npm i puppeteer
npm i speedline

exit 0
