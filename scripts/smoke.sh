#!/usr/bin/env bash
set -euo pipefail
BASE="https://tickets.sagariousmedia.cloud"
API_KEY=$(grep -E '^SGE_API_KEY=' .env | head -1 | cut -d= -f2 | tr -d '"')

echo "1) /healthz via CF:"
curl -sS -I "$BASE/healthz" | tr -d '\r' | sed -n '1,10p'

echo; echo "2) mint:"
MINT_JSON=$(curl -sS -X POST "$BASE/api/v1/mint" \
  -H "Content-Type: application/json" -H "X-API-Key: $API_KEY" \
  -d '{"tid":1234,"eid":999,"ttl":86400}')
URL=$(printf '%s' "$MINT_JSON" | python3 -c 'import sys,json; print(json.load(sys.stdin)["qr_png_url"])')
echo "QR URL: $URL"

echo; echo "3) GET png (MISS then HIT expected):"
curl -sS -I "$URL" | tr -d '\r' | sed -n '1,20p'
curl -sS -I "$URL" | tr -d '\r' | sed -n '1,20p'

echo; echo "4) HEAD png (should be 200 but no-store by method-map):"
curl -sS -I -X HEAD "$URL" | tr -d '\r' | sed -n '1,20p'

echo; echo "5) Rate-limit JSON (429 + no-store + retry-after):"
TOKEN=$(printf '%s' "$MINT_JSON" | python3 -c 'import sys,json; print(json.load(sys.stdin)["token"])')
# drive to 429
for i in {1..30}; do
  code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE/api/v1/checkin" \
    -H "Content-Type: application/json" -H "X-API-Key: $API_KEY" \
    -d "{\"token\":\"$TOKEN\"}")
  [ "$code" = "429" ] && break
done
curl -sD - -o /dev/null -X POST "$BASE/api/v1/checkin" \
  -H "Content-Type: application/json" -H "X-API-Key: $API_KEY" \
  -d "{\"token\":\"$TOKEN\"}" | tr -d '\r' | sed -n '1,30p'
echo; echo "--- body ---"
curl -s -X POST "$BASE/api/v1/checkin" \
  -H "Content-Type: application/json" -H "X-API-Key: $API_KEY" \
  -d "{\"token\":\"$TOKEN\"}"
