-- 0023: Regierung — Gesetzgebungs-Workflow (Entwurf -> Abstimmung ->
-- Inkrafttreten) und Wahlen (geheime Stimmabgabe: nur Teilnahme wird
-- gespeichert, Parlaments-Abstimmungen sind dagegen namentlich = realistisch).

CREATE TABLE law_proposals (
    id               BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    law_code         VARCHAR(32)     NOT NULL,
    new_fine         BIGINT          NOT NULL,
    new_jail_minutes INT UNSIGNED    NOT NULL,
    rationale        VARCHAR(1000)   NOT NULL,
    proposed_by      BIGINT UNSIGNED NOT NULL,   -- character_id (Regierungsmitglied)
    status           ENUM('voting','passed','rejected','enacted') NOT NULL DEFAULT 'voting',
    votes_yes        INT UNSIGNED    NOT NULL DEFAULT 0,
    votes_no         INT UNSIGNED    NOT NULL DEFAULT 0,
    voting_ends_at   DATETIME(3)     NOT NULL,
    created_at       DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    enacted_at       DATETIME(3)     NULL,
    PRIMARY KEY (id),
    KEY idx_proposals_status (status, voting_ends_at),
    CONSTRAINT fk_proposals_char FOREIGN KEY (proposed_by) REFERENCES characters (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Namentliche Parlaments-Stimme (Nachvollziehbarkeit der Volksvertreter)
CREATE TABLE proposal_votes (
    proposal_id  BIGINT UNSIGNED NOT NULL,
    character_id BIGINT UNSIGNED NOT NULL,
    vote_yes     TINYINT(1)      NOT NULL,
    voted_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (proposal_id, character_id),
    CONSTRAINT fk_pvotes_proposal FOREIGN KEY (proposal_id) REFERENCES law_proposals (id),
    CONSTRAINT fk_pvotes_char FOREIGN KEY (character_id) REFERENCES characters (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE elections (
    id                   BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    office               VARCHAR(48)     NOT NULL,      -- 'governor'
    title                VARCHAR(200)    NOT NULL,
    phase                ENUM('registration','voting','closed') NOT NULL DEFAULT 'registration',
    registration_ends_at DATETIME(3)     NOT NULL,
    voting_ends_at       DATETIME(3)     NOT NULL,
    created_by           BIGINT UNSIGNED NOT NULL,      -- account_id (ACP)
    winner_character_id  BIGINT UNSIGNED NULL,
    created_at           DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    KEY idx_elections_phase (phase)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE election_candidates (
    id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    election_id  BIGINT UNSIGNED NOT NULL,
    character_id BIGINT UNSIGNED NOT NULL,
    statement    VARCHAR(500)    NOT NULL,
    votes        INT UNSIGNED    NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE KEY uq_candidate (election_id, character_id),
    CONSTRAINT fk_candidates_election FOREIGN KEY (election_id) REFERENCES elections (id),
    CONSTRAINT fk_candidates_char FOREIGN KEY (character_id) REFERENCES characters (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- GEHEIME Wahl: nur die Teilnahme wird gespeichert, nie die Stimme.
CREATE TABLE election_voters (
    election_id BIGINT UNSIGNED NOT NULL,
    account_id  BIGINT UNSIGNED NOT NULL,
    voted_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (election_id, account_id),
    CONSTRAINT fk_voters_election FOREIGN KEY (election_id) REFERENCES elections (id),
    CONSTRAINT fk_voters_account FOREIGN KEY (account_id) REFERENCES accounts (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
