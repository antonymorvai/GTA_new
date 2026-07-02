-- 0001: Accounts, Identifiers, Sessions, Bans
-- Konvention: Alle Migrations sind idempotent-sicher via schema_migrations
-- (siehe scripts/migrate.sh). Kein DROP in Migrations.

CREATE TABLE IF NOT EXISTS schema_migrations (
    version     VARCHAR(64)  NOT NULL PRIMARY KEY,
    applied_at  DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE accounts (
    id                 BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    username           VARCHAR(32)     NOT NULL,
    email              VARCHAR(255)    NULL,
    email_verified_at  DATETIME(3)     NULL,
    -- Argon2id-Hash; NULL solange Account nur in-game existiert (UCP-Registrierung folgt)
    password_hash      VARCHAR(255)    NULL,
    totp_secret        VARBINARY(128)  NULL,
    totp_enabled       TINYINT(1)      NOT NULL DEFAULT 0,
    -- Cfx-Identifier (license:xxxx) als primärer Spiel-Anker
    license            VARCHAR(64)     NULL,
    discord_id         VARCHAR(32)     NULL,
    whitelist_status   ENUM('none','pending','approved','rejected') NOT NULL DEFAULT 'none',
    created_at         DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    updated_at         DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    last_login_at      DATETIME(3)     NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_accounts_username (username),
    UNIQUE KEY uq_accounts_email (email),
    UNIQUE KEY uq_accounts_license (license),
    UNIQUE KEY uq_accounts_discord (discord_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Historie aller gesehenen Identifier (IP/HWID/...) für Multi-Account-Erkennung.
CREATE TABLE account_identifiers (
    id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    account_id  BIGINT UNSIGNED NOT NULL,
    id_type     ENUM('ip','hwid','license','discord','steam','fivem') NOT NULL,
    id_value    VARCHAR(128)    NOT NULL,
    first_seen  DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    last_seen   DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    UNIQUE KEY uq_ident (account_id, id_type, id_value),
    KEY idx_ident_lookup (id_type, id_value),
    CONSTRAINT fk_ident_account FOREIGN KEY (account_id) REFERENCES accounts (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Eine Session pro Verbindung; session_id wandert in JEDES Log-Event.
CREATE TABLE sessions (
    id            CHAR(36)        NOT NULL,           -- UUID v4
    account_id    BIGINT UNSIGNED NOT NULL,
    character_id  BIGINT UNSIGNED NULL,
    ip            VARCHAR(45)     NOT NULL,
    started_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    ended_at      DATETIME(3)     NULL,
    end_reason    VARCHAR(128)    NULL,
    PRIMARY KEY (id),
    KEY idx_sessions_account (account_id, started_at),
    CONSTRAINT fk_sessions_account FOREIGN KEY (account_id) REFERENCES accounts (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE account_bans (
    id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    account_id  BIGINT UNSIGNED NOT NULL,
    issued_by   BIGINT UNSIGNED NULL,                 -- NULL = System/Anti-Cheat
    reason      TEXT            NOT NULL,
    evidence    TEXT            NULL,                 -- Permalinks auf Log-Ansichten
    expires_at  DATETIME(3)     NULL,                 -- NULL = permanent
    created_at  DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    revoked_at  DATETIME(3)     NULL,
    revoked_by  BIGINT UNSIGNED NULL,
    PRIMARY KEY (id),
    KEY idx_bans_account (account_id, expires_at),
    CONSTRAINT fk_bans_account FOREIGN KEY (account_id) REFERENCES accounts (id),
    CONSTRAINT fk_bans_issuer  FOREIGN KEY (issued_by)  REFERENCES accounts (id),
    CONSTRAINT fk_bans_revoker FOREIGN KEY (revoked_by) REFERENCES accounts (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
