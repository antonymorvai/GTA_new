#!/usr/bin/env bash
# Spielt Seed-Daten (RBAC-Matrix, Basis-Items) in die Spiel-DB ein. Idempotent.
set -euo pipefail
cd "$(dirname "$0")/.."
[ -f .env ] && set -a && . ./.env && set +a

for file in database/seeds/*.sql; do
    echo "-> $(basename "$file")"
    docker compose exec -T mariadb sh -c \
        "mariadb -u root -p\"\$MARIADB_ROOT_PASSWORD\" \"\$MARIADB_DATABASE\"" < "$file"
done
echo "Seeds eingespielt."
