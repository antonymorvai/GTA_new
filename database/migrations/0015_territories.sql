-- 0015: Gangs & Territorien — Einfluss als kontinuierlicher Wert (kein
-- Capture-Timer). Aktivitäten (Deals, Präsenz) erhöhen Einfluss, Verfall
-- ohne Pflege; Auswirkungen z. B. auf Drogenpreise im Gebiet.

CREATE TABLE gangs (
    id         INT UNSIGNED NOT NULL AUTO_INCREMENT,
    name       VARCHAR(48)  NOT NULL,
    label      VARCHAR(128) NOT NULL,
    created_at DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    UNIQUE KEY uq_gangs_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE gang_members (
    character_id BIGINT UNSIGNED NOT NULL,
    gang_id      INT UNSIGNED    NOT NULL,
    rank         TINYINT UNSIGNED NOT NULL DEFAULT 0,
    joined_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (character_id),
    KEY idx_gangmembers_gang (gang_id),
    CONSTRAINT fk_gangmembers_character FOREIGN KEY (character_id) REFERENCES characters (id),
    CONSTRAINT fk_gangmembers_gang FOREIGN KEY (gang_id) REFERENCES gangs (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE territories (
    id       INT UNSIGNED NOT NULL AUTO_INCREMENT,
    name     VARCHAR(48)  NOT NULL,
    label    VARCHAR(128) NOT NULL,
    center_x FLOAT        NOT NULL,
    center_y FLOAT        NOT NULL,
    radius   FLOAT        NOT NULL DEFAULT 250.0,
    PRIMARY KEY (id),
    UNIQUE KEY uq_territories_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE territory_influence (
    territory_id INT UNSIGNED NOT NULL,
    gang_id      INT UNSIGNED NOT NULL,
    influence    DECIMAL(6,2) NOT NULL DEFAULT 0,   -- 0..100
    updated_at   DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    PRIMARY KEY (territory_id, gang_id),
    CONSTRAINT fk_ti_territory FOREIGN KEY (territory_id) REFERENCES territories (id),
    CONSTRAINT fk_ti_gang FOREIGN KEY (gang_id) REFERENCES gangs (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
