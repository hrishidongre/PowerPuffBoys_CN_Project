#!/bin/bash
# Captures the DNS -> TCP -> TLS -> HTTP flow for one request into a .pcap.
#
# BEST RESULT: run this on a Mac that is NOT the edge. On the edge machine the
# client-to-edge connection goes over loopback and never touches en0, so the TLS
# handshake is missing from an en0 capture. If you must run it on the edge, this
# script also captures lo0 and tells you which file holds what.
set -e
. "$(dirname "$0")/../lib.sh"
need EDGE_IP DNS_PRIMARY_IP
out="$root/phase2/evidence/captures"
mkdir -p "$out"
stamp=$(date +%Y%m%d_%H%M%S)
iface=$(route get default | awk '/interface:/{print $2}')
me=$(ipconfig getifaddr "$iface")

on_edge=no
[ "$me" = "$EDGE_IP" ] && on_edge=yes

if [ "$on_edge" = yes ]; then
  echo "NOTE: this Mac IS the edge ($me)."
  echo "      Traffic to the service stays on loopback, so two captures are taken."
  echo "      For a single clean file, run this from another Mac instead."
  echo
fi

echo "flushing the DNS cache so the query really goes on the wire"
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder

f="$out/flow_${stamp}.pcap"
sudo tcpdump -i "$iface" -s0 -w "$f" "port 53 or host $EDGE_IP or host $DNS_PRIMARY_IP" &
pid=$!

if [ "$on_edge" = yes ]; then
  floop="$out/loopback_${stamp}.pcap"
  sudo tcpdump -i lo0 -s0 -w "$floop" "port $EDGE_HTTPS_PORT" &
  lpid=$!
fi

sleep 2
curl -s -o /dev/null "https://app.$DOMAIN/api/status"
curl -s -o /dev/null "https://app.$DOMAIN/api/status"
sleep 3
sudo kill "$pid" 2>/dev/null || true
[ -n "$lpid" ] && sudo kill "$lpid" 2>/dev/null
wait 2>/dev/null || true

echo
echo "saved:"
echo "  $f"
[ "$on_edge" = yes ] && echo "  $floop   <- the TLS handshake is in THIS one"
echo
echo "Wireshark display filters:"
echo "  dns                        the query and the response"
echo "  tcp.flags.syn==1           the three-way handshake"
echo "  tls.handshake.type==1      ClientHello"
echo "  tls.handshake.type==2      ServerHello"
echo "  tls.handshake.type==11     Certificate"
echo "  tls                        everything after this is encrypted"
echo
echo "quick check of what you just captured:"
printf "  DNS packets        : "; sudo tcpdump -r "$f" -n port 53 2>/dev/null | wc -l
printf "  TCP handshakes     : "; sudo tcpdump -r "$f" -n "tcp[tcpflags] & tcp-syn != 0" 2>/dev/null | wc -l
if [ "$on_edge" = yes ]; then
  printf "  TLS on loopback    : "; sudo tcpdump -r "$floop" 2>/dev/null | wc -l
fi
