-- 0027: Smartphone-Social — Twitter-Klon + Kleinanzeigen.
-- Inhalte doppelt: hier für In-Game-Anzeige, im Log-Store (comms.tweet/ad)
-- für ACP/Ermittlungen (Katalog §2.2: Kommunikation wird vollständig geloggt).

CREATE TABLE tweets (
    id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    character_id BIGINT UNSIGNED NOT NULL,
    handle       VARCHAR(32)     NOT NULL,        -- @vorname_nachname
    body         VARCHAR(280)    NOT NULL,
    created_at   DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    KEY idx_tweets_time (created_at),
    CONSTRAINT fk_tweets_character FOREIGN KEY (character_id) REFERENCES characters (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE classifieds (
    id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    character_id BIGINT UNSIGNED NOT NULL,
    phone_number CHAR(7)         NOT NULL,        -- Kontakt (IC)
    body         VARCHAR(300)    NOT NULL,
    created_at   DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    expires_at   DATETIME(3)     NOT NULL,
    PRIMARY KEY (id),
    KEY idx_classifieds_active (expires_at),
    CONSTRAINT fk_classifieds_character FOREIGN KEY (character_id) REFERENCES characters (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
