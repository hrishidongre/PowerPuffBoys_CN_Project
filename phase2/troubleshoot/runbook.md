# Extension F runbook - diagnosing an injected fault

The faculty will break exactly one thing. Marks come from the method, not from
guessing fast. Say your reasoning out loud while you work.

## The rule

Always test bottom up: network, then DNS, then TCP, then TLS, then HTTP.
A fault at a low layer makes every layer above it look broken, so never start at
the browser.

`./phase2/troubleshoot/diagnose.sh` walks all five in order and stops at the first
failure. Run it first, then confirm by hand with the single command for that layer.

## Symptom to layer

| What you see | Layer | Likely cause | Confirm with |
| --- | --- | --- | --- |
| `ping` to a Mac fails | Network | Machine asleep, wrong Wi-Fi, IP changed by DHCP | `ping <ip>`, `./phase2/whoami.sh` on that Mac |
| Name does not resolve, but `curl https://<edge-ip>` works | DNS | dnsmasq stopped, or client resolver list wrong | `dig @<dns-ip> app.powerpuffboys.test` |
| Name resolves to the wrong IP | DNS record | Record edited, or client holding a cached answer | `dig app... +noall +answer` then flush cache |
| Resolves fine, connection refused or hangs | Transport | nginx down, wrong port, pf rule blocking | `nc -z <edge-ip> 443` |
| Connects then fails instantly with a cert error | TLS | CA not trusted on this Mac, or SAN missing the name | `openssl s_client -connect <ip>:443 -servername app...` |
| 502 Bad Gateway | Application | Both backends stopped, or wrong upstream IP/port | `curl http://<backend-ip>:3001/api/status` from the edge |
| 200 but always the same backend | Load balancing | One backend marked failed, or it really is down | watch `X-Upstream` over 10 requests |
| 404 on a path that works elsewhere | Application | Path exists on only one backend | check which backend served it |

## The four one-liners worth memorising

```bash
dig app.powerpuffboys.test +noall +answer          # DNS, with the TTL visible
nc -z -G 2 <edge-ip> 443                           # is the port open
echo | openssl s_client -connect <edge-ip>:443 -servername app.powerpuffboys.test
curl -i https://app.powerpuffboys.test/api/status  # application, headers included
```

## Things that have actually bitten this setup

- DHCP hands out new IPs after a reconnect, so `phase2/hosts.env` goes stale and
  nginx keeps proxying to an address nobody owns any more. Re-run `whoami.sh` on
  each Mac first if several layers fail at once.
- `/api/items` only exists on Backend B. Before Phase 2 it was round robined, so
  half the requests 404ed. It now has its own upstream.
- A stale DNS answer survives a config change for up to the TTL. That is the
  Extension B demo, and also a false alarm during troubleshooting.
- The two backends use different ETag values for the same URL ("backend-a-v1" and
  "backend-b-v1"). A client that cached from A and then revalidates against B gets
  a fresh 200 instead of a 304. That is not a fault, it is what happens when you
  load balance without shared cache validators, and it is a good answer if the
  faculty asks why a 304 sometimes does not appear.
