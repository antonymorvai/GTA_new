-- 0013: Justiz — versioniertes Gesetzbuch, Bußgelder, Haftstrafen.
-- Gesetze sind DATEN: Regierung/Justiz ändert sie in-RP (law.change-Events,
-- Historie append-only); Bußgeld-Engine und MDT lesen immer den aktiven Stand.

CREATE TABLE laws (
    id           INT UNSIGNED NOT NULL AUTO_INCREMENT,
    code         VARCHAR(32)  NOT NULL,          -- z. B. 'StVO-1' oder 'StGB-242'
    title        VARCHAR(200) NOT NULL,
    description  TEXT         NOT NULL,
    fine         BIGINT       NOT NULL DEFAULT 0,     -- Cent
    jail_minutes INT UNSIGNED NOT NULL DEFAULT 0,
    version      INT UNSIGNED NOT NULL DEFAULT 1,
    active       TINYINT(1)   NOT NULL DEFAULT 1,
    updated_at   DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    UNIQUE KEY uq_laws_code (code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE law_history (
    id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    law_code     VARCHAR(32)  NOT NULL,
    version      INT UNSIGNED NOT NULL,
    snapshot     JSON         NOT NULL,          -- kompletter Stand nach der Änderung
    changed_by   BIGINT UNSIGNED NULL,           -- character_id (Richter/Regierung)
    changed_at   DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    KEY idx_lawhist_code (law_code, version)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE fines (
    id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    character_id BIGINT UNSIGNED NOT NULL,
    law_code     VARCHAR(32)     NOT NULL,
    amount       BIGINT          NOT NULL,        -- Cent, Stand bei Ausstellung
    issued_by    BIGINT UNSIGNED NOT NULL,        -- character_id (Officer)
    note         VARCHAR(300)    NOT NULL DEFAULT '',
    status       ENUM('open','paid','cancelled') NOT NULL DEFAULT 'open',
    created_at   DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    paid_at      DATETIME(3)     NULL,
    PRIMARY KEY (id),
    KEY idx_fines_char (character_id, status),
    CONSTRAINT fk_fines_character FOREIGN KEY (character_id) REFERENCES characters (id),
    CONSTRAINT fk_fines_officer FOREIGN KEY (issued_by) REFERENCES characters (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE jail_sentences (
    id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    character_id BIGINT UNSIGNED NOT NULL,
    minutes      INT UNSIGNED    NOT NULL,
    reason       VARCHAR(500)    NOT NULL,
    issued_by    BIGINT UNSIGNED NOT NULL,        -- character_id (Richter/Officer)
    started_at   DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    ends_at      DATETIME(3)     NOT NULL,
    released_at  DATETIME(3)     NULL,            -- vorzeitig/regulär entlassen
    released_by  BIGINT UNSIGNED NULL,
    PRIMARY KEY (id),
    KEY idx_jail_char (character_id, released_at),
    KEY idx_jail_active (released_at, ends_at),
    CONSTRAINT fk_jail_character FOREIGN KEY (character_id) REFERENCES characters (id),
    CONSTRAINT fk_jail_issuer FOREIGN KEY (issued_by) REFERENCES characters (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
