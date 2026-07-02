-- 0002: RBAC — Rollen, Permissions, Zuweisungen.
-- Jede Zuweisung trägt granted_by; die eigentliche Audit-Spur liegt zusätzlich
-- als rbac.*-Event im Log-Store (siehe docs/log-event-catalog.md).

CREATE TABLE roles (
    id         INT UNSIGNED NOT NULL AUTO_INCREMENT,
    name       VARCHAR(64)  NOT NULL,
    label      VARCHAR(128) NOT NULL,
    -- höhere priority = mehr Autorität; schützt vor Selbst-Eskalation
    priority   INT          NOT NULL DEFAULT 0,
    is_system  TINYINT(1)   NOT NULL DEFAULT 0,   -- System-Rollen nicht löschbar
    created_at DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    UNIQUE KEY uq_roles_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE permissions (
    id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
    name        VARCHAR(128) NOT NULL,   -- z. B. 'game.item.give', 'acp.player.view'
    description VARCHAR(255) NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_permissions_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE role_permissions (
    role_id       INT UNSIGNED NOT NULL,
    permission_id INT UNSIGNED NOT NULL,
    granted_by    BIGINT UNSIGNED NULL,
    granted_at    DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (role_id, permission_id),
    CONSTRAINT fk_rp_role FOREIGN KEY (role_id) REFERENCES roles (id),
    CONSTRAINT fk_rp_perm FOREIGN KEY (permission_id) REFERENCES permissions (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE account_roles (
    account_id BIGINT UNSIGNED NOT NULL,
    role_id    INT UNSIGNED    NOT NULL,
    granted_by BIGINT UNSIGNED NULL,
    granted_at DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (account_id, role_id),
    CONSTRAINT fk_ar_account FOREIGN KEY (account_id) REFERENCES accounts (id),
    CONSTRAINT fk_ar_role    FOREIGN KEY (role_id)    REFERENCES roles (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
