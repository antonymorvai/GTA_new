-- 0008: Bank — Kontonummern und Daueraufträge.
-- Salden bleiben in character_money.bank (eine Quelle der Wahrheit);
-- der komplette Zahlungsfluss lebt als money.*-Events im Log-Store
-- (Kontoauszüge im UCP werden daraus generiert).

CREATE TABLE bank_details (
    character_id   BIGINT UNSIGNED NOT NULL,
    account_number CHAR(10)        NOT NULL,   -- z. B. 'LS10482937'
    created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (character_id),
    UNIQUE KEY uq_bank_number (account_number),
    CONSTRAINT fk_bank_character FOREIGN KEY (character_id) REFERENCES characters (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE standing_orders (
    id                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    from_character_id BIGINT UNSIGNED NOT NULL,
    to_account_number CHAR(10)        NOT NULL,
    amount            BIGINT          NOT NULL,   -- Cent
    reference         VARCHAR(128)    NOT NULL DEFAULT '',
    interval_hours    INT UNSIGNED    NOT NULL DEFAULT 24,
    next_run_at       DATETIME(3)     NOT NULL,
    active            TINYINT(1)      NOT NULL DEFAULT 1,
    created_at        DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    KEY idx_orders_due (active, next_run_at),
    KEY idx_orders_from (from_character_id),
    CONSTRAINT fk_orders_character FOREIGN KEY (from_character_id) REFERENCES characters (id),
    CONSTRAINT chk_order_amount CHECK (amount > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
