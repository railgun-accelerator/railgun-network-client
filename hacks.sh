#!/usr/bin/env bash

set -o errexit
if grep -q $1 hacks.csv; then
    sed -i "s/$1.*/$1,$2/" hacks.csv
else
    echo $1,$2 >> hacks.csv
fi

gateway=$(awk -F, "\$1 == $2 { print \$2 }" regions.csv)
next_hop=$(awk -F, "\$1 == $2 { print \$3 }" regions.csv)
if [ -z "${gateway}" ] || [ -z "${next_hop}" ]; then
    echo "can't find route for region$2"
    exit 1
fi

if [ "${gateway}" = "${RAILGUN_ID}" ]; then
    echo ip route add $1 via ${RAILGUN_GATEWAY}
else
    echo ip route add $1 dev railgun${next_hop} src ${RAILGUN_ADDRESS} realm ${gateway}  advmss 1360
fi