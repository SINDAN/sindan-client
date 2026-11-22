#!/bin/bash

BASEDIR=$(cd "$(dirname "$0")/.." && pwd) || exit 1

find . -type f -name "*.tmpl" | while IFS= read -r template; do
    sed -e "s!{{BASE_DIR}}!$BASEDIR!" "$template" > "${template%.tmpl}"
done
