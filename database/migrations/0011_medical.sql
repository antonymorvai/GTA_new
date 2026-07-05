-- 0011: Verletzungssystem & Krankenakten.
-- Verletzungen sind Zustand pro Trefferzone (Behandlung setzt treated_at);
-- der vollständige Kampf-Hergang lebt als combat.*-Events im Log-Store.

CREATE TABLE character_injuries (
    id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    character_id BIGINT UNSIGNED NOT NULL,
    zone         ENUM('head','torso','left_arm','right_arm','left_leg','right_leg') NOT NULL,
    kind         ENUM('bullet','stab','blunt','burn','fracture') NOT NULL,
    severity     TINYINT UNSIGNED NOT NULL DEFAULT 1,   -- 1 leicht, 2 mittel, 3 schwer
    bleeding     TINYINT(1)      NOT NULL DEFAULT 0,
    created_at   DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    treated_at   DATETIME(3)     NULL,
    treated_by   BIGINT UNSIGNED NULL,                  -- character_id des Medics
    PRIMARY KEY (id),
    KEY idx_injuries_char (character_id, treated_at),
    CONSTRAINT fk_injuries_character FOREIGN KEY (character_id) REFERENCES characters (id),
    CONSTRAINT fk_injuries_medic FOREIGN KEY (treated_by) REFERENCES characters (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE medical_records (
    id                  BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    character_id        BIGINT UNSIGNED NOT NULL,      -- Patient
    author_character_id BIGINT UNSIGNED NOT NULL,      -- behandelnder Medic
    entry               TEXT            NOT NULL,
    created_at          DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    KEY idx_medrecords_char (character_id, created_at),
    CONSTRAINT fk_medrecords_patient FOREIGN KEY (character_id) REFERENCES characters (id),
    CONSTRAINT fk_medrecords_author FOREIGN KEY (author_character_id) REFERENCES characters (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
