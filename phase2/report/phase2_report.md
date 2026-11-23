# Phase 2 Report - Harden, Recover, Troubleshoot

Team PowerPuffBoys, Section A

| Member | Enrollment | Machine role |
| --- | --- | --- |
| Hrishi Dongre | 2401010191 | Mac 3 - Backend A, standby edge |
| Pampana Sree Adithya | 2401010315 | Mac 1 - primary DNS |
| Vedant Madne | 2401010499 | Mac 4 - Backend B, backup DNS |
| Vetriselvan R | 2401010501 | Mac 2 - edge reverse proxy and load balancer |

## 1. What changed from Phase 1

Phase 1 ended with one DNS server, one edge, two backends, and no failure handling.
Three things were wrong or missing for a resilient setup:

- nginx had no `max_fails` or `fail_timeout`, so a dead backend stayed in rotation
  and every second request returned an error instead of failing over.
- `/api/items` was round robined even though it only exists on Backend B, so half
  of those requests returned 404.
- every config held hardcoded IPs, which went stale whenever DHCP changed them.

Phase 2 fixes all three and adds Extensions A to F. All configuration now renders
from one shared file, `phase2/hosts.env`, so the whole team works from one map.

<!-- fill in after the demo: one paragraph per extension, what you ran and what you saw -->

## 2. Extension A - Backup DNS resolver

Setup:
Observed when the primary was stopped:
Why a DNS failure looks different from an application failure:

## 3. Extension B - TTL and controlled record change

TTL used:
Behaviour before the TTL expired:
Behaviour after flushing the cache:
How this maps to production traffic cutover:

## 4. Extension C - Service isolation

Rules applied:
Result from the edge:
Result from a client:
Rollback performed:

## 5. Extension D - High availability failover

Backend A stopped at:
What clients saw:
Behaviour after restarting it:
Remaining single point of failure and what would remove it:

## 6. Extension E - Controlled edge migration

Standby edge:
DNS record changed to:
What the TTL did to in-flight clients:

## 7. Extension F - Troubleshooting challenge

Fault injected:
Layer identified:
How we isolated it:
Fix or workaround:

## 8. Resilience test results

| Test | Expected | Observed | Pass |
| --- | --- | --- | --- |
| Primary DNS stopped | clients resolve via backup | | |
| Record changed, TTL 30s | old answer until expiry | | |
| Direct access to 3001/3002 from a client | blocked | | |
| Backend A stopped | all traffic via B, no client error | | |
| Backend A restarted | both backends in rotation again | | |
| Both backends stopped | 502 at the edge, TLS still fine | | |
| Edge cutover via DNS | new lookups hit the standby | | |

## 9. Learning summary

<!-- one paragraph per extension, in your own words - this is 5 marks -->
