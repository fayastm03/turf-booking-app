"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.redis = void 0;
const ioredis_1 = __importDefault(require("ioredis"));
const config_1 = require("../config");
let redis;
const store = new Map();
function useInMemoryMock() {
    console.log('⚡ Using in-memory Redis fallback (ideal for local testing without Docker)');
    exports.redis = redis = {
        get: async (key) => {
            const entry = store.get(key);
            if (!entry)
                return null;
            if (entry.expiry && Date.now() > entry.expiry) {
                store.delete(key);
                return null;
            }
            return entry.value;
        },
        set: async (key, value, ...args) => {
            const hasNX = args.map(a => typeof a === 'string' ? a.toUpperCase() : a).includes('NX');
            // Check if key exists and hasn't expired for NX lock check
            const existing = store.get(key);
            const isStillValid = existing && (!existing.expiry || Date.now() < existing.expiry);
            if (hasNX && isStillValid) {
                return null; // lock acquisition failed
            }
            let expiry = null;
            const exIndex = args.map(a => typeof a === 'string' ? a.toUpperCase() : a).indexOf('EX');
            if (exIndex !== -1 && typeof args[exIndex + 1] === 'number') {
                const ttlSeconds = args[exIndex + 1];
                expiry = Date.now() + (ttlSeconds * 1000);
            }
            store.set(key, { value, expiry });
            return 'OK';
        },
        del: async (key) => {
            const existed = store.has(key);
            store.delete(key);
            return existed ? 1 : 0;
        },
        on: (event, callback) => {
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
    const client = new ioredis_1.default(config_1.config.REDIS_URL, {
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
        exports.redis = redis = client;
    }).catch((err) => {
        useInMemoryMock();
    });
    exports.redis = redis = client;
}
catch (err) {
    useInMemoryMock();
}
