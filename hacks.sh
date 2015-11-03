#!/usr/bin/env bash

set -o errexit

set -o allexport
source /etc/railgun/profile
set +o allexport

if grep -q $1 /etc/railgun/hacks.csv; then
    sed -i "s/$1.*/$1,$2/" /etc/railgun/hacks.csv
else
    echo $1,$2 >> /etc/railgun/hacks.csv
fi

gateway=$(awk -F, "\$1 == $2 { print \$2 }" /etc/railgun/regions.csv)
next_hop=$(awk -F, "\$1 == $2 { print \$3 }" /etc/railgun/regions.csv)
if [ -z "${gateway}" ] || [ -z "${next_hop}" ]; then
    echo "can't find route for region$2"
    exit 1
fi

if [ "${gateway}" = "${RAILGUN_ID}" ]; then
    ip route replace $1 via ${RAILGUN_GATEWAY} table 101
else
    ip route replace $1 dev railgun${next_hop} src ${RAILGUN_ADDRESS} realm ${gateway} advmss 1360 table 101
fi
