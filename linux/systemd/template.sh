#!/bin/bash

BASEDIR=$(cd $(dirname $0)/..; pwd)

for template in $(find -type f -name "*.tmpl"); do
    sed -e "s!{{BASE_DIR}}!$BASEDIR!" $template > ${template%.tmpl}
done
