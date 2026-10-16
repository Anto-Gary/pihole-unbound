#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
exec sudo docker compose up -d --wait --wait-timeout 240
