-- 0014: Dynamische Ressourcen — endliche, sich regenerierende Pools.
-- Overfarming erschöpft Spots (current -> 0), Regeneration pro Tick;
-- Spieler müssen Gebiete wechseln -> natürliche Verteilung auf der Map.

CREATE TABLE resource_pools (
    id             INT UNSIGNED NOT NULL AUTO_INCREMENT,
    pool_type      ENUM('fishing','mining','logging','hunting','farming') NOT NULL,
    label          VARCHAR(128) NOT NULL,
    pos_x          FLOAT        NOT NULL,
    pos_y          FLOAT        NOT NULL,
    pos_z          FLOAT        NOT NULL,
    radius         FLOAT        NOT NULL DEFAULT 20.0,
    capacity       INT UNSIGNED NOT NULL DEFAULT 100,
    current        INT UNSIGNED NOT NULL DEFAULT 100,
    regen_per_tick INT UNSIGNED NOT NULL DEFAULT 5,
    item_name      VARCHAR(64)  NOT NULL,       -- item_definitions.name des Ertrags
    skill          VARCHAR(32)  NOT NULL,       -- character_skills-Key (XP durch Nutzung)
    active         TINYINT(1)   NOT NULL DEFAULT 1,
    PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
