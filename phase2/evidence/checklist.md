# Evidence checklist - the 11 step demo

The brief says the evaluator must find any piece of evidence within 30 seconds.
Save every screenshot into `phase2/evidence/` named by step number.

| # | Step | Who runs it | Command | Save as |
| --- | --- | --- | --- | --- |
| 1 | Topology and inventory | Vetri | show `phase2/README.md` role table and the architecture diagram | 01_topology.png |
| 2 | All machines on the private LAN | everyone | `./phase2/whoami.sh` then `ping` each other | 02_ping_<name>.png |
| 3 | Resolve the private domain | any client | `dig app.powerpuffboys.test +noall +answer` | 03_dig.png |
| 4 | Open over HTTPS by name | any client | `curl -i https://app.powerpuffboys.test/` and the browser | 04_https.png |
| 5 | Load balancing across both backends | any client | `for i in {1..10}; do curl -sD- -o /dev/null https://app.powerpuffboys.test/api/status \| grep -i x-backend; done` | 05_loadbalance.png |
| 6 | Wireshark DNS, TCP, TLS | any client | `./phase2/evidence/capture.sh` then open the pcap | 06_dns.png, 06_tcp.png, 06_tls.png |
| 7 | HTTP headers and caching | any client | `curl -I https://app.powerpuffboys.test/` then repeat with `-H 'If-None-Match: "backend-a-v1"'` | 07_cache_304.png |
| 8 | Fail one backend | Hrishi stops A | ctrl-c on `run_backend_a.sh`, then step 5 again | 08_failover.png |
| 9 | Phase 2 DNS resilience | Adi, Vedant | see Extension A, B, E below | 09_*.png |
| 10 | Faculty injected fault | whole team | `./phase2/troubleshoot/diagnose.sh` | 10_diagnosis.png |
| 11 | Individual viva | everyone | no command - see the viva list below | - |

## Extension evidence, one row each

| Ext | What to show | Commands |
| --- | --- | --- |
| A backup DNS | client keeps resolving after the primary dies | `./phase2/verify.sh client`, then Adi runs `sudo brew services stop dnsmasq`, then `dig app.powerpuffboys.test +short` still answers |
| B TTL | old answer survives, then flips | Client first runs `dscacheutil -q host -a name app.powerpuffboys.test` to cache it. Adi runs `./phase2/dns/cutover.sh <new-ip>`. Client repeats the same `dscacheutil` command and still sees the OLD address for up to 30s, while `dig app... +short` already shows the new one. Then `./phase2/dns/flush_cache.sh` and the cached one flips immediately. Do NOT use `dig` to show the cached answer, it bypasses the cache |
| C isolation | client blocked, edge allowed | Hrishi and Vedant run `./phase2/run.sh isolate`, client runs `./phase2/firewall/check_isolation.sh` |
| D HA failover | traffic continues on one backend, resumes on two | stop Backend A, run step 5, restart it, run step 5 again |
| E edge cutover | DNS moves the edge | Hrishi runs `./phase2/run.sh edge-standby`, Adi runs `cutover.sh <hrishi-ip>`, client sees `X-Edge: standby` |
| F troubleshooting | layered method | `./phase2/troubleshoot/diagnose.sh` and the runbook table |

## Single point of failure, for the Extension D question

The edge nginx on Vetri's Mac. Everything flows through it, so if that Mac dies the
service dies even though both backends are healthy. Removing it would need two edge
machines sharing one address - either two A records for `app.powerpuffboys.test`
(DNS round robin, which is what Extension E sets up by hand), a floating IP that
moves between the two, or a layer 4 balancer in front of both edges.

## Viva questions each member should be able to answer cold

1. Walk one request from typing the name to the JSON response, naming the protocol at each hop.
2. Why does the client never need to know the backend IPs?
3. Where exactly does TLS terminate, and what is unencrypted after that point?
4. Why is the teardown four messages when the handshake is three?
5. What is the difference between a DNS failure and a backend failure, from the client's view?
6. What does the TTL control, and what did you observe during the cutover?
7. Why does a fresh cache hit never reach the server, while a 304 does?
8. Which component is still a single point of failure, and what would fix it?
