#!/bin/bash
# Extension C evidence. Run from a CLIENT Mac - both of these must fail,
# then the same names over https through the edge must succeed.
. "$(dirname "$0")/../lib.sh"
for pair in "$BACKEND_A_IP:$BACKEND_A_PORT" "$BACKEND_B_IP:$BACKEND_B_PORT"; do
  ip=${pair%:*}; port=${pair#*:}
  printf "direct to %s:%s ... " "$ip" "$port"
  if nc -z -G 3 "$ip" "$port" 2>/dev/null; then echo "REACHABLE - isolation is NOT working"; else echo "blocked, as intended"; fi
done
printf "through the edge ... "
curl -s -o /dev/null -w "%{http_code}\n" "https://app.$DOMAIN/api/status"
