-- 0005: Live-Tuning / Feature-Flags (Kernprinzip B).
-- Jeder Balancing-Wert ist DATEN: zur Laufzeit änderbar, versioniert, rollbackfähig.
-- Werte werden von hrp_core/server/tuning.lua gecacht und per Event verteilt.

CREATE TABLE config_flags (
    flag_key    VARCHAR(96)  NOT NULL,      -- z. B. 'economy.price_tick_minutes'
    flag_value  JSON         NOT NULL,      -- beliebiger JSON-Wert (Zahl, Bool, Objekt)
    description VARCHAR(255) NULL,
    updated_by  BIGINT UNSIGNED NULL,       -- account_id, NULL = System/Seed
    updated_at  DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    PRIMARY KEY (flag_key),
    CONSTRAINT fk_flags_account FOREIGN KEY (updated_by) REFERENCES accounts (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Append-only Historie -> Rollback = alten Wert erneut setzen (neuer Eintrag).
CREATE TABLE config_flag_history (
    id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    flag_key    VARCHAR(96)  NOT NULL,
    old_value   JSON         NULL,
    new_value   JSON         NOT NULL,
    changed_by  BIGINT UNSIGNED NULL,
    changed_at  DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    KEY idx_flag_history (flag_key, changed_at),
    CONSTRAINT fk_flag_hist_account FOREIGN KEY (changed_by) REFERENCES accounts (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
