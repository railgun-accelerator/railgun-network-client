#!/usr/bin/env bash

set -o errexit

echo 'ipset...'

ipset create -exist ports1 bitmap:port range 10000-32767
ipset create -exist ports2 bitmap:port range 10000-32767
ipset create -exist ports3 bitmap:port range 10000-32767
ipset create -exist block_ip hash:ip
ipset create -exist region1 hash:net
ipset create -exist region2 hash:net
ipset create -exist region3 hash:net
ipset create -exist region4 hash:net

echo 'iptables...'

envsubst < iptables-rules | iptables-restore

echo 'network...'

coffee main.coffee
