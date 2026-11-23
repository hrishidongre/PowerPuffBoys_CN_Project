#!/bin/bash
# One command per machine. Run from the repo root after a git pull.
#   ./phase2/run.sh backend-a      Hrishi
#   ./phase2/run.sh backend-b      Vedant
#   ./phase2/run.sh dns-primary    Adi
#   ./phase2/run.sh dns-backup     Vedant (second service on his Mac)
#   ./phase2/run.sh edge           Vetri
#   ./phase2/run.sh edge-standby   Hrishi (Extension E only)
#   ./phase2/run.sh client         any Mac acting as a test client
#   ./phase2/run.sh isolate        Hrishi and Vedant (Extension C)
set -e
here=$(cd "$(dirname "$0")" && pwd)
case "$1" in
  backend-a)    exec "$here/backend/run_backend_a.sh" ;;
  backend-b)    exec "$here/backend/run_backend_b.sh" ;;
  dns-primary)  exec "$here/dns/install_dns.sh" ;;
  dns-backup)   exec "$here/dns/install_dns.sh" ;;
  edge)         exec "$here/edge/install_edge.sh" primary ;;
  edge-standby) exec "$here/edge/install_edge.sh" standby ;;
  client)       "$here/edge/trust_ca.sh"; exec "$here/dns/set_client_dns.sh" ;;
  isolate)      exec "$here/firewall/load_rules.sh" ;;
  *)            sed -n '2,12p' "$0"; exit 1 ;;
esac
