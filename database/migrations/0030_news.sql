-- 0030: Zeitung — Artikel von Journalisten, öffentlich lesbar (Homepage/UCP).

CREATE TABLE news_articles (
    id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    author_id    BIGINT UNSIGNED NOT NULL,      -- character_id (Journalist)
    headline     VARCHAR(200)    NOT NULL,
    body         TEXT            NOT NULL,
    published_at DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    KEY idx_articles_time (published_at),
    CONSTRAINT fk_articles_author FOREIGN KEY (author_id) REFERENCES characters (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
