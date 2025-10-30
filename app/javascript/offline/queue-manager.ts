/**
 * Mutation Queue Manager
 * CRUD operations for queued mutations stored in IndexedDB
 * Implements queue limit of 100 mutations, blocks when full
 */

import { db } from '../db/index'
import type { QueuedMutation, MutationStatus } from '../types/offline'

const MAX_QUEUE_SIZE = 100

/**
 * Generate unique ID for queued mutation
 */
function generateMutationId(): string {
  return `mutation_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`
}

/**
 * Enqueue a mutation for later sync
 * @param mutation - Mutation to enqueue
 * @returns Mutation ID
 * @throws Error if queue is full (100 mutations)
 */
export async function enqueueMutation(
  mutation: Omit<QueuedMutation, 'id' | 'status' | 'retries' | 'created_at'>
): Promise<string> {
  // Check queue size
  const queueSize = await getQueueSize()

  if (queueSize >= MAX_QUEUE_SIZE) {
    throw new Error(
      `Queue is full (${MAX_QUEUE_SIZE} mutations). Please sync pending mutations before adding new ones.`
    )
  }

  const id = generateMutationId()
  const queuedMutation: QueuedMutation = {
    id,
    ...mutation,
    status: 'pending',
    retries: 0,
    created_at: Date.now()
  }

  try {
    await db.queuedMutations.add(queuedMutation)
    return id
  } catch (error) {
    console.error('[QueueManager] Failed to enqueue mutation:', error)
    throw error
  }
}

/**
 * Get pending mutations (status: pending or failed)
 */
export async function getPendingMutations(): Promise<QueuedMutation[]> {
  try {
    const mutations = await db.queuedMutations
      .where('status')
      .anyOf(['pending', 'failed', 'syncing'])
      .sortBy('created_at')

    return mutations as QueuedMutation[]
  } catch (error) {
    console.error('[QueueManager] Failed to get pending mutations:', error)
    return []
  }
}

/**
 * Get a specific mutation by ID
 */
export async function getMutation(id: string): Promise<QueuedMutation | undefined> {
  try {
    const mutation = await db.queuedMutations.get(id)
    return mutation as QueuedMutation | undefined
  } catch (error) {
    console.error('[QueueManager] Failed to get mutation:', error)
    return undefined
  }
}

/**
 * Update mutation status
 */
export async function updateMutationStatus(
  id: string,
  status: MutationStatus,
  error?: string
): Promise<void> {
  try {
    await db.queuedMutations.update(id, {
      status,
      ...(error && { error })
    })
  } catch (error) {
    console.error('[QueueManager] Failed to update mutation status:', error)
    throw error
  }
}

/**
 * Increment retry count for a mutation
 */
export async function incrementRetry(id: string): Promise<void> {
  try {
    const mutation = await db.queuedMutations.get(id)
    if (mutation) {
      await db.queuedMutations.update(id, {
        retries: (mutation.retries || 0) + 1
      })
    }
  } catch (error) {
    console.error('[QueueManager] Failed to increment retry:', error)
    throw error
  }
}

/**
 * Dequeue a mutation after successful sync
 */
export async function dequeueMutation(id: string): Promise<void> {
  try {
    await db.queuedMutations.delete(id)
  } catch (error) {
    console.error('[QueueManager] Failed to dequeue mutation:', error)
    throw error
  }
}

/**
 * Get current queue size
 */
export async function getQueueSize(): Promise<number> {
  try {
    return await db.queuedMutations.count()
  } catch (error) {
    console.error('[QueueManager] Failed to get queue size:', error)
    return 0
  }
}

/**
 * Clear all mutations (use with caution)
 */
export async function clearQueue(): Promise<void> {
  try {
    await db.queuedMutations.clear()
  } catch (error) {
    console.error('[QueueManager] Failed to clear queue:', error)
    throw error
  }
}

/**
 * Get queue statistics
 */
export async function getQueueStats(): Promise<{
  total: number
  pending: number
  syncing: number
  synced: number
  failed: number
}> {
  try {
    const total = await db.queuedMutations.count()
    const pending = await db.queuedMutations.where('status').equals('pending').count()
    const syncing = await db.queuedMutations.where('status').equals('syncing').count()
    const synced = await db.queuedMutations.where('status').equals('synced').count()
    const failed = await db.queuedMutations.where('status').equals('failed').count()

    return {
      total,
      pending,
      syncing,
      synced,
      failed
    }
  } catch (error) {
    console.error('[QueueManager] Failed to get queue stats:', error)
    return {
      total: 0,
      pending: 0,
      syncing: 0,
      synced: 0,
      failed: 0
    }
  }
}

