#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
docker compose pull || true
docker compose up -d --build
sudo nginx -t && sudo systemctl reload nginx
./scripts/smoke.sh
