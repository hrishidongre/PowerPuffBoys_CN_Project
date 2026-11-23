#!/bin/bash
# Extension C - put pf back to the macOS default ruleset.
set -e
sudo pfctl -f /etc/pf.conf
before="$(dirname "$0")/.pf_state_before.txt"
if [ -f "$before" ] && grep -q Disabled "$before"; then
  sudo pfctl -d
  echo "pf disabled again, as it was before the demo"
else
  echo "default ruleset restored, pf left enabled"
fi
