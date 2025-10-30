/**
 * Dexie database definition for offline data storage
 */

import Dexie, { type Table } from 'dexie'
import type {
  CachedTransaction,
  CachedDashboardStats,
  CachedFilter,
  CachedRecurringTransaction,
  QueuedMutationEntry
} from './stores'

/**
 * Vantura offline database
 */
class VanturaDatabase extends Dexie {
  transactions!: Table<CachedTransaction, number>
  dashboardStats!: Table<CachedDashboardStats, string>
  filters!: Table<CachedFilter, number>
  recurringTransactions!: Table<CachedRecurringTransaction, number>
  queuedMutations!: Table<QueuedMutationEntry, string>

  constructor() {
    super('VanturaOffline')

    // Define schema version 1
    this.version(1).stores({
      transactions: 'id, cached_at, expires_at',
      dashboardStats: 'id, cached_at, expires_at',
      filters: 'id, cached_at',
      recurringTransactions: 'id, cached_at',
      queuedMutations: 'id, status, created_at'
    })
  }
}

/**
 * Create and export database instance
 */
export const db = new VanturaDatabase()

/**
 * Purge expired cache entries
 * Called periodically to clean up old data
 */
export async function purgeExpiredCache(): Promise<void> {
  const now = Date.now()

  // Purge expired transactions (older than 30 days)
  await db.transactions.where('expires_at').below(now).delete()

  // Purge expired dashboard stats (older than 7 days)
  await db.dashboardStats.where('expires_at').below(now).delete()

  // Purge old queued mutations that have been synced (older than 7 days)
  const sevenDaysAgo = now - 7 * 24 * 60 * 60 * 1000
  await db.queuedMutations
    .where('status')
    .equals('synced')
    .and((mutation) => mutation.created_at < sevenDaysAgo)
    .delete()
}

/**
 * Initialize database and purge expired entries
 */
export async function initializeDatabase(): Promise<void> {
  // Purge expired cache on startup
  await purgeExpiredCache()

  // Schedule periodic cleanup (every hour)
  setInterval(() => {
    void purgeExpiredCache()
  }, 60 * 60 * 1000)
}

