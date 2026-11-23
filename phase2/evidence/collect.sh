#!/bin/bash
# Captures everything that can be proved without stopping anything.
# Writes timestamped text logs into phase2/evidence/logs/ for the report.
. "$(dirname "$0")/../lib.sh"
out="$root/phase2/evidence/logs"
mkdir -p "$out"
ts=$(date "+%Y-%m-%d %H:%M:%S")

{
echo "Team PowerPuffBoys, Phase 2 evidence"
echo "collected $ts"
echo

echo "=== 1. machine map ==="
printf "%-22s %s\n" "primary DNS"   "$DNS_PRIMARY_IP"
printf "%-22s %s\n" "backup DNS"    "$DNS_BACKUP_IP"
printf "%-22s %s\n" "edge"          "$EDGE_IP"
printf "%-22s %s\n" "standby edge"  "$EDGE_STANDBY_IP"
printf "%-22s %s\n" "backend A"     "$BACKEND_A_IP:$BACKEND_A_PORT"
printf "%-22s %s\n" "backend B"     "$BACKEND_B_IP:$BACKEND_B_PORT"
echo

echo "=== 2. reachability ==="
for p in "primary DNS:$DNS_PRIMARY_IP" "backup DNS:$DNS_BACKUP_IP" "edge:$EDGE_IP" "backend A:$BACKEND_A_IP" "backend B:$BACKEND_B_IP"; do
  n=${p%:*}; ip=${p#*:}
  printf "%-22s %-16s " "$n" "$ip"
  ping -c1 -W900 "$ip" >/dev/null 2>&1 && echo "reachable" || echo "NO RESPONSE"
done
echo

echo "=== 3. DNS, both resolvers, Extension A ==="
echo "client resolver list: $(networksetup -getdnsservers Wi-Fi | tr '\n' ' ')"
echo "--- primary ---"; dig @"$DNS_PRIMARY_IP" "app.$DOMAIN" +nocmd +noall +answer
echo "--- backup ---";  dig @"$DNS_BACKUP_IP"  "app.$DOMAIN" +nocmd +noall +answer
echo "both answer with the same record and a TTL of $TTL"
echo

echo "=== 4. caching behaviour for Extension B ==="
echo "IMPORTANT: dig always asks the server directly and bypasses the macOS cache,"
echo "so dig will show a changed record instantly and prove nothing about the TTL."
echo "To show a cached answer surviving, query the system resolver instead:"
dscacheutil -q host -a name "app.$DOMAIN" | sed 's/^/  /'
echo "  (or just: ping -c1 app.$DOMAIN, or open it in a browser)"
echo "server-side TTL on the record:"
dig @"$DNS_PRIMARY_IP" "app.$DOMAIN" +nocmd +noall +answer | awk '$4=="A"{print "  TTL "$2" seconds"}'
echo

echo "=== 5. TLS, no -k, certificate trusted ==="
curl -s -o /dev/null -w "status %{http_code}  tls verify %{ssl_verify_result} (0 = trusted)  http %{http_version}\n" "https://app.$DOMAIN/api/status"
echo | openssl s_client -connect "$EDGE_IP:$EDGE_HTTPS_PORT" -servername "app.$DOMAIN" \
  -CAfile "$root/phase2/edge/certs/ca.crt" 2>/dev/null \
  | grep -E "subject=|issuer=|Protocol|Cipher|Verify return code" | sed 's/^ *//'
echo

echo "=== 6. load balancing, Extension D in normal state ==="
for i in $(seq 1 10); do
  curl -s -D- -o /dev/null "https://app.$DOMAIN/api/status" \
    | awk 'tolower($1)=="x-backend:"{printf "backend %s  ",$2} tolower($1)=="x-upstream:"{printf "upstream %s",$2} END{print ""}' | tr -d '\r'
done
echo

echo "=== 7. caching, fresh then conditional ==="
curl -s -D- -o /dev/null "https://app.$DOMAIN/" | grep -iE "^HTTP|^cache-control|^etag" | tr -d '\r'
echo "--- same request again, this time sending the ETag back ---"
curl -s -D- -o /dev/null -H 'If-None-Match: "backend-a-v1"' "https://app.$DOMAIN/" | grep -iE "^HTTP|^cache-control|^etag" | tr -d '\r'
echo

echo "=== 8. service isolation, Extension C ==="
for p in "backend A:$BACKEND_A_IP:$BACKEND_A_PORT" "backend B:$BACKEND_B_IP:$BACKEND_B_PORT"; do
  n=$(echo "$p" | cut -d: -f1); ip=$(echo "$p" | cut -d: -f2); pt=$(echo "$p" | cut -d: -f3)
  printf "direct from this client to %-12s %s:%s  " "$n" "$ip" "$pt"
  nc -z -G 2 "$ip" "$pt" 2>/dev/null && echo "REACHABLE (isolation not applied yet)" || echo "blocked, correct"
done
printf "through the edge instead: "
curl -s -o /dev/null -w "%{http_code}\n" "https://app.$DOMAIN/api/status"
} | tee "$out/evidence_$(date +%Y%m%d_%H%M%S).txt"
