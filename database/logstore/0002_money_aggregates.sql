-- Continuous Aggregates für das Geldmengen-Dashboard (ACP, Phase 5):
-- tagesgenaue Quelle-Senke-Bilanz pro Event-Typ und Grund-Code, live
-- materialisiert aus dem append-only Event-Strom.

CREATE MATERIALIZED VIEW IF NOT EXISTS money_flow_daily
WITH (timescaledb.continuous) AS
SELECT
    time_bucket('1 day', time)            AS day,
    type,                                  -- money.create / money.destroy / money.transfer / money.adjust
    payload->>'reason'                     AS reason,
    count(*)                               AS events,
    sum((payload->>'amount')::bigint)      AS total_amount
FROM events
WHERE category = 'money'
GROUP BY 1, 2, 3
WITH NO DATA;

SELECT add_continuous_aggregate_policy('money_flow_daily',
    start_offset      => INTERVAL '3 days',
    end_offset        => INTERVAL '1 hour',
    schedule_interval => INTERVAL '1 hour',
    if_not_exists     => TRUE);

-- Geldmenge M0/M1-Analogie: Summe create - destroy kumulativ = im Umlauf
-- befindliches Geld. Abfrage-Beispiel (ACP):
--   SELECT day,
--          sum(CASE WHEN type='money.create'  THEN total_amount ELSE 0 END) AS created,
--          sum(CASE WHEN type='money.destroy' THEN total_amount ELSE 0 END) AS destroyed
--   FROM money_flow_daily GROUP BY day ORDER BY day;

GRANT SELECT ON money_flow_daily TO hrp_writer;
