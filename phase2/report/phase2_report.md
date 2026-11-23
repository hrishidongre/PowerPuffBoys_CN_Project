# Phase 2 Report
## Harden, Recover and Troubleshoot

**Team PowerPuffBoys, Section A**

| Member | Enrollment | Machine | Role |
| --- | --- | --- | --- |
| Hrishi Dongre | 2401010191 | Mac 3, 10.7.8.234 | Backend A, standby edge |
| Pampana Sree Adithya | 2401010315 | Mac 1, 10.7.17.223 | Primary DNS |
| Vedant Madne | 2401010499 | Mac 4, 10.7.2.238 | Backend B |
| Vetriselvan R | 2401010501 | Mac 2, 10.7.17.226 | Edge proxy, load balancer, backup DNS |

Private domain `powerpuffboys.test`. DNS TTL 30 seconds. Backends on ports 3001 and
3002. Edge on 80 and 443 with TLS terminated at nginx.

---

## 1. Architecture

```
              dig app.powerpuffboys.test
   client  ------------------------------->  Mac 1  dnsmasq   primary DNS
     |                                       Mac 2  dnsmasq   backup DNS
     |      answer: 10.7.17.226, TTL 30
     |
     |      https://app.powerpuffboys.test
     +------------------------------------>  Mac 2  nginx, TLS terminates here
                                               |
                                 round robin    +--> Mac 3  Backend A :3001
                                                +--> Mac 4  Backend B :3002
```

A client resolves the private name through the team's own DNS, opens an HTTPS
connection to the edge, and the edge forwards the request as plain HTTP over the
trusted LAN to one of two backends. The client never learns a backend address.

---

## 2. What changed from Phase 1

Phase 1 delivered the path above, but three defects only surfaced once we began
breaking things deliberately.

**nginx had no failure detection.** The upstream pool carried no `max_fails` or
`fail_timeout`, so a stopped backend stayed in rotation and roughly every second
request failed instead of failing over. Phase 2 adds `max_fails=2`,
`fail_timeout=10s` and `proxy_next_upstream`, so a request that lands on a dead
backend is retried against the healthy one inside the same request, and the dead
backend is ejected from rotation for ten seconds.

**`/api/items` was load balanced although it exists only on Backend B**, so about
half of those requests returned 404. It now has a dedicated upstream.

**The two backends disagreed about caching.** Backend A set `Cache-Control` and
`ETag` on every route, Backend B only on `/`. The same URL therefore cached
differently depending on which backend answered. Backend B now matches A.

All configuration also moved into a single file, `phase2/hosts.env`. The Phase 1
configs contained hardcoded addresses from October that DHCP had long since
reassigned, which made the whole system look broken at several layers at once. Each
machine now renders its own config from that shared file, and a mismatch is a one
line fix rather than four.

---

## 3. Extension A - Backup DNS resolver

A second dnsmasq serves identical records, and every client lists both resolvers.

**The backup is not on the machine we originally planned.** Vedant's Mac is enrolled
in the college MDM. Its firewall has dnsmasq set to "block incoming connections",
and `socketfilterfw` refuses every change with *"Firewall settings cannot be
modified from command line on managed Mac computers."*

We proved that was the cause rather than assuming it. dnsmasq was listening
correctly on the LAN address:

```
udp4   10.7.2.238.53    LISTEN
tcp4   10.7.2.238.53    LISTEN
```

but its own query log only ever recorded local traffic:

```
query[A] app.powerpuffboys.test from 127.0.0.1
query[A] app.powerpuffboys.test from 127.0.0.1
```

Queries from other machines never reached the process, so the block was below
dnsmasq, in the firewall. The backup therefore runs on Mac 2, which the brief
permits since it only forbids Mac 1.

Verified state:

```
PASS  dnsmasq running
PASS  app.powerpuffboys.test -> 10.7.17.226
PASS  TTL is 30
PASS  answers on the LAN address 10.7.17.226, so other Macs can use it

primary: app.powerpuffboys.test.  TTL 30  ->  10.7.17.226
backup : app.powerpuffboys.test.  TTL 30  ->  10.7.17.226
client resolver list: 10.7.17.223  10.7.17.226
```

**DNS failure versus application failure.** They look nothing alike from the client.
When DNS fails the name does not resolve at all, yet the service is perfectly
healthy and still reachable by address. When the application fails the name resolves
correctly and the failure happens afterwards, at the connection or in the response.
One is the phone book being missing, the other is nobody answering the phone.

**Tradeoff we accepted.** The edge machine now carries two roles, so losing Mac 2
removes both the front door and the backup resolver. In a real deployment those
would be separate machines; here the alternative machine is centrally managed and
cannot accept inbound DNS.

> **To record during the demonstration:** the time the primary was stopped, what `dig app.powerpuffboys.test` returned from a client while it was down, and the time it was restarted.

---

## 4. Extension B - TTL and controlled record change

Records are served with a 30 second TTL:

```
app.powerpuffboys.test.	30	IN	A	10.7.17.226
```

`phase2/dns/cutover.sh <new-ip>` rewrites the `app` record and reloads dnsmasq.

**A mistake we made and corrected.** Our first attempt used `dig` to show the cached
answer surviving. `dig` queries the server directly and bypasses the macOS resolver
cache, so it reported the new address immediately and appeared to prove the TTL did
nothing. To observe a cached answer you must go through the system resolver:

```
dscacheutil -q host -a name app.powerpuffboys.test
```

`dig` is then useful for the opposite purpose, showing what the server is already
handing out while clients still hold the old answer. The contrast between the two
commands is the demonstration.

**Why this matters in production.** This is exactly how traffic is moved between
machines without downtime. The TTL is lowered in advance, the record is changed, and
for one TTL window old and new clients coexist, both being served correctly. Only
after the window has passed can the old machine be retired.

> **To record during the demonstration:** the time of the record change, what `dscacheutil` returned immediately before and after, how long the cached answer survived, and what changed after `flush_cache.sh`.

---

## 5. Extension C - Service isolation

pf rules on each backend machine block ports 3001 and 3002 from everything except
the edge. pf applies the last matching rule, so the ruleset blocks first and passes
the edge afterwards:

```
block drop in proto tcp from any to any port { 3001, 3002 }
pass in proto tcp from 10.7.17.226 to any port { 3001, 3002 }
pass in proto tcp from 10.7.8.234 to any port { 3001, 3002 }
```

The macOS anchors are re-included in the same ruleset, which is why the machines'
normal networking continues to work after `pfctl -f`:

```
Loading anchor com.apple from /etc/pf.anchors/com.apple
pf enabled
```

**Before**, from a client machine:

```
direct to backend A 10.7.8.234:3001    REACHABLE
direct to backend B 10.7.2.238:3002    REACHABLE
through the edge                       200
```

**After**, tested from both sides, which is the point of the extension:

```
from the edge   10.7.17.226    backend A 3001 : 200       allowed
from the edge   10.7.17.226    backend B 3002 : 200       allowed
from a client   10.7.2.238     to 3001        : blocked
service by name through the edge        200, A B A B A B A B
```

The backends are now unreachable to everything except the front door, and the
service is unaffected. Rollback is `phase2/firewall/rollback.sh`, which restores
`/etc/pf.conf`, and was run after the demonstration.

---

## 6. Extension D - High availability failover

Normal operation alternates cleanly between the two backends:

```
backend B  upstream 10.7.2.238:3002
backend A  upstream 10.7.8.234:3001
backend B  upstream 10.7.2.238:3002
backend A  upstream 10.7.8.234:3001
... ten requests, five to each
```

**We observed genuine failover without arranging it.** Vedant's Mac dropped off the
Wi-Fi mid-session. The next ten requests were served entirely by Backend A with no
client-visible error:

```
10 requests by name    A A A A A A A A A A
```

A separate capture shows the mechanism. The `X-Upstream` header lists two addresses
on the requests where nginx tried the dead backend first and moved on within the
same request. After two such failures the dead backend was ejected for ten seconds,
and subsequent requests went straight to the healthy one:

```
backend A  upstream 10.7.8.234:3001
backend A  upstream 10.7.2.238:3002,     <- tried B, failed, retried A
backend A  upstream 10.7.8.234:3001
backend A  upstream 10.7.2.238:3002,
backend A  upstream 10.7.8.234:3001
backend A  upstream 10.7.8.234:3001      <- B now ejected from rotation
```

With both backends stopped the edge returns a clean 502 on every request, which is
the correct behaviour. DNS and TLS still succeed; only the application layer fails,
which tells you exactly where the boundary between edge and backend lies.

**Remaining single point of failure: the edge.** Both backends can be perfectly
healthy and the service is still unreachable if Mac 2 goes down, and that machine
now also carries the backup resolver. Removing it would require two edges sharing
one address: two A records for the name so DNS spreads clients across both, a
floating address that can move between them, or a layer 4 balancer in front of both.
Extension E is that migration performed by hand.

> **To record during the demonstration:** the time Backend A was stopped, the ten request output while it was down, the time it was restarted, and the output afterwards.

---

## 7. Extension E - Controlled edge migration

A second nginx runs on Mac 3 with the same configuration, started with
`./phase2/run.sh edge-standby`. It tags every response `X-Edge: standby`, so the
switch is visible in the response headers rather than having to be taken on trust.
The certificate and key are copied across with `scp`, never through git, because the
private key must not enter the repository.

The DNS record for `app` is then pointed at Mac 3. Because of the 30 second TTL,
clients holding a cached answer continue to reach the old edge while new lookups go
to the standby, and both serve correctly during that window.

> **To record during the demonstration:** the time of the cutover, the `X-Edge` header before and after, and how long before cached clients moved to the standby.

---

## 8. Extension F - Troubleshooting method

We work from the bottom up: network, DNS, TCP, TLS, application. A fault low in the
stack makes every layer above it look broken, so starting at the browser wastes
time. `phase2/troubleshoot/diagnose.sh` walks all five and stops at the first
failure.

**Case 1, during setup, the service stopped resolving.** The layered check isolated
it in seconds:

```
edge by IP, bypassing DNS    200
backend A direct             200
backend B direct             200
TCP 53 on the primary DNS    closed
```

Everything above the DNS layer was healthy, so the diagnosis was one stopped
service, not a broken system.

**Case 2, the backup resolver answered locally but not over the network.** Ping
succeeded. The port accepted connections. The configuration was correct and
identical to the working primary. Only the query log settled it, by proving the
packets were never arriving, which pointed below dnsmasq to the firewall. That
became section 3.

| Layer | Question | Command |
| --- | --- | --- |
| Network | Can I reach the machine at all? | `ping 10.7.17.226` |
| DNS | Does the name become an address? | `dig app.powerpuffboys.test` |
| TCP | Is the port open? | `nc -z 10.7.17.226 443` |
| TLS | Is the certificate accepted? | `openssl s_client -connect 10.7.17.226:443` |
| HTTP | Does the application answer? | `curl -i https://app.powerpuffboys.test/api/status` |

---

## 9. Test results

| Test | Expected | Observed | Pass |
| --- | --- | --- | --- |
| Both resolvers answer identically | same record, TTL 30 | both returned 10.7.17.226, TTL 30 | yes |
| Backup answers on its LAN address | reachable from other Macs | yes, on 10.7.17.226 | yes |
| HTTPS by name, no `-k` | 200, certificate trusted | 200, verify code 0, HTTP/2, TLS 1.3 | yes |
| Load balancing | both backends serve | alternating A B A B over 10 requests | yes |
| Conditional request | 304 Not Modified | 200, then 304 with the ETag | yes |
| Backend unavailable | traffic continues, no client error | 10 of 10 returned 200 from the survivor | yes |
| Backend restored | both back in rotation | alternating A B confirmed | yes |
| Both backends stopped | clean 502 at the edge | 502 on every request | yes |
| Direct access to 3001 from a client | blocked | blocked after pf rules loaded | yes |
| Direct access from the edge | allowed | 200 on both 3001 and 3002 | yes |
| Primary DNS stopped | clients resolve via backup | | |
| Record changed, TTL 30 | cached answer survives, then flips | | |
| Edge cutover via DNS | new lookups reach the standby | | |

TLS detail recorded at the edge:

```
status 200   verify 0 (trusted)   HTTP/2
Protocol: TLSv1.3
Cipher:   TLS_AES_256_GCM_SHA384
subject=CN=powerpuffboys.test
issuer=CN=PowerPuffBoys Local CA
Verify return code: 0 (ok)
```

---

## 10. Learning summary

**Extension A.** Running a second resolver is easy; making it usable is not. The
service was correct and listening on the right address from the first attempt, and
still no other machine could use it, because a host firewall was dropping packets
before the process saw them. The lesson is that "the service is running" and "the
service is reachable" are separate claims needing separate evidence.

**Extension B.** A TTL is a promise about how stale an answer may be, and the client
is the one keeping that promise, not the server. That is why our first attempt
proved nothing: we measured the server with `dig` when the behaviour we wanted to
show lived in the client's cache. It also explains why production cutovers lower the
TTL in advance rather than at the moment of the change.

**Extension C.** Putting a reverse proxy in front of the backends is not only about
sharing load. Once clients have no reason to reach a backend directly, you can
remove their ability to, and the firewall rule is a two line statement of something
the architecture already implied.

**Extension D.** Failover is not automatic just because there are two servers. Our
Phase 1 nginx had two backends and still failed every second request, because
nothing told it to notice a dead one. Three directives changed that from a broken
service into an invisible one.

**Extension E.** DNS is a control plane. Changing where a name points moves real
traffic between machines, and the TTL decides how long the two worlds overlap. It is
the cheapest migration tool available and needs no new hardware.

**Extension F.** Diagnosing by layer turned two confusing failures into single
sentences. In both cases the symptom appeared at the top of the stack and the cause
was several layers below it, and the habit of testing upward from the network is
what found them quickly.

---

## 11. Deliverables

| Item | Location |
| --- | --- |
| Configuration for every machine | `phase2/`, rendered from `phase2/hosts.env` |
| One command per machine | `phase2/run.sh <role>` |
| Per role verification | `phase2/verify.sh <role>` |
| Backend source | `backend_A.js`, `backend_B.py` |
| Firewall rules and rollback | `phase2/firewall/` |
| Troubleshooting runbook | `phase2/troubleshoot/runbook.md` |
| Evidence and capture helpers | `phase2/evidence/` |
| Demonstration checklist | `phase2/evidence/checklist.md` |
