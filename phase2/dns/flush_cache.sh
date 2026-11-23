#!/bin/bash
# Extension B - clear the client's DNS cache to show the TTL effect immediately.
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
echo "DNS cache flushed"
