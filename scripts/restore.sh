#!/usr/bin/env bash
# Restore der Spiel-DB aus Voll-Backup + optional Point-in-Time via Binlogs.
#
# Nutzung:
#   ./scripts/restore.sh backups/game/full_2026-07-02.sql.gz
#   ./scripts/restore.sh backups/game/full_2026-07-02.sql.gz "2026-07-02 14:30:00"
#
# Log-Store-Restore:
#   gunzip -c backups/logstore/full_<datum>.dump.gz | \
#     docker compose exec -T logstore pg_restore -U $LOGSTORE_USER -d $LOGSTORE_DB --clean
set -euo pipefail
cd "$(dirname "$0")/.."
[ -f .env ] && set -a && . ./.env && set +a

BACKUP_FILE="${1:?Nutzung: restore.sh <voll-backup.sql.gz> [\"YYYY-MM-DD HH:MM:SS\"]}"
STOP_TIME="${2:-}"

echo "!!! ACHTUNG: Überschreibt die Datenbank '$MARIADB_DATABASE'. Abbruch mit Ctrl+C (5 s) ..."
sleep 5

echo "== Voll-Backup einspielen: $BACKUP_FILE =="
gunzip -c "$BACKUP_FILE" | docker compose exec -T mariadb sh -c \
    "mariadb -u root -p\"\$MARIADB_ROOT_PASSWORD\" \"\$MARIADB_DATABASE\""

if [ -n "$STOP_TIME" ]; then
    echo "== Point-in-Time-Recovery bis: $STOP_TIME =="
    # Binlog-Dateien seit dem Voll-Backup nacheinander anwenden
    docker compose exec -T mariadb sh -c "
        for bl in /var/lib/mysql/mysql-bin.[0-9]*; do
            mariadb-binlog --stop-datetime='$STOP_TIME' \"\$bl\"
        done | mariadb -u root -p\"\$MARIADB_ROOT_PASSWORD\" \"\$MARIADB_DATABASE\"
    "
fi

echo "Restore abgeschlossen. Migrations-Stand prüfen: ./scripts/migrate.sh game"
