/**
 * Sync Service
 * Handles syncing queued mutations with exponential backoff retry
 * Implements conflict resolution via server timestamp
 */

import { getPendingMutations, updateMutationStatus, dequeueMutation, incrementRetry } from './queue-manager'
import { deserializeMutation } from './mutation-serializer'
import { apiRequest } from '../api/client'
import type { QueuedMutation, SyncProgress } from '../types/offline'
import type { ApiResponse } from '../types/api'

const MAX_RETRIES = 5
const INITIAL_RETRY_DELAY = 1000 // 1 second

/**
 * Calculate exponential backoff delay
 */
function calculateRetryDelay(retries: number): number {
  return INITIAL_RETRY_DELAY * Math.pow(2, retries)
}

/**
 * Resolve conflict using server timestamp
 * Server timestamp wins if newer than client
 */
function resolveConflict(
  serverTimestamp: string | undefined,
  clientTimestamp: number | undefined
): 'server' | 'client' {
  if (!serverTimestamp && !clientTimestamp) {
    return 'server' // Default to server
  }

  if (!serverTimestamp) {
    return 'client'
  }

  if (!clientTimestamp) {
    return 'server'
  }

  const serverTime = new Date(serverTimestamp).getTime()
  return serverTime > clientTimestamp ? 'server' : 'client'
}

/**
 * Sync a single mutation
 */
async function syncSingleMutation(mutation: QueuedMutation): Promise<boolean> {
  try {
    // Update status to syncing
    await updateMutationStatus(mutation.id, 'syncing')

    // Deserialize mutation
    const { url, method, payload } = deserializeMutation(mutation)

    // Make API request
    const response = await apiRequest(url, {
      method: method as 'POST' | 'PATCH' | 'PUT' | 'DELETE',
      body: method !== 'DELETE' && Object.keys(payload).length > 0 ? JSON.stringify(payload) : undefined,
    })

    // Check for conflict resolution
    const serverTimestamp = (response as ApiResponse<{ updated_at?: string }>).data?.updated_at
    const clientTimestamp = payload.updated_at as number | undefined

    const winner = resolveConflict(serverTimestamp, clientTimestamp)

    if (winner === 'server' && serverTimestamp) {
      // Server timestamp is newer, use server data
      // This will be handled by cache invalidation
    }

    // Success - dequeue mutation
    await dequeueMutation(mutation.id)
    return true
  } catch (error) {
    console.error(`[SyncService] Failed to sync mutation ${mutation.id}:`, error)

    // Increment retry count
    await incrementRetry(mutation.id)

    const newRetries = (mutation.retries || 0) + 1

    if (newRetries >= MAX_RETRIES) {
      // Max retries reached, mark as failed
      await updateMutationStatus(
        mutation.id,
        'failed',
        error instanceof Error ? error.message : 'Max retries reached'
      )
      return false
    }

    // Retry with exponential backoff
    const delay = calculateRetryDelay(newRetries - 1)
    await new Promise((resolve) => setTimeout(resolve, delay))

    // Retry this mutation
    return syncSingleMutation(mutation)
  }
}

/**
 * Broadcast sync progress event
 */
function broadcastSyncProgress(progress: SyncProgress): void {
  const event = new CustomEvent('sync-progress', { detail: progress })
  window.dispatchEvent(event)
}

/**
 * Sync all queued mutations
 * Processes mutations individually (not as batch)
 */
export async function syncQueuedMutations(): Promise<void> {
  if (!navigator.onLine) {
    console.warn('[SyncService] Cannot sync: device is offline')
    return
  }

  const pending = await getPendingMutations()

  if (pending.length === 0) {
    return
  }

  const total = pending.length
  let synced = 0
  let failed = 0

  // Broadcast start
  broadcastSyncProgress({
    total,
    synced: 0,
    failed: 0,
    percentage: 0,
    inProgress: true,
  })

  // Process each mutation individually
  for (const mutation of pending) {
    if (!navigator.onLine) {
      // Connection lost during sync
      await updateMutationStatus(mutation.id, 'pending')
      continue
    }

    const success = await syncSingleMutation(mutation)

    if (success) {
      synced++
    } else {
      failed++
    }

    // Broadcast progress
    broadcastSyncProgress({
      total,
      synced,
      failed,
      percentage: Math.round(((synced + failed) / total) * 100),
      inProgress: synced + failed < total,
    })
  }

  // Broadcast completion
  broadcastSyncProgress({
    total,
    synced,
    failed,
    percentage: 100,
    inProgress: false,
  })
}

/**
 * Register background sync (if supported)
 */
export async function registerBackgroundSync(): Promise<void> {
  if (
    'serviceWorker' in navigator &&
    'sync' in (globalThis.ServiceWorkerRegistration?.prototype || {})
  ) {
    try {
      const registration = await navigator.serviceWorker.ready

      // Type guard for sync manager
      const syncManager = (registration as { sync?: { register: (tag: string) => Promise<void> } })
        .sync

      if (syncManager) {
        await syncManager.register('sync-mutations')
        console.log('[SyncService] Background sync registered')
      }
    } catch (error) {
      console.error('[SyncService] Failed to register background sync:', error)
    }
  }
}

