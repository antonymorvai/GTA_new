-- 0004: Inventar — Item-Definitionen + Item-INSTANZEN mit eindeutiger ID.
-- Jede physische Item-Einheit (bzw. jeder Stack) ist eine Instanz mit UUID.
-- Der komplette Lebenszyklus (Erstellung, jeder Besitzwechsel, jede Bewegung,
-- Verbrauch, Zerstörung) wird als item.*-Event geloggt -> Item-Trace im ACP.

CREATE TABLE item_definitions (
    id              INT UNSIGNED NOT NULL AUTO_INCREMENT,
    name            VARCHAR(64)  NOT NULL,    -- Code-Name, z. B. 'water_bottle'
    label           VARCHAR(128) NOT NULL,    -- Anzeige (Deutsch)
    category        VARCHAR(32)  NOT NULL,    -- 'food','weapon','tool','drug',...
    weight_grams    INT UNSIGNED NOT NULL DEFAULT 0,
    max_stack       SMALLINT UNSIGNED NOT NULL DEFAULT 1,  -- 1 = nicht stapelbar (instanziert)
    is_unique       TINYINT(1)   NOT NULL DEFAULT 0,       -- Seriennummer-pflichtig (Waffen etc.)
    usable          TINYINT(1)   NOT NULL DEFAULT 0,
    metadata_schema JSON         NULL,        -- dokumentiert erwartete metadata-Felder
    created_at      DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    UNIQUE KEY uq_itemdef_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE item_instances (
    id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    uuid           CHAR(36)        NOT NULL,   -- öffentliche Instanz-ID (Item-Trace)
    definition_id  INT UNSIGNED    NOT NULL,
    quantity       INT UNSIGNED    NOT NULL DEFAULT 1,
    quality        TINYINT UNSIGNED NULL,      -- 0..100 (Drogen, Lebensmittel...)
    serial_number  VARCHAR(32)     NULL,       -- Waffen; feilbar aber rekonstruierbar
    shots_fired    INT UNSIGNED    NOT NULL DEFAULT 0,
    expires_at     DATETIME(3)     NULL,       -- MHD
    metadata       JSON            NULL,       -- Fingerabdrücke, Herkunft, etc.
    created_reason VARCHAR(64)     NOT NULL,   -- Grund-Code, z. B. 'shop.buy','craft','admin.give'
    created_by     BIGINT UNSIGNED NULL,       -- character_id des Erzeugers
    created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    destroyed_at   DATETIME(3)     NULL,       -- Soft-Delete: Instanzen verschwinden NIE aus der DB
    destroy_reason VARCHAR(64)     NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_item_uuid (uuid),
    UNIQUE KEY uq_item_serial (serial_number),
    KEY idx_item_definition (definition_id),
    CONSTRAINT fk_item_definition FOREIGN KEY (definition_id) REFERENCES item_definitions (id),
    CONSTRAINT fk_item_creator    FOREIGN KEY (created_by)    REFERENCES characters (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Aktueller Aufenthaltsort jeder Instanz (genau einer). Historie -> Log-Store.
CREATE TABLE item_locations (
    instance_id    BIGINT UNSIGNED NOT NULL,
    container_type ENUM('character','vehicle_trunk','vehicle_glovebox','ground',
                        'storage','evidence','shop','none') NOT NULL,
    container_id   VARCHAR(64)     NOT NULL,   -- character_id, vehicle plate, storage key...
    slot           SMALLINT UNSIGNED NULL,
    updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    PRIMARY KEY (instance_id),
    KEY idx_location_container (container_type, container_id),
    CONSTRAINT fk_location_instance FOREIGN KEY (instance_id) REFERENCES item_instances (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
