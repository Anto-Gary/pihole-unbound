# Design notes

Pi-hole (filtering) forwards to Unbound (DNSSEC validation + DNS-over-TLS forwarding),
as two containers on a Raspberry Pi 4 running Raspberry Pi OS Trixie 64-bit.

## Decisions

- **Encrypted forwarding, not recursion.** Unbound forwards every query over
  authenticated DoT to Quad9 (`9.9.9.10`, unfiltered) and Cloudflare (`1.1.1.1`).
  This hides DNS from your ISP and is faster and more reliable than recursing from
  the root servers. The trade-off: the providers see your queries (each a share, tied
  to your IP) instead of your ISP. Full recursion avoids any provider but exposes
  plaintext DNS to your ISP and is slower on cold lookups; it was the earlier design.
- **Spread and fail closed.** Unbound picks randomly among responsive upstreams and
  skips dead ones. `forward-first: no` means it never falls back to plaintext or to
  its own recursion, so a blocked port 853 is an outage, not a silent downgrade.
- **Unfiltered upstreams.** Pi-hole does the blocking; mixing a filtered and an
  unfiltered provider would make answers inconsistent.
- **Validation stays local.** Unbound validates DNSSEC itself rather than trusting
  the providers to.
- **No network changes.** The Pi must already own `192.168.1.144`; the installer
  only checks. Docker's local bridge, routes and NAT rules are the only side effects.
- **Two containers, no more.** Unbound is the DoT client, so no separate proxy is
  needed. DoH was not chosen: it adds a container for no benefit over DoT here.
- **Pinned images (tag + digest).** Pi-hole `2026.09.0` (FTL 6.7.1) and
  `madnuttah/unbound:1.26.1-1` (Unbound 1.26.1), both with arm64 manifests, both
  including recent security fixes. Revalidate before updating.
- **Explicit Unbound config.** The image reads `/usr/local/unbound/unbound.conf`. Its
  default config allows any client and transfers the root zone, so
  [etc-unbound/pihole.conf](./etc-unbound/pihole.conf)
  replaces it: ACL limited to Pi-hole and the DoT forwarding block.
- **Root trust anchor persisted** in a named volume (RFC 5011 state). IANA's root
  key rolled over on 2026-10-11, so stale anchor state is the main DNSSEC failure to
  watch for.
- **Hardening that was kept:** Unbound runs as UID 1000 with no capabilities, a
  read-only root filesystem and `no-new-privileges`; Unbound has no published ports;
  Pi-hole drops `NET_RAW`; DHCP and NTP services are off; admin is HTTPS-only.
  Pi-hole keeps the capabilities its startup needs; a stricter profile wasn't
  assumed to work.
- **Password as a Compose secret** (`.secrets/pihole_password`, untracked, mode 0600).
  It's a file mount, not an encrypted vault.
- **Pi-hole's own DNSSEC is off.** Unbound is the single validating layer.

## What was deliberately left out

Extra preflight checks that Docker or Compose already enforce (subnet overlap,
remote contexts, plugin versions), a mock test suite, and automatic backups. Keeping
install to one script made failures easier to read.

## Not yet verified

The forward block was tested with a local Unbound 1.23.1 on a Mac (the image runs 1.26.1): DNSSEC validated
(`ad` flag), a bogus signature returned `SERVFAIL`, and TLS connections to all four
provider addresses were open. Otherwise only static checks have run (shell syntax,
ShellCheck, Compose parsing). Still to confirm on the Pi: arm64 startup with the
read-only/no-capability Unbound profile, that the image has its CA bundle at
`/etc/ssl/certs/ca-certificates.crt` (a wrong path would break upstream
authentication), the trust-anchor volume's first-run ownership, that outbound
port 853 is open on your network, LAN reachability, filtering, and reboot recovery.
The port-853 check in `verify.sh` is a warning rather than a failure because its
`netstat` use inside the container hasn't been tested.
