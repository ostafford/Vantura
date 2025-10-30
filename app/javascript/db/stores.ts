/**
 * IndexedDB store schemas and TypeScript interfaces
 */

import type { QueuedMutation } from '../types/offline'

/**
 * Cached transaction data
 */
export interface CachedTransaction {
  id: number
  data: Record<string, unknown>
  cached_at: number // timestamp
  expires_at: number // timestamp (30 days from cached_at)
}

/**
 * Cached dashboard stats
 */
export interface CachedDashboardStats {
  id: string // date string (YYYY-MM-DD)
  data: Record<string, unknown>
  cached_at: number // timestamp
  expires_at: number // timestamp (7 days from cached_at)
}

/**
 * Cached filter data
 */
export interface CachedFilter {
  id: number
  data: Record<string, unknown>
  cached_at: number // timestamp
}

/**
 * Cached recurring transaction data (active only)
 */
export interface CachedRecurringTransaction {
  id: number
  data: Record<string, unknown>
  cached_at: number // timestamp
}

/**
 * Queued mutation store entry
 */
export interface QueuedMutationEntry extends QueuedMutation {
  id: string
}

