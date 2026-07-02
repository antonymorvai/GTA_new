-- 0010: Smartphone-Basis — Rufnummern, Kontakte, SMS.
-- SMS-Inhalte werden doppelt gehalten: hier für die In-Game-Anzeige
-- (Verlauf im Handy), im Log-Store (comms.sms) für ACP/Ermittlungen.
-- Anrufe folgen mit der Voice-Integration (Metadaten-Logging vorbereitet).

CREATE TABLE phone_numbers (
    character_id BIGINT UNSIGNED NOT NULL,
    number       CHAR(7)         NOT NULL,   -- z. B. '5551024'
    created_at   DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (character_id),
    UNIQUE KEY uq_phone_number (number),
    CONSTRAINT fk_phone_character FOREIGN KEY (character_id) REFERENCES characters (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE phone_contacts (
    id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    character_id BIGINT UNSIGNED NOT NULL,
    name         VARCHAR(64)     NOT NULL,
    number       CHAR(7)         NOT NULL,
    created_at   DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    UNIQUE KEY uq_contact (character_id, number),
    CONSTRAINT fk_contacts_character FOREIGN KEY (character_id) REFERENCES characters (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE phone_messages (
    id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    from_number CHAR(7)      NOT NULL,
    to_number   CHAR(7)      NOT NULL,
    body        VARCHAR(500) NOT NULL,
    sent_at     DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    KEY idx_messages_to (to_number, sent_at),
    KEY idx_messages_from (from_number, sent_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
