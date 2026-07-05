-- Anomalie-Prüf-Queue: operative Tabelle (Status-Updates erlaubt — der
-- unveränderliche Nachweis ist das anomaly.detected-Event in events).

CREATE TABLE IF NOT EXISTS anomalies (
    id           BIGSERIAL PRIMARY KEY,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    rule         TEXT        NOT NULL,          -- 'money_created_24h', ...
    subject_kind TEXT        NOT NULL,          -- 'character' | 'account'
    subject_id   TEXT        NOT NULL,
    detail       JSONB       NOT NULL DEFAULT '{}'::jsonb,
    status       TEXT        NOT NULL DEFAULT 'open',   -- open|assigned|resolved|dismissed
    assigned_to  BIGINT      NULL,              -- account_id des Teammitglieds
    resolution   TEXT        NULL
);

CREATE INDEX IF NOT EXISTS idx_anomalies_status ON anomalies (status, created_at DESC);

GRANT SELECT, INSERT, UPDATE ON anomalies TO hrp_writer;
GRANT USAGE ON SEQUENCE anomalies_id_seq TO hrp_writer;
