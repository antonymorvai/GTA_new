-- 0025: Kredite (Bonität aus echten Verhaltensdaten) + Blitzer.

CREATE TABLE loans (
    id            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    character_id  BIGINT UNSIGNED NOT NULL,
    principal     BIGINT          NOT NULL,        -- Cent, ausgezahlt
    remaining     BIGINT          NOT NULL,        -- Cent, inkl. Zinsen
    interest_rate DECIMAL(4,3)    NOT NULL,        -- z. B. 0.100
    missed        TINYINT UNSIGNED NOT NULL DEFAULT 0,   -- verpasste Raten in Folge
    status        ENUM('active','paid','defaulted') NOT NULL DEFAULT 'active',
    created_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    closed_at     DATETIME(3)     NULL,
    PRIMARY KEY (id),
    KEY idx_loans_character (character_id, status),
    CONSTRAINT fk_loans_character FOREIGN KEY (character_id) REFERENCES characters (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE speed_cameras (
    id         INT UNSIGNED NOT NULL AUTO_INCREMENT,
    label      VARCHAR(128) NOT NULL,
    pos_x      FLOAT        NOT NULL,
    pos_y      FLOAT        NOT NULL,
    pos_z      FLOAT        NOT NULL,
    limit_kmh  SMALLINT UNSIGNED NOT NULL DEFAULT 80,
    active     TINYINT(1)   NOT NULL DEFAULT 1,
    PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO speed_cameras (label, pos_x, pos_y, pos_z, limit_kmh) VALUES
    ('Del Perro Freeway West',   -1560.5, -670.3, 28.5, 120),
    ('Olympic Freeway Downtown',  490.4, -570.2, 24.5, 100),
    ('Senora Freeway Nord',       1712.4, 4805.5, 41.5, 120),
    ('Innenstadt Alta Street',    -230.6, -900.4, 29.5, 60)
ON DUPLICATE KEY UPDATE label = VALUES(label);

-- Automatische Bußgelder (Blitzer) haben keinen ausstellenden Beamten
ALTER TABLE fines MODIFY issued_by BIGINT UNSIGNED NULL;
