/**
 * useOffline Hook
 * Provides offline status and queue information
 */

import { useOfflineContext } from '../providers/OfflineProvider'

/**
 * Hook to access offline state
 */
export function useOffline() {
  const { state, refreshQueueState } = useOfflineContext()
  return {
    isOnline: state.isOnline,
    isOffline: !state.isOnline,
    queueState: state.queueState,
    syncProgress: state.syncProgress,
    refreshQueueState,
  }
}

