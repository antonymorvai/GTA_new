# Installations-Guide (von Null bis Live)

## Voraussetzungen
- Linux-Server (Docker + Docker Compose v2), 4+ Kerne, 16 GB RAM, SSD
- Domain mit A-Record auf den Server (für HTTPS via Let's Encrypt)
- FiveM-Lizenzschlüssel (https://portal.cfx.re)
- Offene Ports: 80/443 (Web), 30120 TCP+UDP (Spiel); 40120 (txAdmin) nur per Firewall/VPN

## 1. Repository & Konfiguration

```bash
git clone <repo-url> hardcorerp && cd hardcorerp
cp .env.example .env
# .env bearbeiten: ALLE change-me-Werte durch starke Secrets ersetzen,
# DOMAIN und FIVEM_LICENSE_KEY setzen.
```

Secrets erzeugen z. B. mit `openssl rand -hex 32`.

## 2. Infrastruktur starten

```bash
docker compose up -d mariadb logstore redis
docker compose ps          # warten bis alle "healthy"
```

## 3. Datenbanken migrieren & seeden

```bash
./scripts/migrate.sh       # Spiel-DB + Log-Store
./scripts/seed.sh          # RBAC-Rollen, Basis-Items
```

## 4. Backend & Proxy

```bash
docker compose up -d backend proxy backup
curl -s https://<DOMAIN>/healthz    # -> {"status":"ok",...}
```

## 5. Gameserver

```bash
docker compose --profile game up -d fivem
docker compose logs -f fivem        # Start beobachten
```

Der erste Start lädt txAdmin; alternativ startet `entrypoint.sh` direkt mit
`server.generated.cfg`. Die [hrp]-Ressourcen und oxmysql werden automatisch geladen.

## 6. Erster Admin

1. Einmal mit dem Spiel verbinden — dabei wird dein Account angelegt.
   (Für den allerersten Join `hrp_whitelist_enforce 0` in `gameserver/server.cfg`
   setzen oder den Account direkt in der DB freischalten:)
   ```sql
   UPDATE accounts SET whitelist_status='approved' WHERE id=1;
   ```
2. Account-ID ermitteln: `SELECT id, username FROM accounts;`
3. In der Server-Konsole (txAdmin → Console):
   ```
   hrp_grantrole 1 admin
   ```

## 7. Funktionsprüfung Log-Pipeline

```bash
# Events fließen?
docker compose exec redis redis-cli -a $REDIS_PASSWORD XLEN hrp:events
docker compose exec logstore psql -U hrp_logs -d hrp_logs \
  -c "SELECT type, count(*) FROM events GROUP BY type ORDER BY 2 DESC LIMIT 10;"
```

Nach dem ersten Join müssen mindestens `session.connect`, `character.create`
(nach Erstellung) und `position.batch`-Entrollungen sichtbar sein.

## 8. Backups prüfen

```bash
docker compose exec backup /usr/local/bin/backup-full.sh   # manueller Testlauf
ls -lh backups/game backups/logstore
```

Restore-Probe (regelmäßig durchführen!): siehe `scripts/restore.sh` und
`docs/operations.md`.

## Entwicklung ohne Docker (Backend)

```bash
cd backend && npm install
npm test          # Unit-Tests (Envelope-Validierung, Log-Vollständigkeit)
npm run start:dev # benötigt lokale REDIS_URL/LOGSTORE_URL
```
