# Event Stack – Ticket Service

FastAPI + Uvicorn microservice that mints ticket tokens, renders QR PNGs,
and records check-ins. Deployed behind Nginx and Cloudflare.

## Run (dev)
1) Copy `.env.sample` to `.env` and set values.
2) `docker compose up -d --build`
3) Health: `curl -sS http://127.0.0.1:8088/healthz` → `ok`

## Endpoints
- `POST /api/v1/mint`  -> `{ token, qr_png_url }`
- `POST /api/v1/checkin` with `{token}` -> increments count
- `GET  /api/v1/status/<token>` -> status JSON
- `GET  /api/v1/qr/<token>.png` -> PNG (cached 4h at edge)

## Notes
- Nginx caches only `/api/v1/qr/...png` for 4 hours.
- All other API endpoints are `no-store` and rate-limited.
- SQLite state is in the `event-stack_sge-data` Docker volume.
