#!/bin/bash
# Richtet Cron-Jobs gemäß Env ein: täglich voll, stündlich inkrementell (Binlog-Flush).
set -eu

mkdir -p /backups/game /backups/logstore

echo "${BACKUP_FULL_CRON:-0 4 * * *} /usr/local/bin/backup-full.sh >> /backups/backup.log 2>&1" > /etc/crontabs/root
echo "${BACKUP_INCR_CRON:-0 * * * *} /usr/local/bin/backup-incr.sh >> /backups/backup.log 2>&1" >> /etc/crontabs/root

echo "[backup] Cron eingerichtet: voll='${BACKUP_FULL_CRON:-0 4 * * *}', inkrementell='${BACKUP_INCR_CRON:-0 * * * *}'"
exec crond -f -l 2
