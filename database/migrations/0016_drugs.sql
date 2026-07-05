-- 0016: Illegale Kette — rotierende Deal-Spots.
-- Der World Director rotiert aktive Spots (gewichtet; Polizeipräsenz-Heatmap
-- verfeinert die Gewichtung in einer späteren Ausbaustufe).

CREATE TABLE deal_spots (
    id     INT UNSIGNED NOT NULL AUTO_INCREMENT,
    label  VARCHAR(128) NOT NULL,
    pos_x  FLOAT        NOT NULL,
    pos_y  FLOAT        NOT NULL,
    pos_z  FLOAT        NOT NULL,
    active TINYINT(1)   NOT NULL DEFAULT 0,
    PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
