#!/bin/bash
# Captures the DNS -> TCP -> TLS -> HTTP flow for one request into a .pcap
# you can open in Wireshark. Run on a CLIENT Mac.
#   ./capture.sh            captures a full fresh request
set -e
. "$(dirname "$0")/../lib.sh"
need EDGE_IP DNS_PRIMARY_IP
out="$root/phase2/evidence/captures"
mkdir -p "$out"
f="$out/flow_$(date +%Y%m%d_%H%M%S).pcap"
iface=$(route get default | awk '/interface:/{print $2}')

echo "flushing DNS cache so the query is actually on the wire"
sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder

echo "capturing on $iface for 12 seconds"
sudo tcpdump -i "$iface" -w "$f" \
  "port 53 or host $EDGE_IP or host $DNS_PRIMARY_IP" &
pid=$!
sleep 2
curl -s -o /dev/null "https://app.$DOMAIN/api/status"
curl -s -o /dev/null "https://app.$DOMAIN/api/status"
sleep 3
sudo kill "$pid" 2>/dev/null || true
wait "$pid" 2>/dev/null || true

echo
echo "saved: $f"
echo "Wireshark display filters for the demo:"
echo "  dns                                      the query and response"
echo "  tcp.flags.syn==1                         the three-way handshake"
echo "  tls.handshake.type==1                    ClientHello"
echo "  tls.handshake.type==2                    ServerHello"
echo "  tls.handshake.type==11                   Certificate"
echo "  tls                                      everything after is encrypted"
