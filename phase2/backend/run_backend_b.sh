#!/bin/bash
# Vedant's Mac. Makes the venv on first run, then starts Backend B on 0.0.0.0:3002.
set -e
. "$(dirname "$0")/../lib.sh"
cd "$root"
[ -d .venv ] || python3 -m venv .venv
. .venv/bin/activate
python -m pip install --quiet --upgrade pip
python -m pip install --quiet -r requirements.txt
echo "Backend B on http://0.0.0.0:$BACKEND_B_PORT  (ctrl-c to stop)"
exec python backend_B.py
