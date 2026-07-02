#!/bin/bash
# Stündliches inkrementelles Backup: rotiert das Binlog und sichert alle
# abgeschlossenen Binlog-Dateien. Restore = Voll-Backup + Binlogs bis Zeitpunkt X
# (siehe scripts/restore.sh).
set -eu

STAMP="$(date +%F_%H%M)"
DEST="/backups/game/binlog_${STAMP}"
KEEP_DAYS=7

# Neues Binlog beginnen, damit das aktuelle abgeschlossen ist
mariadb -h "$MARIADB_HOST" -u root -p"$MARIADB_ROOT_PASSWORD" -e "FLUSH BINARY LOGS"

# Abgeschlossene Binlogs auflisten und per mariadb-binlog remote sichern
mkdir -p "$DEST"
LOGS=$(mariadb -h "$MARIADB_HOST" -u root -p"$MARIADB_ROOT_PASSWORD" -N -e "SHOW BINARY LOGS" | awk '{print $1}' | head -n -1)
for log in $LOGS; do
    if [ ! -f "/backups/game/binlogs_seen/$log" ]; then
        mariadb-binlog --read-from-remote-server \
            -h "$MARIADB_HOST" -u root -p"$MARIADB_ROOT_PASSWORD" \
            --raw --result-file="$DEST/" "$log"
        mkdir -p /backups/game/binlogs_seen
        touch "/backups/game/binlogs_seen/$log"
    fi
done

# Leere Verzeichnisse (nichts Neues) wieder entfernen
rmdir "$DEST" 2>/dev/null || true

find /backups/game -maxdepth 1 -name 'binlog_*' -mtime +$KEEP_DAYS -exec rm -rf {} +

echo "[$(date -Is)] Inkrementelles Backup fertig"
