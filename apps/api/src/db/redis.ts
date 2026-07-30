import Redis from 'ioredis';
import { config } from '../config';

let redis: any;
const store = new Map<string, any>();

function useInMemoryMock() {
  console.log('⚡ Using in-memory Redis fallback (ideal for local testing without Docker)');
  
  redis = {
    get: async (key: string) => {
      const entry = store.get(key);
      if (!entry) return null;
      if (entry.expiry && Date.now() > entry.expiry) {
        store.delete(key);
        return null;
      }
      return entry.value;
    },
    set: async (key: string, value: string, ...args: any[]) => {
      const hasNX = args.map(a => typeof a === 'string' ? a.toUpperCase() : a).includes('NX');
      
      // Check if key exists and hasn't expired for NX lock check
      const existing = store.get(key);
      const isStillValid = existing && (!existing.expiry || Date.now() < existing.expiry);
      
      if (hasNX && isStillValid) {
        return null; // lock acquisition failed
      }

      let expiry: number | null = null;
      const exIndex = args.map(a => typeof a === 'string' ? a.toUpperCase() : a).indexOf('EX');
      if (exIndex !== -1 && typeof args[exIndex + 1] === 'number') {
        const ttlSeconds = args[exIndex + 1];
        expiry = Date.now() + (ttlSeconds * 1000);
      }

      store.set(key, { value, expiry });
      return 'OK';
    },
    del: async (key: string) => {
      const existed = store.has(key);
      store.delete(key);
      return existed ? 1 : 0;
    },
    on: (event: string, callback: Function) => {
      if (event === 'connect') {
        // Simulate immediate connection
        setTimeout(() => callback(), 0);
      }
    },
    quit: async () => {
      store.clear();
      return 'OK';
    },
  };
}

try {
  // If the user's config points to localhost but Redis is down, ioredis will emit 'error'
  const client = new Redis(config.REDIS_URL, {
    maxRetriesPerRequest: 1,
    connectTimeout: 1000,
    lazyConnect: true,
  });

  client.on('error', (err) => {
    // If we haven't switched to mock yet, do it now
    if (redis === client) {
      useInMemoryMock();
    }
  });

  // Try to connect
  client.connect().then(() => {
    console.log('🔌 Connected to real Redis server');
    redis = client;
  }).catch((err) => {
    useInMemoryMock();
  });

  redis = client;
} catch (err) {
  useInMemoryMock();
}

export { redis };
