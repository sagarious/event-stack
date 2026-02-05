SHELL := /bin/bash
API_HOST ?= https://tickets.sagariousmedia.cloud
API_KEY  ?= $(shell grep ^SGE_API_KEY= .env | cut -d= -f2 2>/dev/null)

up:
	docker compose up -d --build

down:
	docker compose down

logs:
	docker logs -f ticket-service

health:
	@curl -sS -I $(API_HOST)/healthz | tr -d '\r'

mint:
	@test -n "$(API_KEY)" || (echo "API_KEY missing (set in .env)"; exit 1)
	@curl -sS -X POST $(API_HOST)/api/v1/mint \
	 -H "Content-Type: application/json" -H "X-API-Key: $(API_KEY)" \
	 -d '{"tid":1234,"eid":999,"ttl":86400}'

checkin TOKEN?=
checkin:
	@test -n "$(API_KEY)" -a -n "$(TOKEN)" || (echo "usage: make checkin TOKEN=<jwt>"; exit 1)
	@curl -sS -X POST $(API_HOST)/api/v1/checkin \
	 -H "Content-Type: application/json" -H "X-API-Key: $(API_KEY)" \
	 -d '{"token":"$(TOKEN)"}'

status TOKEN?=
status:
	@test -n "$(API_KEY)" -a -n "$(TOKEN)" || (echo "usage: make status TOKEN=<jwt>"; exit 1)
	@curl -sS -H "X-API-Key: $(API_KEY)" $(API_HOST)/api/v1/status/$(TOKEN)
