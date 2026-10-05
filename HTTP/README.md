# HTTP — Reverse Proxy Forwarding (Mac 2)

Mac 2 runs nginx as the single public entry point. Clients only ever
talk to Mac 2 — they never know the backend IPs.

- nginx receives the (now-decrypted) request and forwards it to one of
  the backends (Mac 3 / Mac 4) as plain HTTP over the LAN, via
  `proxy_pass` to an `upstream` pool.
- This internal hop is unencrypted — TLS was already terminated at
  the edge, so encryption doesn't need to be repeated to the backend
  on a trusted private network.
- The backend's response (JSON + `X-Backend` header) travels back to
  nginx, which re-sends it to the client over the existing HTTPS
  connection.
- Verify: `curl -I http://10.7.6.68:3001/` directly on the LAN
  to confirm the backend itself speaks plain HTTP with no TLS.
