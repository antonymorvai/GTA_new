-- 0028: KFZ-Versicherung + Totalschaden.
-- Zerstörte Fahrzeuge sind TOTALSCHADEN (kein Auto-Heal, kein Ausparken).
-- Vollkasko stellt gegen Selbstbeteiligung wieder her, Teilkasko zahlt aus
-- (Fahrzeug bleibt Schrott), Haftpflicht deckt nur Dritte (RP-Grundlage).

CREATE TABLE vehicle_insurance (
    vehicle_id  BIGINT UNSIGNED NOT NULL,
    tier        ENUM('liability','partial','full') NOT NULL,
    premium     BIGINT          NOT NULL,          -- Cent pro Zahlperiode
    next_due_at DATETIME(3)     NOT NULL,
    active      TINYINT(1)      NOT NULL DEFAULT 1,
    created_at  DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (vehicle_id),
    CONSTRAINT fk_insurance_vehicle FOREIGN KEY (vehicle_id) REFERENCES vehicles (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

ALTER TABLE vehicles
    ADD COLUMN status ENUM('ok','totaled') NOT NULL DEFAULT 'ok' AFTER stored;
