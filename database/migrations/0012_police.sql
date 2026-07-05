-- 0012: Polizei — Strafregister, Fahndungen, Beweismittel (Chain of Custody).
-- Die Beweismittelkette ist der In-RP-Spiegel des Item-Trace: Items liegen als
-- Instanzen im Container 'evidence' (item_locations), jede Übergabe erzeugt
-- zusätzlich einen evidence_log-Eintrag + evidence.custody-Event.

CREATE TABLE criminal_records (
    id                   BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    character_id         BIGINT UNSIGNED NOT NULL,      -- Beschuldigter
    law_code             VARCHAR(32)     NOT NULL,      -- Referenz ins Gesetzbuch
    officer_character_id BIGINT UNSIGNED NOT NULL,
    case_number          VARCHAR(24)     NULL,
    note                 VARCHAR(500)    NOT NULL DEFAULT '',
    created_at           DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    KEY idx_crimrec_char (character_id, created_at),
    CONSTRAINT fk_crimrec_character FOREIGN KEY (character_id) REFERENCES characters (id),
    CONSTRAINT fk_crimrec_officer FOREIGN KEY (officer_character_id) REFERENCES characters (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE warrants (
    id                  BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    character_id        BIGINT UNSIGNED NOT NULL,
    reason              VARCHAR(500)    NOT NULL,
    issued_by_character BIGINT UNSIGNED NOT NULL,
    status              ENUM('active','revoked','executed') NOT NULL DEFAULT 'active',
    created_at          DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    closed_at           DATETIME(3)     NULL,
    closed_by_character BIGINT UNSIGNED NULL,
    PRIMARY KEY (id),
    KEY idx_warrants_char (character_id, status),
    CONSTRAINT fk_warrants_character FOREIGN KEY (character_id) REFERENCES characters (id),
    CONSTRAINT fk_warrants_issuer FOREIGN KEY (issued_by_character) REFERENCES characters (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE evidence_cases (
    case_number VARCHAR(24)     NOT NULL,               -- z. B. 'LSPD-2026-0001'
    title       VARCHAR(200)    NOT NULL,
    created_by  BIGINT UNSIGNED NOT NULL,               -- character_id
    created_at  DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (case_number),
    CONSTRAINT fk_evcases_creator FOREIGN KEY (created_by) REFERENCES characters (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE evidence_log (
    id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    case_number  VARCHAR(24)     NOT NULL,
    item_uuid    CHAR(36)        NOT NULL,
    action       ENUM('stored','checked_out','returned') NOT NULL,
    by_character BIGINT UNSIGNED NOT NULL,
    note         VARCHAR(300)    NOT NULL DEFAULT '',
    created_at   DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    KEY idx_evlog_case (case_number, created_at),
    KEY idx_evlog_item (item_uuid),
    CONSTRAINT fk_evlog_case FOREIGN KEY (case_number) REFERENCES evidence_cases (case_number),
    CONSTRAINT fk_evlog_character FOREIGN KEY (by_character) REFERENCES characters (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
