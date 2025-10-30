/**
 * useMutationQueue Hook
 * Provides operations for managing mutation queue
 */

import { useState, useCallback } from 'react'
import {
  getPendingMutations,
  getQueueSize,
  getQueueStats,
  clearQueue,
} from '../offline/queue-manager'
import { syncQueuedMutations } from '../offline/sync-service'
import type { QueuedMutation } from '../types/offline'

/**
 * Hook for mutation queue operations
 */
export function useMutationQueue() {
  const [loading, setLoading] = useState(false)

  const getPending = useCallback(async (): Promise<QueuedMutation[]> => {
    try {
      return await getPendingMutations()
    } catch (error) {
      console.error('[useMutationQueue] Failed to get pending mutations:', error)
      return []
    }
  }, [])

  const getSize = useCallback(async (): Promise<number> => {
    try {
      return await getQueueSize()
    } catch (error) {
      console.error('[useMutationQueue] Failed to get queue size:', error)
      return 0
    }
  }, [])

  const getStats = useCallback(async () => {
    try {
      return await getQueueStats()
    } catch (error) {
      console.error('[useMutationQueue] Failed to get queue stats:', error)
      return {
        total: 0,
        pending: 0,
        syncing: 0,
        synced: 0,
        failed: 0,
      }
    }
  }, [])

  const sync = useCallback(async (): Promise<void> => {
    if (!navigator.onLine) {
      throw new Error('Cannot sync: device is offline')
    }

    setLoading(true)
    try {
      await syncQueuedMutations()
    } finally {
      setLoading(false)
    }
  }, [])

  const clear = useCallback(async (): Promise<void> => {
    setLoading(true)
    try {
      await clearQueue()
    } finally {
      setLoading(false)
    }
  }, [])

  return {
    getPending,
    getSize,
    getStats,
    sync,
    clear,
    loading,
  }
}

