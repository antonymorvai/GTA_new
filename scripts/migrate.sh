#!/usr/bin/env bash
# Wendet ausstehende Migrations auf Spiel-DB (MariaDB) und Log-Store (TimescaleDB) an.
# Nutzung:  ./scripts/migrate.sh            (beide)
#           ./scripts/migrate.sh game       (nur MariaDB)
#           ./scripts/migrate.sh logstore   (nur TimescaleDB)
set -euo pipefail
cd "$(dirname "$0")/.."
[ -f .env ] && set -a && . ./.env && set +a

TARGET="${1:-all}"

migrate_game() {
    echo "== MariaDB-Migrations =="
    docker compose exec -T mariadb sh -c \
        "mariadb -u root -p\"\$MARIADB_ROOT_PASSWORD\" \"\$MARIADB_DATABASE\" -e \
        'CREATE TABLE IF NOT EXISTS schema_migrations (version VARCHAR(64) PRIMARY KEY, applied_at DATETIME(3) DEFAULT CURRENT_TIMESTAMP(3))'"
    for file in database/migrations/*.sql; do
        version="$(basename "$file" .sql)"
        applied=$(docker compose exec -T mariadb sh -c \
            "mariadb -u root -p\"\$MARIADB_ROOT_PASSWORD\" \"\$MARIADB_DATABASE\" -N -e \
            \"SELECT COUNT(*) FROM schema_migrations WHERE version='$version'\"")
        if [ "$(echo "$applied" | tr -d '[:space:]')" = "0" ]; then
            echo "-> $version"
            docker compose exec -T mariadb sh -c \
                "mariadb -u root -p\"\$MARIADB_ROOT_PASSWORD\" \"\$MARIADB_DATABASE\"" < "$file"
            docker compose exec -T mariadb sh -c \
                "mariadb -u root -p\"\$MARIADB_ROOT_PASSWORD\" \"\$MARIADB_DATABASE\" -e \
                \"INSERT INTO schema_migrations (version) VALUES ('$version')\""
        else
            echo "   $version (bereits angewendet)"
        fi
    done
}

migrate_logstore() {
    echo "== TimescaleDB-Migrations =="
    docker compose exec -T logstore psql -U "$LOGSTORE_USER" -d "$LOGSTORE_DB" -c \
        'CREATE TABLE IF NOT EXISTS schema_migrations (version TEXT PRIMARY KEY, applied_at TIMESTAMPTZ DEFAULT now())'
    for file in database/logstore/*.sql; do
        version="$(basename "$file" .sql)"
        applied=$(docker compose exec -T logstore psql -U "$LOGSTORE_USER" -d "$LOGSTORE_DB" -tA -c \
            "SELECT COUNT(*) FROM schema_migrations WHERE version='$version'")
        if [ "$applied" = "0" ]; then
            echo "-> $version"
            docker compose exec -T logstore psql -U "$LOGSTORE_USER" -d "$LOGSTORE_DB" -v ON_ERROR_STOP=1 < "$file"
            docker compose exec -T logstore psql -U "$LOGSTORE_USER" -d "$LOGSTORE_DB" -c \
                "INSERT INTO schema_migrations (version) VALUES ('$version')"
        else
            echo "   $version (bereits angewendet)"
        fi
    done
}

case "$TARGET" in
    game)     migrate_game ;;
    logstore) migrate_logstore ;;
    all)      migrate_game; migrate_logstore ;;
    *)        echo "Unbekanntes Ziel: $TARGET (game|logstore|all)"; exit 1 ;;
esac
echo "Fertig."
