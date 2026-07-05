-- 0024: Sucht-System + Crafting-Werkzeuge/Werkbänke.

-- Substanz-Toleranz/Sucht pro Charakter (Entzug erzeugt Stress)
CREATE TABLE character_addictions (
    character_id     BIGINT UNSIGNED NOT NULL,
    substance        VARCHAR(32)     NOT NULL,   -- 'weed', später 'painkiller', ...
    level            TINYINT UNSIGNED NOT NULL DEFAULT 0,  -- 0..100
    last_consumed_at DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (character_id, substance),
    CONSTRAINT fk_addictions_character FOREIGN KEY (character_id) REFERENCES characters (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Rezepte: optionales Werkzeug (mit Verschleiß) + Werkbank-Pflicht
ALTER TABLE crafting_recipes
    ADD COLUMN tool_item VARCHAR(64) NULL AFTER inputs,
    ADD COLUMN tool_wear TINYINT UNSIGNED NOT NULL DEFAULT 10 AFTER tool_item,
    ADD COLUMN requires_workbench TINYINT(1) NOT NULL DEFAULT 0 AFTER tool_wear;
