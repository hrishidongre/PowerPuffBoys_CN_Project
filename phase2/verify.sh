#!/bin/bash
# Prove your own part works before the demo.  ./phase2/verify.sh <role>
. "$(dirname "$0")/lib.sh"
failures=0
role=$1

check_backend() {
  local name=$1 port=$2 etag=$3
  echo "Backend $name on port $port"
  lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1 && ok "listening" || fail "nothing on $port"
  local h; h=$(curl -s -D- -o /dev/null "http://127.0.0.1:$port/api/status")
  echo "$h" | grep -qi "^X-Backend: $name" && ok "X-Backend: $name" || fail "X-Backend header missing or wrong"
  echo "$h" | grep -qi "^Cache-Control" && ok "Cache-Control present" || fail "no Cache-Control"
  echo "$h" | grep -qi "^ETag" && ok "ETag present" || fail "no ETag"
  local code; code=$(curl -s -o /dev/null -w '%{http_code}' -H "If-None-Match: $etag" "http://127.0.0.1:$port/")
  [ "$code" = 304 ] && ok "conditional request returns 304" || fail "expected 304, got $code"
  local bind; bind=$(lsof -nP -iTCP:"$port" -sTCP:LISTEN | awk 'NR==2{print $9}')
  case "$bind" in
    127.0.0.1:*|\[::1\]:*) fail "bound to $bind - only this Mac can reach it" ;;
    *) ok "bound to $bind, reachable from the LAN" ;;
  esac
}

check_dns() {
  echo "DNS service on this Mac"
  pgrep -q dnsmasq && ok "dnsmasq running" || fail "dnsmasq not running"
  # Older dig still prints its banner with +noall +answer, so pick the A record
  # line rather than the first line of output.
  local ans; ans=$(dig @127.0.0.1 "app.$DOMAIN" +nocmd +noall +answer | awk '$4=="A"')
  echo "$ans" | grep -q "$EDGE_IP" && ok "app.$DOMAIN -> $EDGE_IP" || fail "wrong or missing answer: ${ans:-none}"
  local ttl; ttl=$(echo "$ans" | awk '$4=="A"{print $2; exit}')
  [ "$ttl" = "$TTL" ] && ok "TTL is $TTL, as Extension B needs" || fail "TTL is ${ttl:-unreadable}, expected $TTL"

  # Extension A only counts if clients can reach it, so check the LAN address too.
  local me; me=$(ipconfig getifaddr "$(route get default | awk '/interface:/{print $2}')")
  if dig @"$me" "app.$DOMAIN" +short +time=2 +tries=1 2>/dev/null | grep -q "$EDGE_IP"; then
    ok "answers on the LAN address $me, so other Macs can use it"
  else
    fail "answers on 127.0.0.1 but NOT on $me - no other Mac can use this resolver"
    echo "        check: ps aux | grep [d]nsmasq        (is --local-service set)"
    echo "        check: tail -20 \$(brew --prefix)/var/log/dnsmasq.log"
    echo "        check: sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate"
  fi
}

check_edge() {
  echo "Edge on this Mac"
  # nginx -t needs root to read the certificate key. Do not fail the run just
  # because this shell has no cached sudo credentials.
  if sudo -n nginx -t 2>/dev/null; then
    ok "nginx config valid"
  elif sudo -n true 2>/dev/null; then
    fail "nginx -t failed"
  else
    echo "  SKIP  nginx -t needs sudo - run 'sudo nginx -t' yourself"
  fi
  pgrep -q nginx && ok "nginx running" || fail "nginx not running"
  local code; code=$(curl -s -m 5 -o /dev/null -w '%{http_code}' "https://app.$DOMAIN/api/status")
  if [ "$code" = 200 ]; then
    ok "https works with no -k"
  else
    fail "https returned $code"
    # A 000 on the edge Mac is almost always its own DNS or trust store, not nginx.
    dig +time=2 +tries=1 "app.$DOMAIN" +short | grep -q . \
      || echo "        cause: app.$DOMAIN does not resolve here. Run ./phase2/run.sh client"
    security find-certificate -c "PowerPuffBoys Local CA" /Library/Keychains/System.keychain >/dev/null 2>&1 \
      || echo "        cause: this Mac does not trust the team CA. Run ./phase2/edge/trust_ca.sh"
    curl -s -m 5 -o /dev/null -w "        edge itself, bypassing both: status %{http_code}\n" \
      --cacert "$root/phase2/edge/certs/ca.crt" --resolve "app.$DOMAIN:$EDGE_HTTPS_PORT:$EDGE_IP" \
      "https://app.$DOMAIN/api/status"
  fi
  # HTTP/2 hands the headers back lowercased, so match either spelling.
  local seen; seen=$(for i in $(seq 1 10); do curl -s -D- -o /dev/null "https://app.$DOMAIN/api/status" | awk 'tolower($1)=="x-backend:"{print $2}'; done | tr -d '\r' | sort -u | tr '\n' ' ')
  if echo "$seen" | grep -q A && echo "$seen" | grep -q B; then
    ok "load balancing hits both: $seen"
  else
    fail "only saw: ${seen:-nothing}"
    echo "        the other backend is probably not started yet"
  fi
}

check_client() {
  echo "Client checks"
  networksetup -getdnsservers Wi-Fi | grep -q "$DNS_PRIMARY_IP" && ok "primary resolver set" || fail "primary resolver not set"
  networksetup -getdnsservers Wi-Fi | grep -q "$DNS_BACKUP_IP" && ok "backup resolver set" || fail "backup resolver not set"
  dig "app.$DOMAIN" +short | grep -q "$EDGE_IP" && ok "name resolves through team DNS" || fail "name does not resolve"
  local code; code=$(curl -s -o /dev/null -w '%{http_code}' "https://app.$DOMAIN/")
  [ "$code" = 200 ] && ok "https by name, certificate trusted" || fail "https returned $code"
}

case "$role" in
  backend-a) need BACKEND_A_PORT; check_backend A "$BACKEND_A_PORT" '"backend-a-v1"' ;;
  backend-b) need BACKEND_B_PORT; check_backend B "$BACKEND_B_PORT" '"backend-b-v1"' ;;
  dns-primary|dns-backup) need EDGE_IP; check_dns ;;
  edge|edge-standby) need BACKEND_A_IP BACKEND_B_IP; check_edge ;;
  client) need DNS_PRIMARY_IP DNS_BACKUP_IP EDGE_IP; check_client ;;
  *) echo "usage: verify.sh backend-a|backend-b|dns-primary|dns-backup|edge|client"; exit 1 ;;
esac

echo
[ "$failures" -eq 0 ] && echo "all checks passed" || { echo "$failures check(s) failed"; exit 1; }
