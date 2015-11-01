#!/usr/bin/env bash

set -o errexit

echo 'ipset...'

ipset create -exist ports1 bitmap:port range 10000-32767
ipset create -exist ports2 bitmap:port range 10000-32767
ipset create -exist ports3 bitmap:port range 10000-32767
ipset create -exist block_ip hash:ip
ipset restore -file ipset

echo 'iptables...'

envsubst < iptables-rules | iptables-restore

echo 'network...'

coffee main.coffee