-- 0022: Staatskasse — schließt den Wirtschaftskreislauf.
-- Einnahmen: Bußgelder, Fahrzeug-/Immobilienkäufe (Staatsverkäufe), Steuern.
-- Ausgaben: Löhne staatlicher Jobs. Leere Kasse = keine Löhne (dynamische
-- Kopplung, Kernprinzip B). Jede Bewegung -> state.treasury-Event.

CREATE TABLE state_treasury (
    id         TINYINT UNSIGNED NOT NULL,     -- genau eine Zeile (id = 1)
    balance    BIGINT NOT NULL DEFAULT 0,     -- Cent
    updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    CONSTRAINT chk_treasury_nonneg CHECK (balance >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Startkapital: 5.000.000 $ (Launch-Konfiguration; danach lebt die Kasse
-- ausschließlich von Einnahmen)
INSERT INTO state_treasury (id, balance) VALUES (1, 500000000)
ON DUPLICATE KEY UPDATE id = id;
