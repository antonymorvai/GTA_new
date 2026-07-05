-- 0017: Immobilien — Kauf, Schlüssel, dynamische Preise (Nachfrage pro Region;
-- Kriminalitäts-Score aus echten Log-Daten fließt in Phase 5 über das Backend ein).

CREATE TABLE properties (
    id            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    label         VARCHAR(128) NOT NULL,
    prop_type     ENUM('apartment','house','warehouse','business') NOT NULL,
    region        VARCHAR(32)  NOT NULL,
    entrance_x    FLOAT        NOT NULL,
    entrance_y    FLOAT        NOT NULL,
    entrance_z    FLOAT        NOT NULL,
    base_price    BIGINT       NOT NULL,          -- Cent
    current_price BIGINT       NOT NULL,
    owner_id      BIGINT UNSIGNED NULL,           -- character_id, NULL = Staat/frei
    purchased_at  DATETIME(3)  NULL,
    created_at    DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    KEY idx_properties_owner (owner_id),
    KEY idx_properties_region (region),
    CONSTRAINT fk_properties_owner FOREIGN KEY (owner_id) REFERENCES characters (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE property_keys (
    property_id  BIGINT UNSIGNED NOT NULL,
    character_id BIGINT UNSIGNED NOT NULL,
    granted_by   BIGINT UNSIGNED NULL,
    granted_at   DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (property_id, character_id),
    CONSTRAINT fk_pkeys_property FOREIGN KEY (property_id) REFERENCES properties (id),
    CONSTRAINT fk_pkeys_character FOREIGN KEY (character_id) REFERENCES characters (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
