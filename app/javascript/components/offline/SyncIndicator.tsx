/**
 * Sync Indicator
 * Floating indicator showing sync progress during background sync
 */

import React from 'react'
import { useOfflineContext } from '../../providers/OfflineProvider'

export function SyncIndicator(): React.JSX.Element | null {
  const { state } = useOfflineContext()
  const { syncProgress, isOnline } = state

  // Only show when syncing and online
  if (!syncProgress || !syncProgress.inProgress || !isOnline) {
    return null
  }

  return (
    <div className="fixed bottom-4 right-4 z-50 w-72 rounded-lg bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 shadow-lg p-4">
      <div className="flex items-center gap-3">
        <div className="flex-shrink-0">
          <svg
            className="animate-spin h-5 w-5 text-primary-600 dark:text-primary-400"
            xmlns="http://www.w3.org/2000/svg"
            fill="none"
            viewBox="0 0 24 24"
          >
            <circle
              className="opacity-25"
              cx="12"
              cy="12"
              r="10"
              stroke="currentColor"
              strokeWidth="4"
            />
            <path
              className="opacity-75"
              fill="currentColor"
              d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
            />
          </svg>
        </div>
        <div className="flex-1 min-w-0">
          <p className="text-sm font-medium text-gray-900 dark:text-white">
            Syncing mutations...
          </p>
          <div className="mt-1 flex items-center gap-2">
            <div className="flex-1 h-2 bg-gray-200 dark:bg-gray-700 rounded-full overflow-hidden">
              <div
                className="h-full bg-primary-600 dark:bg-primary-500 transition-all duration-300"
                style={{ width: `${syncProgress.percentage}%` }}
              />
            </div>
            <span className="text-xs text-gray-600 dark:text-gray-400">
              {syncProgress.percentage}%
            </span>
          </div>
          <p className="mt-1 text-xs text-gray-500 dark:text-gray-400">
            {syncProgress.synced} of {syncProgress.total} synced
            {syncProgress.failed > 0 && `, ${syncProgress.failed} failed`}
          </p>
        </div>
      </div>
    </div>
  )
}

