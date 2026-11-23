# Phase 2 - pull, run your part, verify

Everything here renders from one file: `phase2/hosts.env`. Nobody edits a config
by hand. Pull, run the one command for your machine, run the verifier, done.

## Who is which machine

| Member | Machine | Role | Services |
| --- | --- | --- | --- |
| Pampana Sree Adithya | Mac 1 | primary DNS | dnsmasq on 53 |
| Vetriselvan R | Mac 2 | edge, reverse proxy, load balancer | nginx, TLS termination |
| Hrishi Dongre | Mac 3 | Backend A, standby edge for Extension E | node on 3001 |
| Vedant Madne | Mac 4 | Backend B, backup DNS for Extension A | python on 3002, dnsmasq |

```
              dig app.powerpuffboys.test
   client  ------------------------------->  Mac 1  dnsmasq  (primary DNS)
     |                                       Mac 4  dnsmasq  (backup DNS)
     |      answer: Mac 2's IP, TTL 30
     |
     |      https://app.powerpuffboys.test
     +------------------------------------>  Mac 2  nginx, TLS terminates here
                                               |
                                 round robin    +--> Mac 3  Backend A :3001
                                                +--> Mac 4  Backend B :3002
```

## How this relates to the Phase 1 folders

`dnsmasq/`, `HTTP/`, `TLS/` and `scripts/` are the Phase 1 notes and configs. Leave
them for the review, but do not run from them any more. Three things changed:

- the Phase 1 `dnsmasq/dnsmasq.conf` holds hardcoded IPs (10.7.17.48, 10.7.12.202)
  that DHCP has almost certainly reassigned. `phase2/dns/` generates the same
  records from `hosts.env` instead, and keeps the Phase 1 wildcard record so
  `https://powerpuffboys.test/` still works
- the certificate is unchanged. `TLS/README.md` documents a plain
  `openssl req -x509` command, which would produce a certificate with no
  subjectAltName that Chrome rejects, but that is not what is actually installed:
  the real cert on the edge is signed by "PowerPuffBoys Local CA" and carries
  `powerpuffboys.test` plus the wildcard `*.powerpuffboys.test`, valid to
  September 2027. `phase2/edge/make_certs.sh` detects that and reuses it, so
  nobody has to trust a second root. Worth correcting that README before the viva
- the Phase 1 nginx had no failover settings, so a dead backend produced 502s
  instead of being taken out of rotation

## Step 0 - the IP map, once per session

DHCP changes addresses, so this is the only manual step and it blocks everything else.

1. Everyone runs `./phase2/whoami.sh` and pastes their line in the group chat
2. One person fills `phase2/hosts.env`, commits, pushes
3. Everyone else pulls

If several layers break at once later, this is almost always why.

## Step 1 - your one command

```bash
git pull
./phase2/run.sh <your role>
```

| You | Command |
| --- | --- |
| Adi | `./phase2/run.sh dns-primary` |
| Vetri | `./phase2/edge/make_certs.sh` once, then `./phase2/run.sh edge` |
| Hrishi | `./phase2/run.sh backend-a` |
| Vedant | `./phase2/run.sh backend-b`, and in a second tab `./phase2/run.sh dns-backup` |
| anyone acting as a test client | `./phase2/run.sh client` |

## Step 2 - prove it

```bash
./phase2/verify.sh <your role>
```

It checks the things the brief actually marks: the `X-Backend` header, the 304,
binding to 0.0.0.0 rather than localhost, the TTL being 30, HTTPS working with no
`-k`, and both backends appearing in rotation. Fix anything that says FAIL before
the demo rather than during it.

## Extensions, and who drives each

| Ext | What | Driven by |
| --- | --- | --- |
| A | backup DNS resolver | Vedant runs it, Adi stops his to prove it |
| B | TTL and record change | Adi, with `dns/cutover.sh` |
| C | backend firewall isolation | Hrishi and Vedant, `run.sh isolate`, undo with `firewall/rollback.sh` |
| D | HA failover | Hrishi stops and restarts Backend A |
| E | edge migration | Hrishi runs `run.sh edge-standby`, Adi repoints DNS |
| F | injected fault | whole team, `troubleshoot/diagnose.sh` and `troubleshoot/runbook.md` |

## What still needs a human

Be honest about this in the demo rather than surprised by it.

- **Your admin password.** Changing resolvers, loading pf rules, binding 443 and
  trusting the CA all use `sudo` on your own Mac. The scripts prompt, they cannot
  avoid it.
- **The TLS private key is not in the repo**, and never should be. Vetri generates
  it with `edge/make_certs.sh`. Only `certs/ca.crt` is committed, which is what the
  other Macs need to trust it. For the standby edge, copy `server.crt` and
  `server.key` across with `scp`, not git.
- **Wireshark screenshots, the report wording and the viva** are yours. `evidence/capture.sh`
  produces the pcap and prints the display filters, but someone has to point at the packets.
- **pf firewall rules** could not be tested while writing this, only syntax checked
  with `pfctl -vnf`. Test Extension C once before the demo, and keep `rollback.sh` handy.

## Undo everything

```bash
./phase2/firewall/rollback.sh        # on the backend Macs
./phase2/dns/restore_client_dns.sh   # on each client
sudo brew services stop dnsmasq      # on the DNS Macs
sudo brew services stop nginx        # on the edge
```
