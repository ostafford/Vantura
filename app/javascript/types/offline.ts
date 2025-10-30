/**
 * TypeScript interfaces for offline system
 */

/**
 * Status of a queued mutation
 */
export type MutationStatus = 'pending' | 'syncing' | 'synced' | 'failed'

/**
 * Type of mutation operation
 */
export type MutationType =
  | 'create_transaction'
  | 'update_transaction'
  | 'delete_transaction'
  | 'create_recurring_transaction'
  | 'update_recurring_transaction'
  | 'delete_recurring_transaction'
  | 'toggle_recurring_active'
  | 'create_filter'
  | 'update_filter'
  | 'delete_filter'

/**
 * Queued mutation stored in IndexedDB
 */
export interface QueuedMutation {
  id: string
  type: MutationType
  payload: Record<string, unknown>
  status: MutationStatus
  retries: number
  created_at: number // timestamp
  error?: string
  url: string // API endpoint URL
  method: string // HTTP method
}

/**
 * Sync progress information
 */
export interface SyncProgress {
  total: number
  synced: number
  failed: number
  percentage: number
  inProgress: boolean
}

/**
 * Queue state summary
 */
export interface QueueState {
  pending: number
  syncing: number
  failed: number
  total: number
}

/**
 * Offline state context
 */
export interface OfflineState {
  isOnline: boolean
  queueState: QueueState
  syncProgress: SyncProgress | null
}

