#!/usr/bin/env bash
set -euo pipefail
VOL="event-stack_sge-data"
MP=$(docker volume inspect "$VOL" --format '{{ .Mountpoint }}')
SRC="$MP/sge.db"
DST_DIR="/var/backups/sge"
TS=$(date +%F-%H%M)

mkdir -p "$DST_DIR"
sqlite3 "$SRC" "PRAGMA wal_checkpoint; VACUUM;"
cp -a "$SRC" "$DST_DIR/sge-$TS.db"
gzip -f "$DST_DIR/sge-$TS.db"
echo "[ok] wrote $DST_DIR/sge-$TS.db.gz"
ls -lh "$DST_DIR" | tail -n 5
