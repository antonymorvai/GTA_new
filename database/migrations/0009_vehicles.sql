-- 0009: Fahrzeuge — Modelle (Händler), Spielerfahrzeuge, Schlüssel.
-- Verschleiß/TÜV/Versicherung erweitern dieses Schema in späteren Phasen;
-- Kraftstoff, Kilometerstand und Zustand sind ab jetzt persistenter Zustand.

CREATE TABLE vehicle_models (
    id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
    model       VARCHAR(64)  NOT NULL,      -- Spawn-Name, z. B. 'blista'
    label       VARCHAR(128) NOT NULL,
    category    VARCHAR(32)  NOT NULL,      -- 'compact','suv','truck',...
    base_price  BIGINT       NOT NULL,      -- Cent
    fuel_type   ENUM('petrol','diesel','electric') NOT NULL DEFAULT 'petrol',
    tank_liters DECIMAL(5,1) NOT NULL DEFAULT 55.0,
    consumption_per_100km DECIMAL(4,1) NOT NULL DEFAULT 8.0,
    dealer_stock INT         NOT NULL DEFAULT 5,   -- Import-Wartelisten folgen später
    PRIMARY KEY (id),
    UNIQUE KEY uq_vehmodel (model)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE vehicles (
    id            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    plate         CHAR(8)         NOT NULL,
    model_id      INT UNSIGNED    NOT NULL,
    owner_id      BIGINT UNSIGNED NOT NULL,    -- character_id
    fuel_liters   DECIMAL(5,1)    NOT NULL DEFAULT 50.0,
    mileage_km    DECIMAL(10,1)   NOT NULL DEFAULT 0,
    engine_health DECIMAL(5,1)    NOT NULL DEFAULT 1000.0,
    body_health   DECIMAL(5,1)    NOT NULL DEFAULT 1000.0,
    stored        TINYINT(1)      NOT NULL DEFAULT 1,   -- 1 = in Garage
    garage        VARCHAR(48)     NOT NULL DEFAULT 'legion',
    position      JSON            NULL,                 -- letzte Position wenn draußen
    created_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    deleted_at    DATETIME(3)     NULL,                 -- Soft-Delete (Totalschaden/Verkauf)
    PRIMARY KEY (id),
    UNIQUE KEY uq_vehicles_plate (plate),
    KEY idx_vehicles_owner (owner_id),
    CONSTRAINT fk_vehicles_model FOREIGN KEY (model_id) REFERENCES vehicle_models (id),
    CONSTRAINT fk_vehicles_owner FOREIGN KEY (owner_id) REFERENCES characters (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Schlüssel: Besitzer implizit; zusätzliche Schlüssel explizit (Übergaben geloggt).
CREATE TABLE vehicle_keys (
    vehicle_id   BIGINT UNSIGNED NOT NULL,
    character_id BIGINT UNSIGNED NOT NULL,
    granted_by   BIGINT UNSIGNED NULL,
    granted_at   DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (vehicle_id, character_id),
    CONSTRAINT fk_vkeys_vehicle FOREIGN KEY (vehicle_id) REFERENCES vehicles (id),
    CONSTRAINT fk_vkeys_character FOREIGN KEY (character_id) REFERENCES characters (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
