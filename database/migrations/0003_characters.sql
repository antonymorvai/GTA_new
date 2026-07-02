-- 0003: Charaktere (Multi-Char, 3 Slots), Vitalwerte, Skills, Geldbestand.
-- Geld-SALDEN leben hier (aktueller Zustand); der vollständige Geld-FLUSS
-- lebt ausschließlich im Log-Store (money.* Events). Kein Saldo darf sich
-- ohne korrespondierendes Event ändern (DoD-Regel 2).

CREATE TABLE characters (
    id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    account_id     BIGINT UNSIGNED NOT NULL,
    -- 1..3; wird bei Soft-Delete auf NULL gesetzt und gibt den Slot frei
    slot           TINYINT UNSIGNED NULL,
    first_name     VARCHAR(32)  NOT NULL,
    last_name      VARCHAR(32)  NOT NULL,
    date_of_birth  DATE         NOT NULL,
    gender         ENUM('m','f','d') NOT NULL,
    backstory      TEXT         NOT NULL,              -- Pflicht-Lebenslauf
    appearance     JSON         NOT NULL,              -- Freemode-Parameter
    position       JSON         NULL,                  -- letzte Position {x,y,z,h}
    state          ENUM('alive','unconscious','dead','ck') NOT NULL DEFAULT 'alive',
    health         SMALLINT UNSIGNED NOT NULL DEFAULT 200,
    armor          SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    played_minutes INT UNSIGNED NOT NULL DEFAULT 0,
    created_at     DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    updated_at     DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    deleted_at     DATETIME(3)  NULL,                  -- Soft-Delete (Nachvollziehbarkeit!)
    PRIMARY KEY (id),
    KEY idx_characters_account (account_id),
    KEY idx_characters_name (last_name, first_name),
    CONSTRAINT fk_characters_account FOREIGN KEY (account_id) REFERENCES accounts (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Slot-Eindeutigkeit: NULL-Werte kollidieren im Unique-Index nicht, daher
-- belegt nur ein aktiver (nicht gelöschter) Charakter je Slot den Index.
ALTER TABLE characters ADD UNIQUE KEY uq_characters_slot (account_id, slot);

CREATE TABLE character_vitals (
    character_id BIGINT UNSIGNED NOT NULL,
    hunger       TINYINT UNSIGNED NOT NULL DEFAULT 100,   -- 0..100
    thirst       TINYINT UNSIGNED NOT NULL DEFAULT 100,
    stress       TINYINT UNSIGNED NOT NULL DEFAULT 0,
    fatigue      TINYINT UNSIGNED NOT NULL DEFAULT 0,
    hygiene      TINYINT UNSIGNED NOT NULL DEFAULT 100,
    temperature  DECIMAL(4,1)     NOT NULL DEFAULT 36.6,
    alcohol      DECIMAL(4,2)     NOT NULL DEFAULT 0,     -- Promille
    updated_at   DATETIME(3)      NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    PRIMARY KEY (character_id),
    CONSTRAINT fk_vitals_character FOREIGN KEY (character_id) REFERENCES characters (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE character_skills (
    character_id BIGINT UNSIGNED NOT NULL,
    skill        VARCHAR(32)     NOT NULL,   -- 'driving','shooting','fishing',...
    xp           INT UNSIGNED    NOT NULL DEFAULT 0,
    last_used_at DATETIME(3)     NULL,       -- Basis für Skill-Decay
    PRIMARY KEY (character_id, skill),
    CONSTRAINT fk_skills_character FOREIGN KEY (character_id) REFERENCES characters (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE character_money (
    character_id BIGINT UNSIGNED NOT NULL,
    cash         BIGINT NOT NULL DEFAULT 0,   -- Cent-genau (Integer, kein FLOAT!)
    bank         BIGINT NOT NULL DEFAULT 0,
    updated_at   DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    PRIMARY KEY (character_id),
    CONSTRAINT fk_money_character FOREIGN KEY (character_id) REFERENCES characters (id),
    CONSTRAINT chk_cash_nonneg CHECK (cash >= 0),
    CONSTRAINT chk_bank_range  CHECK (bank >= -1000000000)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
