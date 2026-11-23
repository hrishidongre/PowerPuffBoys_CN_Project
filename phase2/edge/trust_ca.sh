#!/bin/bash
# Run on every client Mac so the demo needs no curl -k and shows no browser warning.
set -e
. "$(dirname "$0")/../lib.sh"
ca="$root/phase2/edge/certs/ca.crt"
[ -f "$ca" ] || { echo "certs/ca.crt missing - pull the repo after the edge Mac has pushed it"; exit 1; }
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain "$ca"
echo "PowerPuffBoys CA trusted on this Mac"
