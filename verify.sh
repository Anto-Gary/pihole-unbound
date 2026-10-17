#!/bin/bash
# Checks real DNS answers (not just exit codes). Usage: sudo ./verify.sh
set -euo pipefail

[[ $EUID -eq 0 ]] || exec sudo "$0" "$@"
cd "$(dirname "$0")"

[[ -f .env ]] || { echo "Error: missing .env. Copy .env.example to .env and set PI_IP and PI_IP6." >&2; exit 1; }
set -a
# shellcheck source=/dev/null
. ./.env
set +a
: "${PI_IP:?Set PI_IP in .env}" "${PI_IP6:?Set PI_IP6 in .env}"

check() { # description, expected status, dig output
    grep -q "status: $2," <<< "$3" || { echo "FAIL: $1 (expected $2)" >&2; exit 1; }
}

for transport in +notcp +tcp; do
    answer=$(dig "@$PI_IP" example.org A "$transport" +time=5 +tries=2)
    check "Pi-hole $transport" NOERROR "$answer"
    grep -Eq '^example\.org\.[[:space:]]+[0-9]+[[:space:]]+IN[[:space:]]+A[[:space:]]' <<< "$answer" ||
        { echo "FAIL: Pi-hole $transport returned no A record" >&2; exit 1; }
done

for transport in +notcp +tcp; do
    answer=$(dig "@$PI_IP6" example.org AAAA "$transport" +time=5 +tries=2)
    check "Pi-hole IPv6 listener $transport" NOERROR "$answer"
    grep -Eq '^example\.org\.[[:space:]]+[0-9]+[[:space:]]+IN[[:space:]]+AAAA[[:space:]]' <<< "$answer" ||
        { echo "FAIL: Pi-hole IPv6 listener $transport returned no AAAA record" >&2; exit 1; }
done

# Runs inside Pi-hole so Unbound's source-address ACL is exercised too.
signed=$(docker compose exec -T pihole dig @172.20.0.7 -p 5335 dnssec.works A +dnssec +time=10 +tries=2)
check "Unbound signed answer" NOERROR "$signed"
grep -Eq '^;; flags:.*[ ;]ad[ ;]' <<< "$signed" || { echo "FAIL: Unbound did not validate DNSSEC" >&2; exit 1; }

# A random name forces an upstream lookup; then confirm Unbound is talking TLS (port 853).
docker compose exec -T pihole dig @172.20.0.7 -p 5335 "verify-$RANDOM.example.org" A +time=10 >/dev/null || true
if docker compose exec -T unbound netstat -tn 2>/dev/null | grep -q ':853 '; then
    echo "OK: Unbound has TLS connections to its providers (port 853)."
else
    echo "WARN: no port-853 connections seen; check 'docker compose logs unbound'." >&2
fi

check "bogus DNSSEC rejection" SERVFAIL "$(dig "@$PI_IP" fail01.dnssec.works A +time=10 +tries=2)"

echo "OK: UDP, TCP, DNSSEC validation, and bogus-signature rejection all passed."
echo "Also test from another LAN device; a query on the Pi doesn't prove LAN reachability."
