/**
 * Recurring Transaction Table Component
 * Displays recurring transactions in a sortable table (desktop) or card layout (mobile)
 */

import React, { useState, useMemo } from 'react'
import { QueryProvider } from '../../providers/QueryProvider'
import { ErrorBoundary } from '../shared/ErrorBoundary'
import { useRecurringTransactions, useToggleRecurringActive, useDeleteRecurringTransaction } from '../../hooks/useRecurringTransactions'
import { useResponsive } from '../../hooks/useResponsive'

interface RecurringTransactionTableProps {
  // Props can be passed from ERB view if needed
}

type SortColumn = 'description' | 'amount' | 'frequency' | 'next_occurrence' | 'status'
type SortDirection = 'asc' | 'desc'

function RecurringTransactionTableContent({}: RecurringTransactionTableProps): React.JSX.Element {
  const { data, isLoading, error } = useRecurringTransactions()
  const toggleActive = useToggleRecurringActive()
  const deleteRecurring = useDeleteRecurringTransaction()
  const [sortColumn, setSortColumn] = useState<SortColumn>('next_occurrence')
  const [sortDirection, setSortDirection] = useState<SortDirection>('asc')
  const { isMobile } = useResponsive()

  const recurringTransactions = data?.data?.recurring_transactions || []

  // Sort transactions client-side
  const sortedTransactions = useMemo(() => {
    const sorted = [...recurringTransactions].sort((a, b) => {
      let aVal: string | number | boolean
      let bVal: string | number | boolean

      switch (sortColumn) {
        case 'description':
          aVal = a.description.toLowerCase()
          bVal = b.description.toLowerCase()
          break
        case 'amount':
          aVal = a.amount
          bVal = b.amount
          break
        case 'frequency':
          aVal = a.frequency
          bVal = b.frequency
          break
        case 'next_occurrence':
          aVal = new Date(a.next_occurrence_date).getTime()
          bVal = new Date(b.next_occurrence_date).getTime()
          break
        case 'status':
          aVal = a.is_active
          bVal = b.is_active
          break
        default:
          return 0
      }

      if (aVal < bVal) return sortDirection === 'asc' ? -1 : 1
      if (aVal > bVal) return sortDirection === 'asc' ? 1 : -1
      return 0
    })
    return sorted
  }, [recurringTransactions, sortColumn, sortDirection])

  const handleSort = (column: SortColumn) => {
    if (sortColumn === column) {
      setSortDirection(sortDirection === 'asc' ? 'desc' : 'asc')
    } else {
      setSortColumn(column)
      setSortDirection('asc')
    }
  }

  const handleToggleActive = async (id: number) => {
    try {
      await toggleActive.mutateAsync(id)
    } catch (error) {
      console.error('Failed to toggle active status:', error)
    }
  }

  const handleDelete = async (id: number) => {
    if (!confirm('Delete this recurring pattern? All future projected transactions will be removed.')) {
      return
    }
    try {
      await deleteRecurring.mutateAsync(id)
    } catch (error) {
      console.error('Failed to delete recurring transaction:', error)
    }
  }

  const formatAmount = (amount: number): string => {
    const sign = amount < 0 ? '-' : '+'
    return `${sign}$${Math.abs(amount).toFixed(2)}`
  }

  const formatFrequency = (frequency: string): string => {
    return frequency.charAt(0).toUpperCase() + frequency.slice(1)
  }

  const SortIcon = ({ column }: { column: SortColumn }): React.JSX.Element | null => {
    if (sortColumn !== column) return null
    return (
      <svg
        className={`w-4 h-4 ml-1 ${sortDirection === 'asc' ? '' : 'transform rotate-180'}`}
        fill="none"
        stroke="currentColor"
        viewBox="0 0 24 24"
      >
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M5 15l7-7 7 7" />
      </svg>
    )
  }

  if (isLoading) {
    return (
      <div className="px-6 py-12 text-center">
        <div className="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600"></div>
        <p className="mt-2 text-sm text-gray-500 dark:text-gray-400">Loading recurring transactions...</p>
      </div>
    )
  }

  if (error) {
    return (
      <div className="px-6 py-12 text-center">
        <p className="text-sm text-red-600 dark:text-red-400">Error loading recurring transactions</p>
      </div>
    )
  }

  if (sortedTransactions.length === 0) {
    return (
      <div className="px-6 py-12 text-center">
        <svg className="mx-auto h-12 w-12 text-gray-400 dark:text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"></path>
        </svg>
        <h3 className="mt-2 text-sm font-medium text-gray-900 dark:text-white">No recurring patterns</h3>
        <p className="mt-1 text-sm text-gray-500 dark:text-gray-400">Mark transactions as recurring to see them here.</p>
      </div>
    )
  }

  // Mobile card layout
  if (isMobile) {
    return (
      <div className="divide-y divide-gray-200 dark:divide-gray-700">
        {sortedTransactions.map((recurring) => (
          <div
            key={recurring.id}
            className={`p-4 ${
              !recurring.is_active ? 'bg-gray-100 dark:bg-gray-700 opacity-60' : ''
            } hover:bg-gray-50 dark:hover:bg-gray-700`}
          >
            <div className="flex items-start justify-between mb-2">
              <div className="flex-1">
                <p className="text-sm font-medium text-gray-900 dark:text-white">
                  {recurring.description}
                </p>
                {recurring.merchant_pattern && (
                  <p className="text-xs text-gray-500 dark:text-gray-400 mt-1">
                    Pattern: &quot;{recurring.merchant_pattern}&quot; (±${recurring.amount_tolerance || 0})
                  </p>
                )}
              </div>
              <span
                className={`text-sm font-medium ${
                  recurring.amount < 0
                    ? 'text-red-600 dark:text-red-400'
                    : 'text-green-600 dark:text-green-400'
                }`}
              >
                {formatAmount(recurring.amount)}
              </span>
            </div>
            <div className="flex items-center justify-between mt-3">
              <div className="flex items-center gap-2 flex-wrap">
                <span className="text-xs text-gray-500 dark:text-gray-400">
                  {formatFrequency(recurring.frequency)}
                </span>
                <span className="text-xs text-gray-500 dark:text-gray-400">
                  Next: {new Date(recurring.next_occurrence_date).toLocaleDateString('en-US', {
                    month: 'short',
                    day: 'numeric',
                    year: 'numeric'
                  })}
                </span>
                {recurring.is_active ? (
                  <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                    Active
                  </span>
                ) : (
                  <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-600">
                    Paused
                  </span>
                )}
              </div>
              <div className="flex gap-2">
                <button
                  onClick={() => handleToggleActive(recurring.id)}
                  disabled={toggleActive.isPending}
                  className="inline-flex items-center px-3 py-1 bg-yellow-100 text-yellow-700 rounded-lg hover:bg-yellow-200 hover:shadow-md transition-all text-xs font-medium disabled:opacity-50"
                >
                  {recurring.is_active ? 'Pause' : 'Resume'}
                </button>
                <button
                  onClick={() => handleDelete(recurring.id)}
                  disabled={deleteRecurring.isPending}
                  className="inline-flex items-center px-3 py-1 bg-red-100 text-red-700 rounded-lg hover:bg-red-200 hover:shadow-md transition-all text-xs font-medium disabled:opacity-50"
                >
                  Delete
                </button>
              </div>
            </div>
          </div>
        ))}
      </div>
    )
  }

  // Desktop table layout
  return (
    <div className="overflow-x-auto">
      <table className="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
        <thead className="bg-gray-50 dark:bg-gray-900">
          <tr>
            <th
              className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider cursor-pointer hover:bg-gray-100 dark:hover:bg-gray-800"
              onClick={() => handleSort('description')}
            >
              <div className="flex items-center">
                Description
                <SortIcon column="description" />
              </div>
            </th>
            <th
              className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider cursor-pointer hover:bg-gray-100 dark:hover:bg-gray-800"
              onClick={() => handleSort('amount')}
            >
              <div className="flex items-center">
                Amount
                <SortIcon column="amount" />
              </div>
            </th>
            <th
              className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider cursor-pointer hover:bg-gray-100 dark:hover:bg-gray-800"
              onClick={() => handleSort('frequency')}
            >
              <div className="flex items-center">
                Frequency
                <SortIcon column="frequency" />
              </div>
            </th>
            <th
              className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider cursor-pointer hover:bg-gray-100 dark:hover:bg-gray-800"
              onClick={() => handleSort('next_occurrence')}
            >
              <div className="flex items-center">
                Next Occurrence
                <SortIcon column="next_occurrence" />
              </div>
            </th>
            <th
              className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider cursor-pointer hover:bg-gray-100 dark:hover:bg-gray-800"
              onClick={() => handleSort('status')}
            >
              <div className="flex items-center">
                Status
                <SortIcon column="status" />
              </div>
            </th>
            <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
              Actions
            </th>
          </tr>
        </thead>
        <tbody className="bg-white dark:bg-gray-800 divide-y divide-gray-200 dark:divide-gray-700">
          {sortedTransactions.map((recurring) => (
            <tr
              key={recurring.id}
              className={`hover:bg-gray-50 dark:hover:bg-gray-700 ${
                !recurring.is_active ? 'bg-gray-100 dark:bg-gray-700 opacity-60' : ''
              }`}
            >
              <td className="px-6 py-4 text-sm text-gray-900 dark:text-gray-300">
                {recurring.description}
                {recurring.merchant_pattern && (
                  <div className="text-xs text-gray-500 dark:text-gray-400 mt-1">
                    Pattern: &quot;{recurring.merchant_pattern}&quot; (±${recurring.amount_tolerance || 0})
                  </div>
                )}
              </td>
              <td
                className={`px-6 py-4 whitespace-nowrap text-sm font-medium ${
                  recurring.amount < 0 ? 'text-red-600 dark:text-red-400' : 'text-green-600 dark:text-green-400'
                }`}
              >
                {formatAmount(recurring.amount)}
              </td>
              <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500 dark:text-gray-400">
                {formatFrequency(recurring.frequency)}
              </td>
              <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500 dark:text-gray-400">
                {new Date(recurring.next_occurrence_date).toLocaleDateString('en-US', {
                  month: 'short',
                  day: 'numeric',
                  year: 'numeric'
                })}
              </td>
              <td className="px-6 py-4 whitespace-nowrap">
                {recurring.is_active ? (
                  <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                    Active
                  </span>
                ) : (
                  <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-600">
                    Paused
                  </span>
                )}
              </td>
              <td className="px-6 py-4 whitespace-nowrap text-sm text-right">
                <div className="flex gap-2 justify-end">
                  <button
                    onClick={() => handleToggleActive(recurring.id)}
                    disabled={toggleActive.isPending}
                    className="inline-flex items-center px-3 py-1 bg-yellow-100 text-yellow-700 rounded-lg hover:bg-yellow-200 hover:shadow-md hover:scale-105 transition-all text-xs font-medium disabled:opacity-50"
                  >
                    <svg className="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M10 9v6m4-6v6m7-3a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                    </svg>
                    {recurring.is_active ? 'Pause' : 'Resume'}
                  </button>
                  <button
                    onClick={() => handleDelete(recurring.id)}
                    disabled={deleteRecurring.isPending}
                    className="inline-flex items-center px-3 py-1 bg-red-100 text-red-700 rounded-lg hover:bg-red-200 hover:shadow-md hover:scale-105 transition-all text-xs font-medium disabled:opacity-50"
                  >
                    <svg className="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"></path>
                    </svg>
                    Delete
                  </button>
                </div>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}

export default function RecurringTransactionTable(props: RecurringTransactionTableProps): React.JSX.Element {
  return (
    <ErrorBoundary>
      <QueryProvider>
        <RecurringTransactionTableContent {...props} />
      </QueryProvider>
    </ErrorBoundary>
  )
}

