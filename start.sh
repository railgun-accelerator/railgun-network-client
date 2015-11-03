#!/usr/bin/env bash

set -o errexit

echo 'modprobe fou...'

modprobe fou

echo 'ipset...'

ipset create -exist ports1 bitmap:port range 10000-32767
ipset create -exist ports2 bitmap:port range 10000-32767
ipset create -exist ports3 bitmap:port range 10000-32767
ipset create -exist block_ip hash:ip

echo 'iptables...'

envsubst < iptables-rules | iptables-restore

echo 'network...'

coffee main.coffee
