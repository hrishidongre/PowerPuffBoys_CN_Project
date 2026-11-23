#!/bin/bash
# Put the resolver settings back the way they were.
set -e
. "$(dirname "$0")/../lib.sh"
svc=${1:-Wi-Fi}
sudo networksetup -setdnsservers "$svc" empty
echo "restored to DHCP-provided resolvers"
