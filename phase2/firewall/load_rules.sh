#!/bin/bash
# Extension C - run on Hrishi's and Vedant's Macs.
# Blocks 3001/3002 from everyone except the edge, so clients must go through nginx.
set -e
. "$(dirname "$0")/../lib.sh"
need EDGE_IP

f=/etc/pf.powerpuffboys.conf
pfctl -s info 2>/dev/null | head -1 > "$root/phase2/firewall/.pf_state_before.txt" || true

{
  echo "# Team PowerPuffBoys - Extension C service isolation. Generated, do not edit."
  echo "set skip on lo0"
  echo 'scrub-anchor "com.apple/*"'
  echo 'nat-anchor "com.apple/*"'
  echo 'rdr-anchor "com.apple/*"'
  echo 'dummynet-anchor "com.apple/*"'
  echo 'anchor "com.apple/*"'
  echo 'load anchor "com.apple" from "/etc/pf.anchors/com.apple"'
  echo
  echo "# pf takes the LAST matching rule, so the block comes first and the passes win."
  echo "block drop in proto tcp to any port { $BACKEND_A_PORT, $BACKEND_B_PORT }"
  echo "pass in proto tcp from $EDGE_IP to any port { $BACKEND_A_PORT, $BACKEND_B_PORT }"
  [ -n "$EDGE_STANDBY_IP" ] && echo "pass in proto tcp from $EDGE_STANDBY_IP to any port { $BACKEND_A_PORT, $BACKEND_B_PORT }"
} | sudo tee "$f" >/dev/null

sudo pfctl -vnf "$f"
sudo pfctl -E -f "$f"
echo
echo "rules loaded. Expected from now on:"
echo "  from the edge Mac   : curl http://<this ip>:$BACKEND_A_PORT/api/status  works"
echo "  from any client Mac : same command hangs then times out"
echo "Undo with ./rollback.sh when the demo is over."
