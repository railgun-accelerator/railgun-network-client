#!/usr/bin/env bash

set -o errexit

echo 'modprobe fou...'

modprobe fou

echo 'ipset...'

ipset create -exist ports1 bitmap:port range 10000-32767
ipset create -exist ports2 bitmap:port range 10000-32767
ipset create -exist ports3 bitmap:port range 10000-32767
ipset create -exist ports4 bitmap:port range 10000-32767
ipset create -exist block_ip hash:ip

echo 'iptables...'

envsubst < iptables-rules | iptables-restore

if [ -n "${RAILGUN_TOS}" ]; then
    iptables -t mangle -A PREROUTING -s 10.0.0.0/16 -p tcp -m addrtype ! --dst-type LOCAL -m tos --tos ${RAILGUN_TOS} -j TPROXY --on-port 5000 --on-ip 0.0.0.0 --tproxy-mark 0x3
fi

echo 'network...'

coffee main.coffee
