# Phase 2 Report - Harden, Recover, Troubleshoot

Team PowerPuffBoys, Section A

| Member | Enrollment | Machine role |
| --- | --- | --- |
| Hrishi Dongre | 2401010191 | Mac 3 - Backend A, standby edge |
| Pampana Sree Adithya | 2401010315 | Mac 1 - primary DNS |
| Vedant Madne | 2401010499 | Mac 4 - Backend B |
| Vetriselvan R | 2401010501 | Mac 2 - edge reverse proxy, load balancer, backup DNS |

Addresses on the day of writing: primary DNS 10.7.17.223, edge and backup DNS
10.7.17.226, Backend A 10.7.8.234:3001, Backend B 10.7.2.238:3002. Domain
`powerpuffboys.test`, DNS TTL 30 seconds.

## 1. What changed from Phase 1

Phase 1 ended with one DNS server, one edge, two backends and no failure handling.
Three defects in that setup only became visible when we started breaking things:

1. **nginx had no failure detection.** The upstream pool had no `max_fails` or
   `fail_timeout`, so a stopped backend stayed in rotation and every second request
   returned an error instead of failing over. Phase 2 adds `max_fails=2`,
   `fail_timeout=10s` and `proxy_next_upstream`, so a request that hits a dead
   backend is retried against the healthy one inside the same request.
2. **`/api/items` was load balanced although it only exists on Backend B**, so
   roughly half of those requests returned 404. It now has its own upstream.
3. **The two backends disagreed about caching.** Backend A set `Cache-Control` and
   `ETag` on every route, Backend B only on `/`. The same URL therefore cached
   differently depending on which backend answered. Backend B now matches A.

Every configuration value also moved into one file, `phase2/hosts.env`, because the
Phase 1 configs contained hardcoded addresses from October that DHCP had long since
reassigned. Each machine now renders its own config from that shared file.

## 2. Extension A - Backup DNS resolver

A second dnsmasq serves the same records, and clients list both resolvers.

The backup is **not** on Vedant's Mac as originally planned. His machine is enrolled
in the college MDM, and its firewall has dnsmasq set to "block incoming
connections", which `socketfilterfw` refuses to change: "Firewall settings cannot be
modified from command line on managed Mac computers". We proved this was the cause
rather than guessing: dnsmasq was listening correctly on `10.7.2.238:53` for both
TCP and UDP, but its query log only ever recorded `query[A] ... from 127.0.0.1`,
so packets from other machines were being dropped before reaching it. The backup
therefore runs on Mac 2, which the brief permits because it only forbids Mac 1.

Verified:

```
PASS  dnsmasq running
PASS  app.powerpuffboys.test -> 10.7.17.226
PASS  TTL is 30
PASS  answers on the LAN address 10.7.17.226, so other Macs can use it
client resolver list: 10.7.17.223  10.7.17.226
```

A DNS failure and an application failure look completely different from the client.
When DNS fails the name does not resolve at all, yet the service is healthy and can
still be reached by address. When the application fails the name resolves perfectly
and the failure happens afterwards, at the connection or in the response.

The tradeoff we accepted: the edge machine now carries two roles, so losing it
removes both the front door and the backup resolver. In a real deployment those
would be separate machines.

## 3. Extension B - TTL and controlled record change

Records are served with a 30 second TTL, which `dig` confirms:

```
app.powerpuffboys.test.	30	IN	A	10.7.17.226
```

`phase2/dns/cutover.sh <new-ip>` rewrites the `app` record and reloads dnsmasq.

One thing we got wrong at first and had to correct: `dig` queries the server
directly and bypasses the macOS resolver cache, so it shows a changed record
instantly and proves nothing about caching. To see a cached answer survive you must
query through the system resolver, with `dscacheutil -q host -a name
app.powerpuffboys.test`, `ping`, or a browser. `dig` is then useful for the opposite
purpose: showing what the server is already handing out while clients still hold the
old answer.

This is exactly how production traffic cutover works. You lower the TTL in advance,
change the record, and wait out the TTL while old and new clients coexist.

<!-- after running the demo, record: time of change, how long the cached answer survived, what flush showed -->

## 4. Extension C - Service isolation

pf rules on each backend machine block ports 3001 and 3002 from everything except
the edge. pf takes the last matching rule, so the ruleset blocks the ports first and
then passes the edge address:

```
block drop in proto tcp to any port { 3001, 3002 }
pass in proto tcp from <edge ip> to any port { 3001, 3002 }
```

Expected result: from a client Mac, a direct connection to either backend times out,
while the same content is still served through the edge over HTTPS.

<!-- not yet applied at the time of writing; record the before and after here -->

Before isolation, confirmed from a client:

```
direct to backend A 10.7.8.234:3001   REACHABLE
direct to backend B 10.7.2.238:3002   REACHABLE
through the edge                      200
```

Rollback is `phase2/firewall/rollback.sh`, which restores `/etc/pf.conf`.

## 5. Extension D - High availability failover

Normal operation alternates cleanly between the two backends:

```
backend B  upstream 10.7.2.238:3002
backend A  upstream 10.7.8.234:3001
backend B  upstream 10.7.2.238:3002
backend A  upstream 10.7.8.234:3001
... ten requests, five each
```

We also observed real failover without arranging it. Vedant's Mac dropped off the
Wi-Fi mid-session, and the next ten requests were served entirely by Backend A with
no client-visible error:

```
10 requests by name    A A A A A A A A A A
```

An earlier capture shows the mechanism in detail. The `X-Upstream` header lists two
addresses on the requests where nginx tried the dead backend first and moved on
inside the same request, and after two such failures the dead backend was ejected
for ten seconds and the remaining requests went straight to the healthy one:

```
backend A  upstream 10.7.8.234:3001
backend A  upstream 10.7.2.238:3002,     <- tried B, failed, retried A
backend A  upstream 10.7.8.234:3001
backend A  upstream 10.7.2.238:3002,
backend A  upstream 10.7.8.234:3001
backend A  upstream 10.7.8.234:3001      <- B now ejected
```

With both backends stopped the edge returns a clean 502, which is the correct
behaviour: DNS and TLS still work, and the failure is reported at the application
layer only.

**Remaining single point of failure:** the edge itself. Both backends can be healthy
and the service is still unreachable if Mac 2 goes down, and it now also carries the
backup resolver. Removing it would need two edges sharing one address: two A records
for the name, a floating address that moves between them, or a layer 4 balancer in
front of both. Extension E is that move performed manually.

## 6. Extension E - Controlled edge migration

A second nginx with the same configuration runs on Mac 3, started with
`./phase2/run.sh edge-standby`, which tags its responses `X-Edge: standby` so the
switch is visible in the headers. The certificate and key are copied by scp rather
than through git. The DNS record for `app` is then pointed at Mac 3.

<!-- record: time of cutover, what the headers showed, how long before new lookups moved -->

## 7. Extension F - Troubleshooting

Our method is to work bottom up: network, DNS, TCP, TLS, application. A fault low
down makes every layer above it look broken, so starting at the browser wastes time.
`phase2/troubleshoot/diagnose.sh` walks all five and stops at the first failure.

We used this on a real fault during setup. The service stopped resolving, and the
layered check isolated it immediately:

```
edge by IP, bypassing DNS    200
backend A direct             200
backend B direct             200
TCP 53 on the primary DNS    closed
```

Everything above the DNS layer was healthy, so the diagnosis was one stopped service
rather than a broken system. The same method found the Vedant firewall problem in
section 2: ping succeeded, the port accepted connections, the configuration was
correct, and only the query log proved the packets were never arriving.

## 8. Resilience test results

| Test | Expected | Observed | Pass |
| --- | --- | --- | --- |
| Both resolvers answer the same record | identical answer, TTL 30 | both returned 10.7.17.226, TTL 30 | yes |
| Backup answers on its LAN address | reachable from other Macs | yes, on 10.7.17.226 | yes |
| Primary DNS stopped | clients resolve via backup | | |
| Record changed, TTL 30 | cached answer survives, then flips | | |
| Direct access to 3001 and 3002 from a client | blocked after Extension C | currently REACHABLE, not yet applied | not yet |
| Backend unavailable | all traffic via the healthy one, no error | 10 of 10 requests returned 200 | yes |
| Backend restored | both backends back in rotation | alternating A B A B confirmed | yes |
| Both backends stopped | clean 502 at the edge | 502 on every request | yes |
| HTTPS by name with no -k | 200, certificate trusted | 200, verify code 0, HTTP/2, TLS 1.3 | yes |
| Conditional request | 304 Not Modified | 200 then 304 with the ETag | yes |
| Edge cutover via DNS | new lookups hit the standby | | |

## 9. Learning summary

<!-- one short paragraph per extension in your own words. This is 5 marks and must not be copied from above. -->
