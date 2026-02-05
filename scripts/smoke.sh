#!/usr/bin/env bash
set -euo pipefail
BASE=https://tickets.sagariousmedia.cloud
API_KEY=$(grep -E '^SGE_API_KEY=' .env | cut -d= -f2 | tr -d '"')

echo "1) /healthz via CF:"
curl -sS -I "$BASE/healthz" | tr -d '\r' | sed -n '1,10p'

echo; echo "2) mint:"
MINT_JSON=$(curl -sS -X POST "$BASE/api/v1/mint" \
  -H "Content-Type: application/json" -H "X-API-Key: $API_KEY" \
  -d '{"tid":1234,"eid":999,"ttl":86400}')
URL=$(python3 - <<PY <<<"$MINT_JSON"
import sys, json; print(json.load(sys.stdin)["qr_png_url"])
PY
)
echo "QR URL: $URL"

echo; echo "3) GET png (MISS then HIT):"
curl -sS -I "$URL" | tr -d '\r' | sed -n '1,20p'
curl -sS -I "$URL" | tr -d '\r' | sed -n '1,20p'

echo; echo "4) HEAD png:"
curl -sS -I -X HEAD "$URL" | tr -d '\r' | sed -n '1,20p'

echo; echo "5) /api/v1/checkin headers (no-store expected, allow: POST):"
curl -sS -I "$BASE/api/v1/checkin" | tr -d '\r' | sed -n '1,20p'
