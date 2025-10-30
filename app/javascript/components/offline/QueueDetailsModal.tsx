/**
 * Queue Details Modal
 * Shows list of queued mutations with retry options
 */

import React, { useEffect, useState } from 'react'
import { getPendingMutations, updateMutationStatus } from '../../offline/queue-manager'
import { syncQueuedMutations } from '../../offline/sync-service'
import type { QueuedMutation } from '../../types/offline'
import { useOfflineContext } from '../../providers/OfflineProvider'

interface QueueDetailsModalProps {
  onClose: () => void
}

export function QueueDetailsModal({ onClose }: QueueDetailsModalProps): React.JSX.Element {
  const [mutations, setMutations] = useState<QueuedMutation[]>([])
  const [loading, setLoading] = useState(true)
  const { refreshQueueState, state } = useOfflineContext()

  useEffect(() => {
    void loadMutations()
  }, [])

  const loadMutations = async (): Promise<void> => {
    setLoading(true)
    try {
      const pending = await getPendingMutations()
      setMutations(pending)
    } catch (error) {
      console.error('[QueueDetailsModal] Failed to load mutations:', error)
    } finally {
      setLoading(false)
    }
  }

  const handleRetry = async (mutationId: string): Promise<void> => {
    try {
      await updateMutationStatus(mutationId, 'pending')
      await loadMutations()
      void refreshQueueState()
    } catch (error) {
      console.error('[QueueDetailsModal] Failed to retry mutation:', error)
    }
  }

  const handleRetryAll = async (): Promise<void> => {
    // Reset all failed mutations to pending
    const failed = mutations.filter((m) => m.status === 'failed')
    await Promise.all(
      failed.map((m) => updateMutationStatus(m.id, 'pending'))
    )
    await loadMutations()
    void refreshQueueState()

    // Trigger sync
    if (state.isOnline) {
      void syncQueuedMutations()
    }
  }

  const handleManualSync = async (): Promise<void> => {
    if (state.isOnline) {
      await syncQueuedMutations()
      await loadMutations()
      void refreshQueueState()
    }
  }

  const failedMutations = mutations.filter((m) => m.status === 'failed')
  const pendingMutations = mutations.filter((m) => m.status === 'pending')
  const syncingMutations = mutations.filter((m) => m.status === 'syncing')

  return (
    <div
      className="fixed inset-0 z-50 overflow-y-auto"
      onClick={onClose}
      role="dialog"
      aria-modal="true"
      aria-labelledby="queue-modal-title"
    >
      <div className="flex min-h-full items-center justify-center p-4">
        <div
          className="relative w-full max-w-2xl rounded-lg bg-white dark:bg-gray-800 shadow-xl"
          onClick={(e) => e.stopPropagation()}
        >
          {/* Header */}
          <div className="flex items-center justify-between border-b border-gray-200 dark:border-gray-700 px-6 py-4">
            <h2
              id="queue-modal-title"
              className="text-lg font-semibold text-gray-900 dark:text-white"
            >
              Mutation Queue
            </h2>
            <button
              onClick={onClose}
              className="text-gray-400 hover:text-gray-500 dark:hover:text-gray-300"
              aria-label="Close"
            >
              <svg className="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M6 18L18 6M6 6l12 12"
                />
              </svg>
            </button>
          </div>

          {/* Actions */}
          <div className="border-b border-gray-200 dark:border-gray-700 px-6 py-3 flex items-center justify-between gap-3">
            <div className="text-sm text-gray-600 dark:text-gray-400">
              {mutations.length} total: {pendingMutations.length} pending,{' '}
              {syncingMutations.length} syncing, {failedMutations.length} failed
            </div>
            <div className="flex gap-2">
              {failedMutations.length > 0 && (
                <button
                  onClick={handleRetryAll}
                  className="px-3 py-1.5 text-sm font-medium text-white bg-primary-600 hover:bg-primary-700 rounded-lg transition-colors"
                >
                  Retry All Failed
                </button>
              )}
              {state.isOnline && mutations.length > 0 && (
                <button
                  onClick={handleManualSync}
                  className="px-3 py-1.5 text-sm font-medium text-white bg-primary-600 hover:bg-primary-700 rounded-lg transition-colors"
                >
                  Sync Now
                </button>
              )}
            </div>
          </div>

          {/* Content */}
          <div className="px-6 py-4 max-h-96 overflow-y-auto">
            {loading ? (
              <div className="text-center py-8 text-gray-500 dark:text-gray-400">
                Loading...
              </div>
            ) : mutations.length === 0 ? (
              <div className="text-center py-8 text-gray-500 dark:text-gray-400">
                No pending mutations
              </div>
            ) : (
              <div className="space-y-2">
                {mutations.map((mutation) => (
                  <div
                    key={mutation.id}
                    className="flex items-center justify-between p-3 border border-gray-200 dark:border-gray-700 rounded-lg"
                  >
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2">
                        <span className="text-sm font-medium text-gray-900 dark:text-white">
                          {mutation.type.replace(/_/g, ' ')}
                        </span>
                        <span
                          className={`inline-flex items-center px-2 py-0.5 rounded text-xs font-medium ${
                            mutation.status === 'pending'
                              ? 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-200'
                              : mutation.status === 'syncing'
                              ? 'bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200'
                              : mutation.status === 'failed'
                              ? 'bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200'
                              : 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200'
                          }`}
                        >
                          {mutation.status}
                        </span>
                      </div>
                      <p className="mt-1 text-xs text-gray-500 dark:text-gray-400 truncate">
                        {mutation.url}
                      </p>
                      {mutation.error && (
                        <p className="mt-1 text-xs text-red-600 dark:text-red-400">
                          {mutation.error}
                        </p>
                      )}
                      {mutation.retries > 0 && (
                        <p className="mt-1 text-xs text-gray-500 dark:text-gray-400">
                          Retries: {mutation.retries}
                        </p>
                      )}
                    </div>
                    {mutation.status === 'failed' && (
                      <button
                        onClick={() => handleRetry(mutation.id)}
                        className="ml-3 px-3 py-1.5 text-sm font-medium text-primary-600 hover:text-primary-700 dark:text-primary-400 dark:hover:text-primary-300"
                      >
                        Retry
                      </button>
                    )}
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  )
}

