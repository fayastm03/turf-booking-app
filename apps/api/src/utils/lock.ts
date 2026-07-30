import { redis } from '../db/redis';

// Lua script to release a lock.
// It checks if the lock value matches the expected client token before deleting it.
// This prevents Client A from deleting a lock that has expired and been acquired by Client B.
const RELEASE_SCRIPT = `
  if redis.call("get", KEYS[1]) == ARGV[1] then
    return redis.call("del", KEYS[1])
  else
    return 0
  end
`;

export class LockManager {
  /**
   * Acquires a lock for a given resource.
   * @param key The key to lock (e.g., `hold:${slotId}`)
   * @param value A unique identifier representing the owner/client (e.g., `userId`)
   * @param ttlSeconds Lock timeout in seconds (e.g., 30s lock, 300s hold)
   * @returns true if the lock was acquired, false otherwise
   */
  static async acquire(key: string, value: string, ttlSeconds: number): Promise<boolean> {
    try {
      const result = await redis.set(key, value, 'NX', 'EX', ttlSeconds);
      return result === 'OK';
    } catch (err) {
      console.error(`[LockManager] Failed to acquire lock for key ${key}:`, err);
      // Fallback behavior if Redis connection is temporarily unstable
      return false;
    }
  }

  /**
   * Releases a lock safely. Only releases if the lock is held by the caller who owns the unique value.
   * @param key The lock key
   * @param value The unique value that was used to acquire the lock
   * @returns true if successfully released, false otherwise
   */
  static async release(key: string, value: string): Promise<boolean> {
    try {
      // If we are using the in-memory mock fallback, it might not support eval or lua.
      // So we check if redis has eval method. If not, we fall back to a manual check-and-delete.
      if (typeof redis.eval === 'function') {
        const result = await redis.eval(RELEASE_SCRIPT, 1, key, value);
        return result === 1;
      } else {
        const currentValue = await redis.get(key);
        if (currentValue === value) {
          await redis.del(key);
          return true;
        }
        return false;
      }
    } catch (err) {
      console.error(`[LockManager] Failed to release lock for key ${key}:`, err);
      return false;
    }
  }
}
