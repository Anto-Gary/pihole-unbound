#!/bin/bash
# Stops the containers only; images, networks, and data are kept.
set -euo pipefail
cd "$(dirname "$0")"
exec sudo docker compose stop
