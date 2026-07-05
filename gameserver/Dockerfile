# FiveM-Gameserver: lädt beim Build das aktuelle Linux-Artefakt und oxmysql.
# Pinne FIVEM_ARTIFACT für reproduzierbare Builds (siehe
# https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/).

FROM debian:bookworm-slim

ARG FIVEM_ARTIFACT_URL=https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/latest/fx.tar.xz
ARG OXMYSQL_URL=https://github.com/CommunityOx/oxmysql/releases/latest/download/oxmysql.zip

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl xz-utils unzip gettext-base \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/cfx

RUN curl -fsSL "$FIVEM_ARTIFACT_URL" -o fx.tar.xz \
    && tar -xf fx.tar.xz \
    && rm fx.tar.xz

# oxmysql als eigene Ressource neben den [hrp]-Ressourcen
RUN mkdir -p /opt/cfx/resources \
    && curl -fsSL "$OXMYSQL_URL" -o /tmp/oxmysql.zip \
    && unzip -q /tmp/oxmysql.zip -d /opt/cfx/resources/ \
    && rm /tmp/oxmysql.zip

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 30120/tcp 30120/udp 40120/tcp

ENTRYPOINT ["/entrypoint.sh"]
