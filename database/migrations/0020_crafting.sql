-- 0020: Crafting — Rezepte als DATEN (Skill-Freischaltung, zur Laufzeit pflegbar).

CREATE TABLE crafting_recipes (
    id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
    name        VARCHAR(64)  NOT NULL,            -- Code-Name, z. B. 'bandage'
    label       VARCHAR(128) NOT NULL,
    output_item VARCHAR(64)  NOT NULL,            -- item_definitions.name
    output_qty  SMALLINT UNSIGNED NOT NULL DEFAULT 1,
    skill       VARCHAR(32)  NOT NULL DEFAULT 'crafting',
    min_level   TINYINT UNSIGNED NOT NULL DEFAULT 0,
    xp_reward   SMALLINT UNSIGNED NOT NULL DEFAULT 15,
    -- Zutaten: [{"item":"cloth","qty":2}, ...]
    inputs      JSON         NOT NULL,
    active      TINYINT(1)   NOT NULL DEFAULT 1,
    PRIMARY KEY (id),
    UNIQUE KEY uq_recipes_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
