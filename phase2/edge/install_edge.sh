#!/bin/bash
# Run on the edge Mac (Vetri), and again on the standby edge Mac for Extension E.
# Usage: ./install_edge.sh [primary|standby]
set -e
. "$(dirname "$0")/../lib.sh"
need BACKEND_A_IP BACKEND_B_IP
role=${1:-primary}

command -v nginx >/dev/null || brew install nginx
brew=$(brew --prefix)
d="$root/phase2/edge/certs"
[ -f "$d/server.crt" ] || { echo "no cert yet - run make_certs.sh first (or scp certs/ from the primary edge)"; exit 1; }

sudo mkdir -p "$brew/etc/nginx/certs" "$brew/etc/nginx/servers"
# Only copy if it differs, so an already working certificate is left alone.
cmp -s "$d/server.crt" "$brew/etc/nginx/certs/server.crt" || {
  sudo cp "$d/server.crt" "$d/server.key" "$brew/etc/nginx/certs/"
  sudo chmod 600 "$brew/etc/nginx/certs/server.key"
  echo "installed the certificate from the repo"
}

render "$root/phase2/edge/powerpuffboys.conf.tmpl" \
  | sed -e "s|__BREW__|$brew|g" -e "s|__EDGE_ROLE__|$role|g" \
  | sudo tee "$brew/etc/nginx/servers/powerpuffboys.conf" >/dev/null

# Phase 1 may have installed a config under a different filename. Two server
# blocks claiming the same name means nginx silently ignores one of them.
others=$(grep -ls "powerpuffboys" "$brew"/etc/nginx/servers/* 2>/dev/null | grep -v "/powerpuffboys.conf$" || true)
if [ -n "$others" ]; then
  echo "WARNING - these other nginx configs also claim the powerpuffboys names:"
  echo "$others"
  echo "Move them out of servers/ before the demo."
fi
grep -q "servers/\*" "$brew/etc/nginx/nginx.conf" || echo "WARNING - nginx.conf does not include servers/*, so this config will not load"

sudo nginx -t
sudo nginx -s reload 2>/dev/null || sudo brew services restart nginx
echo "edge up as '$role' on ports $EDGE_HTTP_PORT and $EDGE_HTTPS_PORT"
