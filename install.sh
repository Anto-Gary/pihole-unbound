#!/bin/bash
# Installs Docker if needed, then starts Pi-hole + Unbound.
# Usage: sudo ./install.sh
set -euo pipefail

[[ $EUID -eq 0 ]] || exec sudo "$0" "$@"
cd "$(dirname "$0")"

PI_IP=192.168.1.144

fail() { echo "Error: $*" >&2; exit 1; }

# shellcheck source=/dev/null
. /etc/os-release
[[ ${VERSION_CODENAME:-} == trixie && $(dpkg --print-architecture) == arm64 ]] ||
    fail "Raspberry Pi OS Trixie 64-bit (arm64) is required."
ip -4 -o addr show | grep -qF "inet $PI_IP/" ||
    fail "This Pi must already have the address $PI_IP. No network settings are changed."
[[ $(timedatectl show -p NTPSynchronized --value) == yes ]] ||
    echo "Warning: system time is not synchronized; DNSSEC validation will fail until it is." >&2

if ! docker compose version >/dev/null 2>&1; then
    command -v docker >/dev/null 2>&1 &&
        fail "Docker is installed without the Compose plugin. Install docker-compose-plugin and re-run."
    apt-get update
    apt-get install -y ca-certificates curl
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
    tee /etc/apt/sources.list.d/docker.sources >/dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $VERSION_CODENAME
Components: stable
Architectures: arm64
Signed-By: /etc/apt/keyrings/docker.asc
EOF
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    systemctl enable --now docker
fi
apt-get install -y bind9-dnsutils openssl

install -d -m 0700 .secrets
[[ -s .secrets/pihole_password ]] || (umask 077; openssl rand -hex 32 > .secrets/pihole_password)

docker compose pull
docker compose up -d --wait --wait-timeout 240 ||
    { docker compose ps >&2; fail "Startup failed. See: sudo docker compose logs"; }
./verify.sh

cat <<EOF

Done. Set each device's DNS server to $PI_IP.
Admin UI: https://$PI_IP/admin/ (self-signed certificate)
Admin password: sudo cat $PWD/.secrets/pihole_password
EOF
