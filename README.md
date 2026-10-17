# Pi-hole + Unbound (DNS-over-TLS) on Raspberry Pi OS Trixie

Two containers provide DNS filtering and encrypted, DNSSEC-validating resolution:

```text
Device -> 192.168.1.144:53 -> Pi-hole -> Unbound:5335 -> DoT (port 853) -> Quad9 / Cloudflare
```

Pi-hole blocks ads and trackers. Unbound forwards everything to Quad9 and
Cloudflare over authenticated DNS-over-TLS, spreads queries across them, skips a
provider that's down, and validates DNSSEC locally. If every provider is
unreachable, DNS **fails** instead of falling back to plaintext.

**What this does and doesn't give you:** your ISP can't read or tamper with your DNS
queries. The providers can see them, each seeing a share, tied to your IP address.
Your ISP still sees the IP addresses you connect to. See [DESIGN.md](./DESIGN.md)
for the reasoning behind the setup.

## Requirements

- Raspberry Pi 4 running **Raspberry Pi OS Trixie 64-bit (arm64)**.
- The Pi **already has** the static address `192.168.1.144` (see
  [Prepare the Pi](#prepare-the-pi)). Nothing here changes your network, router,
  or DHCP.
- Synchronized time (DNSSEC fails otherwise), free TCP/UDP 53 and TCP 443, and
  **outbound TCP 853**. Some networks block 853; test with
  `openssl s_client -connect 1.1.1.1:853 </dev/null`.

## Prepare the Pi

These are one-time manual steps; the installer does not do them for you.

### Set up SSH access to the Pi

Run these on the machine you'll connect **from** (your Mac). The Pi needs SSH
enabled and password login working for the first copy. Replace `PI_USER` and
`PI_IP` with your Pi's username and its current address.

```bash
# 1. Create a key on your Mac (choose a passphrase if you want one).
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_pi

# 2. Copy the public key to the Pi. You'll be asked for the Pi's password once.
cat ~/.ssh/id_ed25519_pi.pub | ssh PI_USER@PI_IP \
  'umask 077; mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys'

# 3. Test it, using only that key.
ssh -i ~/.ssh/id_ed25519_pi -o IdentitiesOnly=yes PI_USER@PI_IP
```

- Only the **public** key (`.pub`) goes to the Pi. Keep the private key on your Mac.
- Running step 2 again appends a duplicate line, which is harmless.
- To skip typing the key and address each time, add this to `~/.ssh/config` on your
  Mac, then connect with `ssh pi`:

  ```text
  Host pi
      HostName 192.168.1.144
      User PI_USER
      IdentityFile ~/.ssh/id_ed25519_pi
      IdentitiesOnly yes
  ```

- Once key login works, you can turn off password logins on the Pi
  (`PasswordAuthentication no` in `/etc/ssh/sshd_config`, then
  `sudo systemctl restart ssh`). Keep an existing session open while you test a new
  one so you can't lock yourself out.
- After you give the Pi its static IP below, connect to `192.168.1.144`.

### Give the Pi a static IP

Ethernet is more reliable for a DNS server than Wi-Fi. Raspberry Pi OS Trixie uses
NetworkManager, so use `nmcli`. Run these in a local terminal or over SSH.

```bash
# 1. Find the connection name and confirm your network details.
nmcli connection show          # e.g. "netplan-wlan0-<your-ssid>" or "netplan-eth0"
ip route                       # shows your gateway ("default via ...") and subnet

# 2. Set the static address. Replace the connection name; adjust the gateway and
#    /24 if `ip route` shows something different.
sudo nmcli connection modify "<connection-name>" \
  ipv4.method manual \
  ipv4.addresses 192.168.1.144/24 \
  ipv4.gateway 192.168.1.1 \
  ipv4.dns "192.168.1.1 1.1.1.1"

sudo nmcli connection up "<connection-name>"

# 3. Confirm the new address.
ip -4 addr show
```

- **Your SSH session will drop** when the address changes. Reconnect to
  `192.168.1.144`.
- Pick an address **outside your router's DHCP pool**, or reserve it on the router,
  so nothing else is handed the same address.
- `ipv4.dns` here is only the Pi's own resolver. It is not what your other devices
  use; they get `192.168.1.144` once Pi-hole is running.

### Set up an SSH key for GitHub

Create a key on the **Pi** so it can clone this repo over SSH.

```bash
# 1. Generate the key (choose a passphrase if you want one).
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_github

# 2. Print the public key, then add it at GitHub -> Settings -> SSH and GPG keys
#    -> New SSH key.
cat ~/.ssh/id_ed25519_github.pub

# 3. Tell SSH to use that key for GitHub by adding this to ~/.ssh/config:
#
#      Host github.com
#          HostName github.com
#          User git
#          IdentityFile ~/.ssh/id_ed25519_github
#          IdentitiesOnly yes
#
nano ~/.ssh/config && chmod 600 ~/.ssh/config

# 4. Test it (needs the key from step 2 to already be on GitHub).
ssh -T git@github.com
# Expect: "Hi <username>! You've successfully authenticated, but GitHub does not
# provide shell access." (this command exits with status 1; that's normal)

# 5. Clone the repo.
git clone git@github.com:Anto-Gary/pihole-unbound.git
```

Never copy the private key (the file without `.pub`) anywhere. A key added to your
GitHub account can reach all your repositories. For a Pi that only needs to read
this one repo, a read-only [deploy key](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/managing-deploy-keys)
limits the damage if the Pi is compromised.

## Install

From the cloned repo on the Pi, run:

```bash
sudo ./install.sh
```

This installs Docker (from Docker's signed apt repository) if it's missing,
generates an admin password, pulls the pinned images, starts both containers, and
runs `verify.sh`. It's safe to re-run. Then set each device's DNS server to
`192.168.1.144`.

- Admin UI: `https://192.168.1.144/admin/` (self-signed certificate; compare
  `sudo openssl x509 -in etc-pihole/tls.pem -noout -fingerprint -sha256` with
  what your browser shows before trusting it).
- Password: `grep PIHOLE_PASSWORD .env`. It's stored only in `.env`. install.sh
  generates one if it's unset, or you can set your own (letters and digits only).
  Compose passes it to Pi-hole as `FTLCONF_webserver_api_password`, so it's visible
  to anyone who can run `docker inspect pihole`. After changing it, run
  `sudo ./startPihole.sh` to apply it.
- Settings: copy [.env.example](./.env.example) to `.env` and set `PI_IP` (the Pi's
  IPv4 address), `PI_IP6` (its private `fd..` IPv6 address), `TZ` and optionally
  `PIHOLE_PASSWORD`. The scripts and Compose file read these values, and `.env` is
  not committed.

## Day to day

```bash
sudo ./startPihole.sh                          # start (never changes versions)
sudo ./stopPihole.sh                           # stop; keeps images and data
sudo ./verify.sh                               # DNS, DNSSEC and bogus-signature checks
sudo docker compose logs --tail=100 unbound pihole
```

From another LAN device, expect `NOERROR` with an answer for the first two and
`SERVFAIL` for the third:

```bash
dig @192.168.1.144 example.org A
dig @192.168.1.144 example.org A +tcp
dig @192.168.1.144 fail01.dnssec.works A
```

### Device names

To see names instead of IP addresses in the Pi-hole UI, copy
[hosts/local-hosts.example](./hosts/local-hosts.example) to `hosts/local-hosts.txt`
and add one `IP hostname` per line, for example `192.168.1.26 laptop`. The file is
git-ignored, so your device names stay private. Saving it applies the change
immediately, with no restart. The first time, run `sudo ./startPihole.sh` so Pi-hole
mounts the `hosts/` folder. Names show in the UI after it next refreshes them (a few
minutes), and they resolve on your network too. Give each device a DHCP reservation in
the eero app so its IP doesn't change. Back up `hosts/local-hosts.txt` yourself, since
it isn't in git. The compose file sets `FTLCONF_misc_dnsmasq_lines`, which replaces
any custom dnsmasq lines set in the UI.

### Watching live traffic

Run each in its own terminal and browse from a LAN device. Stop with `Ctrl+C`.

```bash
# Pi-hole: client queries, cache hits, blocks, and forwards to Unbound
sudo docker compose exec pihole tail -f /var/log/pihole/pihole.log

# Unbound: the queries Pi-hole forwarded, and each reply with its lookup time
sudo docker compose logs -f --tail=0 unbound
```

Unbound only logs queries while `log-queries` and `log-replies` are `yes` in
[etc-unbound/pihole.conf](./etc-unbound/pihole.conf). With them set to `no` (the
privacy-friendly default) its log shows only startup and errors. Unbound's log is a
plaintext history of every site visited, so set both back to `no` when you're done,
then run `sudo docker compose restart unbound`. Pi-hole answers cached and blocked
queries itself, so those never appear in Unbound's log.

### IPv6

Pi-hole also listens on the Pi's private (ULA) IPv6 address set as `PI_IP6` in `.env`,
so it isn't reachable from the internet. Test it from another LAN device, using that
address:

```bash
dig @<PI_IP6> example.org AAAA
dig @<PI_IP6> example.org AAAA +tcp
```

Expect `NOERROR` with AAAA records; `sudo ./verify.sh` checks this too. The listener
only helps once your router advertises that address as the IPv6 DNS server (RDNSS /
DHCPv6 DNS), or devices have it set manually. The repo doesn't change your router.
IPv6 queries reach Pi-hole through Docker's proxy, so they appear in the Query Log as
coming from `172.20.0.1` rather than the real device. If the Pi's address ever
changes, update `PI_IP6` in `.env` and re-run `sudo ./startPihole.sh`. The container
won't start while the address is missing. Don't put your public IPv6 address in
`.env` or commit it; `.env` is untracked.

## Things to know

- **Clients can bypass it.** Browsers with their own DoH, VPNs, and IPv6 DNS
  advertised by your router can skip Pi-hole. This repo doesn't change the
  network to prevent that, so point the router's advertised IPv6 DNS at the address
  above or turn IPv6 DNS advertisement off. Don't add a public "secondary" DNS if
  you want consistent filtering.
- **Docker bypasses UFW.** Published ports are exposed before UFW's INPUT rules
  apply, and binding to the LAN address isn't an access policy. Don't port-forward
  this to the internet.
- **Unbound isn't reachable from the LAN.** It has no published ports and only
  answers Pi-hole (`172.20.0.6`) and its own healthcheck.
- **Docker network.** Containers use `172.20.0.0/24` (Pi-hole `.6`, Unbound `.7`).
  If that overlaps something on your host, Docker will refuse to create it; change
  the subnet, both addresses, the Pi-hole upstream, the Unbound ACL in
  [etc-unbound/pihole.conf](./etc-unbound/pihole.conf), and `verify.sh` together.
- **One Pi is a single point of failure.**

If DNSSEC validation fails, check the system time, outbound TCP 853, and
`docker compose logs unbound` first. If DNS stops entirely, the usual cause is port
853 being blocked or both providers being unreachable. To change providers, edit the
`forward-zone` block in [etc-unbound/pihole.conf](./etc-unbound/pihole.conf) and
restart Unbound. Each `forward-addr` needs the provider's certificate hostname after
`#`, and providers should have the same filtering policy. Unbound's root trust anchor lives in the
`pihole-unbound_unbound-state` volume. Don't disable validation or delete that
volume as a first fix.

## Backups and updates

Back up `.env`, `hosts/local-hosts.txt`, `etc-pihole/`, and the `unbound-state` volume with the
containers stopped, preserving ownership and modes.

Images are pinned by tag and digest in [docker-compose.yml](./docker-compose.yml)
(Pi-hole `2026.09.0`, Unbound image `1.26.1-1`, as of 2026-10-15). There's no
auto-updater. To update, read the release notes and advisories, confirm the image
supports arm64, change both the tag and the digest, run `docker compose pull`,
`./startPihole.sh`, and `./verify.sh`, and keep the previous images until the new
ones prove stable.

## References

- [Pi-hole Docker configuration](https://docs.pi-hole.net/docker/configuration/)
- [Docker on Debian](https://docs.docker.com/engine/install/debian/)
- [Unbound image source](https://github.com/madnuttah/unbound-docker)
- [IANA trust anchors](https://www.iana.org/dnssec/files)
