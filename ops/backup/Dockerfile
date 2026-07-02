FROM alpine:3.20

RUN apk add --no-cache mariadb-client postgresql16-client gzip bash tzdata

COPY backup-full.sh /usr/local/bin/backup-full.sh
COPY backup-incr.sh /usr/local/bin/backup-incr.sh
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /usr/local/bin/backup-*.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
