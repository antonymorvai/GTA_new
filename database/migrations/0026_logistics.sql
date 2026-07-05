-- 0026: Lieferketten — Tankstellen haben ECHTE Kraftstoff-Bestände.
-- Tanken zieht vom Stationsbestand ab; leere Station = niemand kann tanken,
-- bis ein Trucker liefert (dynamische Firmen-Aufträge aus echtem Bedarf).

CREATE TABLE fuel_stations (
    id             INT UNSIGNED NOT NULL AUTO_INCREMENT,
    label          VARCHAR(128) NOT NULL,
    pos_x          FLOAT        NOT NULL,
    pos_y          FLOAT        NOT NULL,
    pos_z          FLOAT        NOT NULL,
    capacity_l     INT UNSIGNED NOT NULL DEFAULT 8000,
    stock_l        INT UNSIGNED NOT NULL DEFAULT 5000,
    PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO fuel_stations (label, pos_x, pos_y, pos_z, capacity_l, stock_l) VALUES
    ('Xero Route 68 Ost',        49.4, 2778.8, 58.0, 8000, 5000),
    ('Xero Harmony',             263.9, 2606.5, 44.9, 8000, 5000),
    ('LTD Grove Street',         -70.2, -1761.8, 29.5, 10000, 6000),
    ('RON Strawberry',           265.6, -1261.3, 29.3, 10000, 6000),
    ('Xero La Puerta',           -524.0, -1211.1, 18.2, 10000, 6000),
    ('RON Senora Freeway',       1208.9, 2660.2, 37.9, 8000, 5000)
ON DUPLICATE KEY UPDATE label = VALUES(label);
