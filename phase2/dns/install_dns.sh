#!/bin/bash
# Extension A - run on Adi's Mac (primary) and on Vedant's Mac (backup).
set -e
. "$(dirname "$0")/../lib.sh"
need EDGE_IP

command -v dnsmasq >/dev/null || brew install dnsmasq
brew=$(brew --prefix)
conf="$brew/etc/dnsmasq.conf"
sudo cp -n "$conf" "$conf.orig" 2>/dev/null || true
render "$root/phase2/dns/dnsmasq.conf.tmpl" | sed "s|__BREW__|$brew|g" | sudo tee "$conf" >/dev/null

sudo brew services restart dnsmasq
sleep 1
echo "serving $DOMAIN records, TTL $TTL, pointing at $EDGE_IP"
dig @127.0.0.1 "app.$DOMAIN" +noall +answer
