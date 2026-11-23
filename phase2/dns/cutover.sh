#!/bin/bash
# Extension E - repoint app.<domain> at a different edge, then reload dnsmasq.
# Usage: ./cutover.sh <new-edge-ip>     (run on whichever Mac serves DNS)
set -e
. "$(dirname "$0")/../lib.sh"
new=$1
[ -n "$new" ] || { echo "usage: cutover.sh <new-edge-ip>"; exit 1; }

conf=$(brew --prefix)/etc/dnsmasq.conf
sudo sed -i '' "s|^address=/app.$DOMAIN/.*|address=/app.$DOMAIN/$new|" "$conf"
sudo brew services restart dnsmasq
sleep 1
echo "app.$DOMAIN now answers with:"
dig @127.0.0.1 "app.$DOMAIN" +noall +answer
echo
echo "On a client, keep running this to watch the old answer expire:"
echo "  dig app.$DOMAIN +noall +answer"
