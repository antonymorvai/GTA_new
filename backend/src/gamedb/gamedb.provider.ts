import { createPool, Pool } from 'mysql2/promise';

export const GAMEDB = 'GAMEDB_POOL';

/** MariaDB-Pool (Spiel-DB) — ausschließlich Prepared Statements. */
export const gamedbProvider = {
  provide: GAMEDB,
  useFactory: (): Pool =>
    createPool({
      uri: process.env.GAMEDB_URL,
      connectionLimit: 10,
      namedPlaceholders: false,
    }),
};

export type GameDb = Pool;
