-- Log-Store (TimescaleDB): append-only Event-Sourcing der Spielwelt.
-- KEIN UPDATE/DELETE durch die Anwendung — wird per Rechteentzug erzwungen.
-- Retention/DSGVO: Policies unten, konfiguriert über Backend-Env.

CREATE EXTENSION IF NOT EXISTS timescaledb;

CREATE TABLE IF NOT EXISTS events (
    time             TIMESTAMPTZ      NOT NULL,
    event_id         UUID             NOT NULL,
    type             TEXT             NOT NULL,   -- 'money.transfer', 'item.move', ...
    category         TEXT             NOT NULL,   -- erster Namespace-Teil: 'money','item',...
    schema_version   SMALLINT         NOT NULL DEFAULT 1,
    server_id        TEXT             NOT NULL DEFAULT 'main',
    actor_account    BIGINT           NULL,
    actor_character  BIGINT           NULL,
    session_id       UUID             NULL,
    target_kind      TEXT             NULL,       -- 'character','item','vehicle','account',...
    target_id        TEXT             NULL,
    correlation_id   UUID             NULL,       -- verkettet zusammengehörige Events
    pos_x            REAL             NULL,
    pos_y            REAL             NULL,
    pos_z            REAL             NULL,
    instance         TEXT             NULL,       -- Routing-Bucket / Interior-Instanz
    payload          JSONB            NOT NULL DEFAULT '{}'::jsonb
);

SELECT create_hypertable('events', 'time', chunk_time_interval => INTERVAL '1 day', if_not_exists => TRUE);

CREATE INDEX IF NOT EXISTS idx_events_type          ON events (type, time DESC);
CREATE INDEX IF NOT EXISTS idx_events_actor_char    ON events (actor_character, time DESC) WHERE actor_character IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_events_actor_account ON events (actor_account, time DESC)   WHERE actor_account IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_events_target        ON events (target_kind, target_id, time DESC) WHERE target_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_events_correlation   ON events (correlation_id) WHERE correlation_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_events_payload       ON events USING GIN (payload jsonb_path_ops);

-- Positions-Sampling separat (hohes Volumen, eigene Retention/Kompression).
CREATE TABLE IF NOT EXISTS position_samples (
    time         TIMESTAMPTZ NOT NULL,
    character_id BIGINT      NOT NULL,
    session_id   UUID        NULL,
    x            REAL        NOT NULL,
    y            REAL        NOT NULL,
    z            REAL        NOT NULL,
    heading      REAL        NOT NULL DEFAULT 0,
    speed        REAL        NOT NULL DEFAULT 0
);

SELECT create_hypertable('position_samples', 'time', chunk_time_interval => INTERVAL '6 hours', if_not_exists => TRUE);
CREATE INDEX IF NOT EXISTS idx_pos_character ON position_samples (character_id, time DESC);

-- Kompression: alte Chunks komprimieren (Speicher ~10x kleiner)
ALTER TABLE events SET (timescaledb.compress, timescaledb.compress_segmentby = 'category');
SELECT add_compression_policy('events', INTERVAL '7 days', if_not_exists => TRUE);

ALTER TABLE position_samples SET (timescaledb.compress, timescaledb.compress_segmentby = 'character_id');
SELECT add_compression_policy('position_samples', INTERVAL '1 day', if_not_exists => TRUE);

-- Retention-Policies werden vom Backend beim Start gemäß
-- LOG_RETENTION_DAYS / POSITION_RETENTION_DAYS gesetzt (add_retention_policy).

-- Append-only erzwingen: App-Rolle darf nur INSERT/SELECT.
-- (Der Superuser bleibt für Migrations/DSGVO-Löschungen; jede solche Operation
--  ist organisatorisch zu protokollieren, siehe docs/operations.md)
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'hrp_writer') THEN
        CREATE ROLE hrp_writer NOLOGIN;
    END IF;
END $$;
GRANT INSERT, SELECT ON events, position_samples TO hrp_writer;
REVOKE UPDATE, DELETE ON events, position_samples FROM hrp_writer;
