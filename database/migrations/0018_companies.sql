-- 0018: Firmen — Handelsregister, Mitglieder, Firmenkonto.
-- Firmenkonto-Salden leben hier; JEDE Bewegung läuft über die Core-Geld-API
-- (Company-Varianten) und erzeugt money.*-Events mit target kind 'company'.

CREATE TABLE companies (
    id           INT UNSIGNED NOT NULL AUTO_INCREMENT,
    name         VARCHAR(48)  NOT NULL,          -- Registrierungs-Kürzel
    label        VARCHAR(128) NOT NULL,
    owner_id     BIGINT UNSIGNED NOT NULL,       -- character_id (Geschäftsführung)
    created_at   DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    dissolved_at DATETIME(3)  NULL,              -- Insolvenz/Auflösung (Soft-Delete)
    PRIMARY KEY (id),
    UNIQUE KEY uq_companies_name (name),
    CONSTRAINT fk_companies_owner FOREIGN KEY (owner_id) REFERENCES characters (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE company_members (
    company_id   INT UNSIGNED    NOT NULL,
    character_id BIGINT UNSIGNED NOT NULL,
    rank         TINYINT UNSIGNED NOT NULL DEFAULT 0,   -- 0 Mitarbeiter, 1 Leitung, 2 Inhaber
    salary       BIGINT          NOT NULL DEFAULT 0,    -- Cent pro Lohnlauf
    hired_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (company_id, character_id),
    KEY idx_compmembers_char (character_id),
    CONSTRAINT fk_compmembers_company FOREIGN KEY (company_id) REFERENCES companies (id),
    CONSTRAINT fk_compmembers_character FOREIGN KEY (character_id) REFERENCES characters (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE company_funds (
    company_id INT UNSIGNED NOT NULL,
    balance    BIGINT       NOT NULL DEFAULT 0,
    updated_at DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    PRIMARY KEY (company_id),
    CONSTRAINT fk_compfunds_company FOREIGN KEY (company_id) REFERENCES companies (id),
    CONSTRAINT chk_compfunds_nonneg CHECK (balance >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
