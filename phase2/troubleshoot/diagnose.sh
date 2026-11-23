#!/bin/bash
# Extension F - layer by layer, lowest first. Run this when the faculty breaks something.
# It stops at the first broken layer and tells you which one it is.
. "$(dirname "$0")/../lib.sh"

say() { echo; echo "--- $1 ---"; }
verdict() { echo; echo ">>> BROKEN AT: $1"; echo ">>> $2"; exit 1; }

say "layer 1  link and network - can we reach the machines at all"
for pair in "edge:$EDGE_IP" "backendA:$BACKEND_A_IP" "backendB:$BACKEND_B_IP" "dns:$DNS_PRIMARY_IP"; do
  n=${pair%:*}; ip=${pair#*:}
  [ -z "$ip" ] && continue
  if ping -c1 -W1000 "$ip" >/dev/null 2>&1; then echo "  ok    $n $ip"; else echo "  DOWN  $n $ip"; bad_net=1; fi
done
[ -n "$bad_net" ] && verdict "network layer" "A machine is off, asleep, or on a different Wi-Fi. Nothing above this can work."

say "layer 2  DNS - does the name turn into the edge IP"
echo "  configured resolvers: $(networksetup -getdnsservers Wi-Fi | tr '\n' ' ')"
primary=$(dig @"$DNS_PRIMARY_IP" "app.$DOMAIN" +short 2>/dev/null)
backup=$(dig @"$DNS_BACKUP_IP" "app.$DOMAIN" +short 2>/dev/null)
actual=$(dig "app.$DOMAIN" +short 2>/dev/null)
echo "  primary dns says : ${primary:-no answer}"
echo "  backup dns says  : ${backup:-no answer}"
echo "  this client gets : ${actual:-no answer}"
[ -z "$actual" ] && verdict "DNS layer" "Name does not resolve. Check dnsmasq is running, and that this Mac lists the team resolvers."
[ "$actual" != "$EDGE_IP" ] && verdict "DNS layer (wrong record)" "Resolution works but points at $actual instead of $EDGE_IP. DNS is a directory, not a connection - this is a record or a stale cache. Try ./phase2/dns/flush_cache.sh."

say "layer 3  TCP - is the port open on the edge"
if nc -z -G 2 "$EDGE_IP" "$EDGE_HTTPS_PORT" 2>/dev/null; then echo "  ok    tcp $EDGE_IP:$EDGE_HTTPS_PORT"; else
  verdict "transport layer" "Host answers ping but port $EDGE_HTTPS_PORT is closed. nginx is down, listening on a different port, or a firewall rule is blocking it. Host and port are separate identifiers."
fi

say "layer 4  TLS - handshake and certificate"
tls=$(echo | openssl s_client -connect "$EDGE_IP:$EDGE_HTTPS_PORT" -servername "app.$DOMAIN" 2>/dev/null)
echo "$tls" | grep -q "BEGIN CERTIFICATE" && echo "  ok    server sent a certificate" || verdict "TLS layer" "No certificate came back. Check ssl_certificate paths in the nginx config."
echo "$tls" | grep "Verify return code" | tail -1 | sed 's/^/  /'
echo "$tls" | grep -q "Verify return code: 0" || echo "  WARN  certificate does not verify - CA not trusted on this Mac, or the SAN does not cover app.$DOMAIN"
echo "$tls" | grep -E "Protocol|Cipher" | head -2 | sed 's/^/  /'

say "layer 5  HTTP - does the application answer"
code=$(curl -s -o /dev/null -w '%{http_code}' "https://app.$DOMAIN/api/status")
echo "  status: $code"
case "$code" in
  200) ;;
  502|503|504) verdict "application layer" "The edge is fine and reached the backends, but got $code. Both backends are down, or the upstream IPs/ports in the nginx config are wrong." ;;
  000) verdict "TLS or HTTP layer" "curl could not complete the request. Usually an untrusted certificate - run ./phase2/edge/trust_ca.sh." ;;
  *)   verdict "application layer" "Unexpected status $code from the backend application." ;;
esac

say "which backends are answering"
for i in $(seq 1 6); do curl -s -D- -o /dev/null "https://app.$DOMAIN/api/status" | awk '/^X-Backend:|^X-Upstream:/{printf "%s ", $2}'; echo; done

echo
echo "All five layers healthy."
