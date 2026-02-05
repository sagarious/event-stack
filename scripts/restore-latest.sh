#!/usr/bin/env bash
set -euo pipefail
LATEST=$(ls -1t /var/backups/sge/sge-*.db.gz | head -1)
[ -n "$LATEST" ] || { echo "no backups found"; exit 1; }
VOL="event-stack_sge-data"
MP=$(docker volume inspect "$VOL" --format '{{ .Mountpoint }}')
gzip -cd "$LATEST" > "$MP/sge.db"
echo "[ok] restored $LATEST -> $MP/sge.db"
