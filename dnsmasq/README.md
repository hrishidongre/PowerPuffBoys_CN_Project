# Private DNS Server — dnsmasq (Mac 1)

Config file: `/opt/homebrew/etc/dnsmasq.conf`

```
listen-address=127.0.0.1,10.7.17.48
address=/powerpuffboys.test/10.7.12.202
```

- `listen-address` — interfaces dnsmasq accepts queries on: loopback
  (local testing) and Mac 1's LAN IP (so other machines can query it).
- `address=/powerpuffboys.test/10.7.12.202` — static record: any query
  for `powerpuffboys.test` resolves to `10.7.12.202` (Mac 2, nginx).
- Clients set their DNS resolver to Mac 1's IP manually.
- Verify: `dig powerpuffboys.test` from a client — `SERVER:` should
  show Mac 1, answer should show `10.7.12.202`.
- Start: `sudo brew services start dnsmasq`; restart after edits.
