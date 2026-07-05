-- 0019: Launch-Workflows — Whitelist-Bewerbungen, Tickets/Reports, Sanktionen.

CREATE TABLE whitelist_applications (
    id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    account_id   BIGINT UNSIGNED NOT NULL,
    -- Antworten des Fragebogens + Charakterkonzept (JSON, server-seitig validiert)
    answers      JSON            NOT NULL,
    -- Regeltest: server-seitig bewertet, Bestehen ist Einreich-Voraussetzung
    test_score   TINYINT UNSIGNED NOT NULL,
    test_total   TINYINT UNSIGNED NOT NULL,
    status       ENUM('pending','approved','rejected') NOT NULL DEFAULT 'pending',
    reviewed_by  BIGINT UNSIGNED NULL,
    review_note  VARCHAR(500)    NULL,
    created_at   DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    reviewed_at  DATETIME(3)     NULL,
    PRIMARY KEY (id),
    KEY idx_applications_status (status, created_at),
    KEY idx_applications_account (account_id),
    CONSTRAINT fk_applications_account FOREIGN KEY (account_id) REFERENCES accounts (id),
    CONSTRAINT fk_applications_reviewer FOREIGN KEY (reviewed_by) REFERENCES accounts (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE tickets (
    id                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    account_id        BIGINT UNSIGNED NOT NULL,
    category          ENUM('support','bug','complaint','report','refund','other') NOT NULL,
    subject           VARCHAR(200)    NOT NULL,
    -- Bei Spielerreports: gemeldeter Account/Charakter (Freitext-Referenz)
    reported_ref      VARCHAR(128)    NULL,
    status            ENUM('open','answered','closed') NOT NULL DEFAULT 'open',
    assigned_to       BIGINT UNSIGNED NULL,
    created_at        DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    closed_at         DATETIME(3)     NULL,
    PRIMARY KEY (id),
    KEY idx_tickets_status (status, created_at),
    KEY idx_tickets_account (account_id),
    CONSTRAINT fk_tickets_account FOREIGN KEY (account_id) REFERENCES accounts (id),
    CONSTRAINT fk_tickets_assignee FOREIGN KEY (assigned_to) REFERENCES accounts (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE ticket_messages (
    id         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    ticket_id  BIGINT UNSIGNED NOT NULL,
    author_id  BIGINT UNSIGNED NOT NULL,
    is_staff   TINYINT(1)      NOT NULL DEFAULT 0,
    body       TEXT            NOT NULL,
    -- Beweis-Verweise: Log-Permalinks, Screenshot-URLs (Uploads folgen)
    evidence   VARCHAR(1000)   NULL,
    created_at DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    KEY idx_ticketmsg_ticket (ticket_id, created_at),
    CONSTRAINT fk_ticketmsg_ticket FOREIGN KEY (ticket_id) REFERENCES tickets (id),
    CONSTRAINT fk_ticketmsg_author FOREIGN KEY (author_id) REFERENCES accounts (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Vollständige Sanktionshistorie (Bans zusätzlich in account_bans für den
-- Connect-Check; diese Tabelle ist die lückenlose Akte inkl. Verwarnungen).
CREATE TABLE sanctions (
    id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    account_id  BIGINT UNSIGNED NOT NULL,
    kind        ENUM('warn','kick','ban') NOT NULL,
    reason      VARCHAR(500)    NOT NULL,
    evidence    VARCHAR(1000)   NULL,           -- Log-Permalinks (Pflichtfeld im ACP-UI)
    ban_id      BIGINT UNSIGNED NULL,           -- Verknüpfung bei kind='ban'
    issued_by   BIGINT UNSIGNED NOT NULL,
    created_at  DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    KEY idx_sanctions_account (account_id, created_at),
    CONSTRAINT fk_sanctions_account FOREIGN KEY (account_id) REFERENCES accounts (id),
    CONSTRAINT fk_sanctions_ban FOREIGN KEY (ban_id) REFERENCES account_bans (id),
    CONSTRAINT fk_sanctions_issuer FOREIGN KEY (issued_by) REFERENCES accounts (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
