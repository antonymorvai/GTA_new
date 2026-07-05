#!/bin/bash
# Tägliches Voll-Backup: Spiel-DB (mariadb-dump) + Log-Store (pg_dump).
# --flush-logs startet ein neues Binlog -> sauberer Startpunkt für Inkremente.
set -eu

STAMP="$(date +%F_%H%M)"
KEEP_DAYS=14

echo "[$(date -Is)] Voll-Backup startet"

mariadb-dump \
    -h "$MARIADB_HOST" -u root -p"$MARIADB_ROOT_PASSWORD" \
    --single-transaction --flush-logs --master-data=2 --routines --triggers \
    "$MARIADB_DATABASE" | gzip > "/backups/game/full_${STAMP}.sql.gz"

pg_dump \
    -h "$LOGSTORE_HOST" -U "$LOGSTORE_USER" -d "$LOGSTORE_DB" \
    -Fc | gzip > "/backups/logstore/full_${STAMP}.dump.gz"

find /backups/game /backups/logstore -name 'full_*' -mtime +$KEEP_DAYS -delete

echo "[$(date -Is)] Voll-Backup fertig: full_${STAMP}"
