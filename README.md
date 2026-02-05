# event-stack

Small ticket service (FastAPI/Uvicorn) behind Nginx. QR PNGs are cacheable at Cloudflare; all other API routes are no-store.

## Stack
- Python 3.11 (FastAPI, Uvicorn)
- Docker Compose
- Nginx (HTTPS, Cloudflare real IP + caching)

## Quickstart
cp .env.example .env
# set SGE_SECRET and SGE_API_KEY in .env
docker compose up -d --build

## Endpoints
GET  /healthz                  -> ok
POST /api/v1/mint              -> { token, qr_png_url }
POST /api/v1/checkin
GET  /api/v1/status/{token}

## Nginx behavior
/api/v1/qr/    -> Cache-Control: public, max-age=14400, immutable
(other /api/**)-> Cache-Control: no-store

### Caching / headers contract
- `GET /api/v1/qr/{token}.png` → `Cache-Control: public, max-age=14400, immutable` (Cloudflare MISS→HIT)
- `HEAD /api/v1/qr/{token}.png` → `Cache-Control: no-store` (method-mapped)
- All other `/api/**` → `Cache-Control: no-store`
- Rate limit (`/api/v1/checkin`): `429` JSON with `Retry-After: 10` and `Cache-Control: no-store`
