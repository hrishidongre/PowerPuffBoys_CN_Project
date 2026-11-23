#!/bin/bash
# Run on a DNS Mac when it answers on 127.0.0.1 but not from the network.
# Prints everything needed to tell which of the three causes it is.
. "$(dirname "$0")/../lib.sh"
brew=$(brew --prefix)
iface=$(route get default | awk '/interface:/{print $2}')
me=$(ipconfig getifaddr "$iface")

echo "=== 1. this Mac ==="
echo "  ip      : $me"
ifconfig "$iface" | awk '/inet /{print "  netmask : "$4}'

echo
echo "=== 2. how dnsmasq was started (look for --local-service) ==="
ps aux | grep "[d]nsmasq" | sed 's/^/  /'

echo
echo "=== 3. what it is listening on ==="
sudo -n lsof -nP -iUDP:53 -iTCP:53 2>/dev/null | sed 's/^/  /' \
  || echo "  (needs sudo: sudo lsof -nP -iUDP:53 -iTCP:53)"

echo
echo "=== 4. does it answer itself, and on its own LAN address ==="
printf "  via 127.0.0.1 : "; dig @127.0.0.1 "app.$DOMAIN" +short +time=2 +tries=1 2>&1 | head -1
printf "  via %s : " "$me"; dig @"$me" "app.$DOMAIN" +short +time=2 +tries=1 2>&1 | head -1

echo
echo "=== 5. the query log, last 15 lines ==="
echo "  if a query from another Mac is NOT here, the firewall ate it"
tail -15 "$brew/var/log/dnsmasq.log" 2>/dev/null | sed 's/^/  /' || echo "  no log file yet"

echo
echo "=== 6. macOS firewall ==="
/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null | sed 's/^/  /'
/usr/libexec/ApplicationFirewall/socketfilterfw --getblockall 2>/dev/null | sed 's/^/  /'
