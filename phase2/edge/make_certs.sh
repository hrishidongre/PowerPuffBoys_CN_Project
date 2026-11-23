#!/bin/bash
# Run on the edge Mac. Reuses the Phase 1 CA and certificate if they are still
# good, because the other Macs already trust that CA - replacing it would mean
# everyone installing a new root for nothing.
# Only ca.crt is committed. The .key files never leave this machine.
set -e
. "$(dirname "$0")/../lib.sh"
d="$root/phase2/edge/certs"
nd="$(brew --prefix)/etc/nginx/certs"
mkdir -p "$d"

covers() {
  local san
  san=$(openssl x509 -in "$1" -noout -ext subjectAltName 2>/dev/null)
  echo "$san" | grep -q "DNS:$DOMAIN" || return 1
  echo "$san" | grep -q "DNS:\*\.$DOMAIN" && return 0
  echo "$san" | grep -q "DNS:app\.$DOMAIN" && echo "$san" | grep -q "DNS:api\.$DOMAIN"
}

# 1. the certificate authority
if [ -f "$nd/ca.crt" ] && [ -r "$nd/ca.key" ]; then
  cp "$nd/ca.crt" "$nd/ca.key" "$d/"
  echo "reusing the CA already installed on this Mac: $(openssl x509 -in "$d/ca.crt" -noout -subject)"
elif [ ! -f "$d/ca.key" ]; then
  openssl genrsa -out "$d/ca.key" 2048
  openssl req -x509 -new -nodes -key "$d/ca.key" -sha256 -days 730 \
    -subj "/CN=PowerPuffBoys Local CA" -out "$d/ca.crt"
  echo "created a new CA - every other Mac must now run trust_ca.sh"
fi

# 2. the server certificate
if [ -f "$nd/server.crt" ] && [ -r "$nd/server.key" ] \
   && openssl x509 -in "$nd/server.crt" -noout -checkend 2592000 >/dev/null 2>&1 \
   && covers "$nd/server.crt"; then
  cp "$nd/server.crt" "$nd/server.key" "$d/"
  echo "reusing the installed certificate, valid until $(openssl x509 -in "$d/server.crt" -noout -enddate | cut -d= -f2)"
else
  cat > "$d/server.ext" <<EXT
subjectAltName=DNS:$DOMAIN,DNS:*.$DOMAIN
basicConstraints=CA:FALSE
keyUsage=critical,digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
EXT
  openssl genrsa -out "$d/server.key" 2048
  openssl req -new -key "$d/server.key" -out "$d/server.csr" -subj "/CN=$DOMAIN"
  openssl x509 -req -in "$d/server.csr" -CA "$d/ca.crt" -CAkey "$d/ca.key" -CAcreateserial \
    -out "$d/server.crt" -days 365 -sha256 -extfile "$d/server.ext"
  echo "issued a new certificate"
fi

echo
openssl x509 -in "$d/server.crt" -noout -subject -issuer -ext subjectAltName
openssl verify -CAfile "$d/ca.crt" "$d/server.crt"
echo
echo "Next: ./phase2/run.sh edge here, and trust_ca.sh on any Mac that does not"
echo "already trust this CA. For the standby edge, scp certs/server.crt and"
echo "certs/server.key across - not through git."
