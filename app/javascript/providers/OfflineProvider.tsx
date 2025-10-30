/**
 * Offline Provider
 * Provides offline state and queue status context to all React components
 */

import React, { createContext, useContext, useEffect, useState, useCallback } from 'react'
import type { OfflineState, SyncProgress, QueueState } from '../types/offline'
import { getQueueSize, getPendingMutations } from '../offline/queue-manager'

interface OfflineContextType {
  state: OfflineState
  refreshQueueState: () => Promise<void>
}

const OfflineContext = createContext<OfflineContextType | undefined>(undefined)

interface OfflineProviderProps {
  children: React.ReactNode
}

/**
 * OfflineProvider component - provides offline state context
 */
export function OfflineProvider({ children }: OfflineProviderProps): React.JSX.Element {
  const [isOnline, setIsOnline] = useState(navigator.onLine)
  const [queueState, setQueueState] = useState<QueueState>({
    pending: 0,
    syncing: 0,
    failed: 0,
    total: 0
  })
  const [syncProgress, setSyncProgress] = useState<SyncProgress | null>(null)

  // Refresh queue state from IndexedDB
  const refreshQueueState = useCallback(async (): Promise<void> => {
    try {
      const queueSize = await getQueueSize()
      const pending = await getPendingMutations()

      const syncing = pending.filter((m) => m.status === 'syncing').length
      const failed = pending.filter((m) => m.status === 'failed').length
      const pendingCount = pending.filter((m) => m.status === 'pending').length

      setQueueState({
        pending: pendingCount,
        syncing: syncing,
        failed: failed,
        total: queueSize
      })
    } catch (error) {
      console.error('[OfflineProvider] Failed to refresh queue state:', error)
    }
  }, [])

  // Listen for online/offline events
  useEffect(() => {
    const handleOnline = (): void => {
      setIsOnline(true)
      void refreshQueueState()
    }

    const handleOffline = (): void => {
      setIsOnline(false)
      void refreshQueueState()
    }

    window.addEventListener('online', handleOnline)
    window.addEventListener('offline', handleOffline)

    // Initial state refresh
    void refreshQueueState()

    // Poll for queue state changes every 2 seconds
    const interval = setInterval(() => {
      void refreshQueueState()
    }, 2000)

    return () => {
      window.removeEventListener('online', handleOnline)
      window.removeEventListener('offline', handleOffline)
      clearInterval(interval)
    }
  }, [refreshQueueState])

  const state: OfflineState = {
    isOnline,
    queueState,
    syncProgress
  }

  // Update sync progress callback (will be set by sync service)
  useEffect(() => {
    const handleSyncProgress = ((event: CustomEvent<SyncProgress>) => {
      setSyncProgress(event.detail)
      // Clear progress when sync completes
      if (event.detail.inProgress === false && event.detail.failed === 0) {
        setTimeout(() => {
          setSyncProgress(null)
        }, 2000)
      }
      void refreshQueueState()
    }) as EventListener

    window.addEventListener('sync-progress', handleSyncProgress as EventListener)

    return () => {
      window.removeEventListener('sync-progress', handleSyncProgress as EventListener)
    }
  }, [refreshQueueState])

  return (
    <OfflineContext.Provider value={{ state, refreshQueueState }}>
      {children}
    </OfflineContext.Provider>
  )
}

/**
 * Hook to access offline context
 */
export function useOfflineContext(): OfflineContextType {
  const context = useContext(OfflineContext)
  if (context === undefined) {
    throw new Error('useOfflineContext must be used within an OfflineProvider')
  }
  return context
}

