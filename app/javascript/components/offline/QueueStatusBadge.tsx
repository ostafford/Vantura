/**
 * Queue Status Badge
 * Shows pending mutations count in navigation bar
 * Click to open queue details modal
 */

import React, { useState } from 'react'
import { useOfflineContext } from '../../providers/OfflineProvider'
import { QueueDetailsModal } from './QueueDetailsModal'

export function QueueStatusBadge(): React.JSX.Element | null {
  const { state } = useOfflineContext()
  const [showModal, setShowModal] = useState(false)

  const { pending, failed } = state.queueState

  // Don't show if no pending or failed mutations
  if (pending === 0 && failed === 0) {
    return null
  }

  const total = pending + failed

  return (
    <>
      <button
        onClick={() => setShowModal(true)}
        className="relative flex items-center gap-2 px-3 py-2 text-sm font-medium text-gray-700 dark:text-gray-300 bg-white dark:bg-gray-800 border border-gray-300 dark:border-gray-700 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors"
        title={`${pending} pending, ${failed} failed mutations`}
      >
        <svg
          className="w-4 h-4"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
          xmlns="http://www.w3.org/2000/svg"
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"
          />
        </svg>
        <span className="hidden md:inline">{total} pending</span>
        {failed > 0 && (
          <span className="absolute -top-1 -right-1 flex h-5 w-5 items-center justify-center rounded-full bg-red-500 text-xs font-bold text-white">
            {failed}
          </span>
        )}
      </button>

      {showModal && <QueueDetailsModal onClose={() => setShowModal(false)} />}
    </>
  )
}

