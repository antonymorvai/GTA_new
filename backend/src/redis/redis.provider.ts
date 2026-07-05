import Redis from 'ioredis';

export const REDIS = 'REDIS_CLIENT';

export const redisProvider = {
  provide: REDIS,
  useFactory: (): Redis => {
    const url = process.env.REDIS_URL ?? 'redis://localhost:6379';
    return new Redis(url, { maxRetriesPerRequest: null });
  },
};

/** Stream-Namen zentral, damit Producer und Consumer nie divergieren. */
export const STREAMS = {
  events: 'hrp:events',
  dead: 'hrp:events:dead',
  group: 'logstore-writers',
} as const;
