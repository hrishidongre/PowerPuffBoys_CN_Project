# Shared helpers. Source this, do not run it.
root=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)
set -a; . "$root/phase2/hosts.env"; set +a

need() {
  for v in "$@"; do
    [ -n "${!v}" ] || { echo "hosts.env is missing $v - fill it in and pull again"; exit 1; }
  done
}

render() {
  sed -e "s|__DOMAIN__|$DOMAIN|g" \
      -e "s|__TTL__|$TTL|g" \
      -e "s|__DNS_PRIMARY_IP__|$DNS_PRIMARY_IP|g" \
      -e "s|__DNS_BACKUP_IP__|$DNS_BACKUP_IP|g" \
      -e "s|__EDGE_IP__|$EDGE_IP|g" \
      -e "s|__EDGE_STANDBY_IP__|$EDGE_STANDBY_IP|g" \
      -e "s|__BACKEND_A_IP__|$BACKEND_A_IP|g" \
      -e "s|__BACKEND_B_IP__|$BACKEND_B_IP|g" \
      -e "s|__EDGE_HTTP_PORT__|$EDGE_HTTP_PORT|g" \
      -e "s|__EDGE_HTTPS_PORT__|$EDGE_HTTPS_PORT|g" \
      -e "s|__BACKEND_A_PORT__|$BACKEND_A_PORT|g" \
      -e "s|__BACKEND_B_PORT__|$BACKEND_B_PORT|g" \
      "$1"
}

ok()   { echo "  PASS  $1"; }
fail() { echo "  FAIL  $1"; failures=$((failures+1)); }
