-- 0006: Wirtschafts-Engine — Shops mit dynamischen Preisen (Angebot & Nachfrage).
-- Preise sind ZUSTAND, kein Konstantenwert: current_price wandert mit jedem
-- Kauf/Verkauf Richtung Gleichgewicht und wird periodisch Richtung Ziel-Bestand
-- korrigiert (economy.price_tick-Events, Parameter via config_flags).

CREATE TABLE shops (
    id         INT UNSIGNED NOT NULL AUTO_INCREMENT,
    name       VARCHAR(64)  NOT NULL,      -- Code-Name, z. B. 'supermarket_grove'
    label      VARCHAR(128) NOT NULL,
    region     VARCHAR(32)  NOT NULL,      -- Preiszone, z. B. 'los_santos_south'
    pos_x      FLOAT        NOT NULL,
    pos_y      FLOAT        NOT NULL,
    pos_z      FLOAT        NOT NULL,
    created_at DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    UNIQUE KEY uq_shops_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE shop_items (
    id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    shop_id        INT UNSIGNED NOT NULL,
    definition_id  INT UNSIGNED NOT NULL,
    base_price     BIGINT       NOT NULL,   -- Cent; Anker der Preisformel
    current_price  BIGINT       NOT NULL,   -- Cent; dynamisch
    stock          INT          NOT NULL DEFAULT 0,
    target_stock   INT          NOT NULL DEFAULT 100,  -- Gleichgewichtsbestand
    restock_rate   INT          NOT NULL DEFAULT 10,   -- Zulauf pro Tick (Lieferketten ersetzen das in Phase 4)
    can_buy        TINYINT(1)   NOT NULL DEFAULT 1,    -- Spieler kauft vom Shop
    can_sell       TINYINT(1)   NOT NULL DEFAULT 0,    -- Spieler verkauft an Shop
    PRIMARY KEY (id),
    UNIQUE KEY uq_shop_item (shop_id, definition_id),
    KEY idx_shopitems_def (definition_id),
    CONSTRAINT fk_shopitems_shop FOREIGN KEY (shop_id) REFERENCES shops (id),
    CONSTRAINT fk_shopitems_def FOREIGN KEY (definition_id) REFERENCES item_definitions (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
