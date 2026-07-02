-- 0007: Jobs-Grundgerüst — Jobs, Grades, Zuordnung, Dienststatus.
-- Fraktions-Spezifika (MDT, Akten, Funk) folgen in Phase 3 auf dieser Basis.

CREATE TABLE jobs (
    id        INT UNSIGNED NOT NULL AUTO_INCREMENT,
    name      VARCHAR(48)  NOT NULL,        -- 'police', 'ems', 'trucker', ...
    label     VARCHAR(128) NOT NULL,
    is_state  TINYINT(1)   NOT NULL DEFAULT 0,  -- staatlich: Lohn aus Staatskasse
    PRIMARY KEY (id),
    UNIQUE KEY uq_jobs_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE job_grades (
    id        INT UNSIGNED NOT NULL AUTO_INCREMENT,
    job_id    INT UNSIGNED NOT NULL,
    grade     TINYINT UNSIGNED NOT NULL,    -- 0 = niedrigster Rang
    label     VARCHAR(128) NOT NULL,
    salary    BIGINT       NOT NULL DEFAULT 0,  -- Cent pro Lohnlauf
    PRIMARY KEY (id),
    UNIQUE KEY uq_job_grade (job_id, grade),
    CONSTRAINT fk_grades_job FOREIGN KEY (job_id) REFERENCES jobs (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE character_jobs (
    character_id BIGINT UNSIGNED NOT NULL,
    job_id       INT UNSIGNED    NOT NULL,
    grade        TINYINT UNSIGNED NOT NULL DEFAULT 0,
    on_duty      TINYINT(1)      NOT NULL DEFAULT 0,
    hired_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (character_id),                -- Phase 2: genau ein Job pro Charakter
    KEY idx_charjobs_job (job_id, on_duty),
    CONSTRAINT fk_charjobs_character FOREIGN KEY (character_id) REFERENCES characters (id),
    CONSTRAINT fk_charjobs_job FOREIGN KEY (job_id) REFERENCES jobs (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
