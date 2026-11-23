#!/bin/bash
# Run ONCE on the edge Mac (Vetri). Creates a local CA and a cert for the project names.
# ca.crt is safe to commit. The .key files never leave this machine.
set -e
. "$(dirname "$0")/../lib.sh"
d="$root/phase2/edge/certs"
mkdir -p "$d"

if [ ! -f "$d/ca.key" ]; then
  openssl genrsa -out "$d/ca.key" 2048
  openssl req -x509 -new -nodes -key "$d/ca.key" -sha256 -days 365 \
    -subj "/C=IN/O=PowerPuffBoys/CN=PowerPuffBoys Local CA" -out "$d/ca.crt"
fi

cat > "$d/server.cnf" <<CNF
[req]
distinguished_name = dn
req_extensions = ext
prompt = no
[dn]
CN = app.$DOMAIN
[ext]
subjectAltName = DNS:$DOMAIN, DNS:app.$DOMAIN, DNS:api.$DOMAIN
CNF

openssl genrsa -out "$d/server.key" 2048
openssl req -new -key "$d/server.key" -out "$d/server.csr" -config "$d/server.cnf"
openssl x509 -req -in "$d/server.csr" -CA "$d/ca.crt" -CAkey "$d/ca.key" -CAcreateserial \
  -out "$d/server.crt" -days 365 -sha256 \
  -extfile "$d/server.cnf" -extensions ext

echo "made:"
openssl x509 -in "$d/server.crt" -noout -subject -ext subjectAltName
echo
echo "Next: run install_edge.sh here, and trust_ca.sh on every other Mac."
echo "For the standby edge (Extension E), copy certs/server.crt and certs/server.key"
echo "to that Mac by hand - scp, not git."
