#!/bin/bash
# Extension A - run on every client Mac. Lists primary first, backup second.
set -e
. "$(dirname "$0")/../lib.sh"
need DNS_PRIMARY_IP DNS_BACKUP_IP

svc=${1:-Wi-Fi}
networksetup -getdnsservers "$svc" > "$root/phase2/dns/.dns_backup_$svc.txt" || true
sudo networksetup -setdnsservers "$svc" "$DNS_PRIMARY_IP" "$DNS_BACKUP_IP"
echo "resolvers now:"
networksetup -getdnsservers "$svc"
