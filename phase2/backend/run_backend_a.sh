#!/bin/bash
# Hrishi's Mac. Installs deps on first run, then starts Backend A on 0.0.0.0:3001.
set -e
. "$(dirname "$0")/../lib.sh"
cd "$root"
command -v node >/dev/null || { echo "install node first: brew install node"; exit 1; }
[ -d node_modules ] || npm install
echo "Backend A on http://0.0.0.0:$BACKEND_A_PORT  (ctrl-c to stop, which is also the Extension D demo)"
exec node backend_A.js
