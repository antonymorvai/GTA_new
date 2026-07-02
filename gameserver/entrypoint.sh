#!/bin/sh
set -eu

# server.cfg mit Umgebungswerten befüllen (Secrets bleiben außerhalb des Repos)
envsubst '${FIVEM_SERVER_NAME} ${FIVEM_MAX_CLIENTS} ${FIVEM_LICENSE_KEY} ${FIVEM_GAME_BUILD} ${MARIADB_USER} ${MARIADB_PASSWORD} ${MARIADB_DATABASE} ${INGEST_TOKEN}' \
    < /opt/cfx/server.cfg > /opt/cfx/server.generated.cfg

cd /opt/cfx
exec ./run.sh +exec server.generated.cfg
