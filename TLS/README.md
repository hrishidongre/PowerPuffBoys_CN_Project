# TLS — Certificate & Handshake (Mac 2)

Mac 2 terminates TLS on port 443 before forwarding requests on as
plain HTTP (see README_HTTP.md).

**Certificate generation (on Mac 2):**
```
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout server.key -out server.crt
```
Self-signed cert + 2048-bit RSA key, valid 365 days, key unencrypted
(`-nodes`) so nginx can read it without a passphrase.

**Trusting it on each client:**
```
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ~/Downloads/ca.crt
```
Installs the cert into the System keychain as a trusted root, so
browsers/curl stop showing warnings for it.

**Handshake:** ClientHello → ServerHello → Certificate → Key Exchange
→ Finished. After this, all data is encrypted — visible in Wireshark
as handshake packets followed by opaque "Application Data" packets.

**Verify:** `curl -I https://powerpuffboys.test/` — `200 OK`, no
certificate warning.