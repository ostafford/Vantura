/**
 * Recurring Transaction Table Component
 * Displays recurring transactions in a sortable table (desktop) or card layout (mobile)
 */

import React from 'react'
import { QueryProvider } from '../../providers/QueryProvider'
import { ErrorBoundary } from '../shared/ErrorBoundary'
import { useRecurringTransactions, useToggleRecurringActive, useDeleteRecurringTransaction } from '../../hooks/useRecurringTransactions'
import { ResponsiveTable, type Column } from '../shared/ResponsiveTable'
import useTableSort from '../../hooks/useTableSort'
import { formatAmount, formatDate } from '../../utils/formatting'

interface RecurringTransactionTableProps {
  // Props can be passed from ERB view if needed
}

function RecurringTransactionTableContent({}: RecurringTransactionTableProps): React.JSX.Element {
  const { data, isLoading, error } = useRecurringTransactions()
  const toggleActive = useToggleRecurringActive()
  const deleteRecurring = useDeleteRecurringTransaction()

  const recurringTransactions = data?.data?.recurring_transactions || []

  const { sortedRows: sortedTransactions, sortState, sortBy } = useTableSort<any>({
    rows: recurringTransactions,
    defaultSort: { key: 'next_occurrence_date', direction: 'asc' },
    accessor: (row, key) => {
      if (key === 'next_occurrence_date') return new Date(row.next_occurrence_date)
      return (row as any)[key]
    }
  })

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

  const formatFrequency = (frequency: string): string => {
    return frequency.charAt(0).toUpperCase() + frequency.slice(1)
  }

  const SortIcon = ({ column }: { column: keyof any }): React.JSX.Element | null => {
    if (sortState.key !== column) return null
    return (
      <svg
        className={`w-4 h-4 ml-1 ${sortState.direction === 'asc' ? '' : 'transform rotate-180'}`}
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

  const columns: readonly Column<any>[] = [
    { id: 'description', header: 'Description', sortable: true },
    { id: 'amount', header: 'Amount', sortable: true },
    { id: 'frequency', header: 'Frequency', sortable: true },
    { id: 'next_occurrence_date', header: 'Next Occurrence', sortable: true, accessor: (r) => new Date(r.next_occurrence_date) },
    { id: 'is_active', header: 'Status', sortable: true },
    { id: 'id', header: 'Actions' }
  ]

  return (
    <div className="overflow-x-auto">
      <ResponsiveTable<any>
        ariaLabel="Recurring Transactions"
        columns={columns}
        rows={sortedTransactions}
        getRowId={(row) => String(row.id)}
        rowClassName={(row) => `${!row.is_active ? 'bg-gray-100 dark:bg-gray-700 opacity-60' : ''}`}
        sortState={{ key: sortState.key, direction: sortState.direction }}
        onSortChange={(key) => sortBy(key)}
        renderCell={(row, col) => {
          if (col.id === 'amount') {
            const cls = row.amount < 0 ? 'text-red-600 dark:text-red-400' : 'text-green-600 dark:text-green-400'
            return <span className={`font-medium ${cls}`}>{formatAmount(row.amount)}</span>
          }
          if (col.id === 'frequency') return formatFrequency(row.frequency)
          if (col.id === 'next_occurrence_date') return formatDate(row.next_occurrence_date)
          if (col.id === 'is_active') {
            return row.is_active ? (
              <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">Active</span>
            ) : (
              <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-600">Paused</span>
            )
          }
          if (col.id === 'id') {
            return (
              <div className="flex gap-2 justify-end">
                <button
                  onClick={() => handleToggleActive(row.id)}
                  disabled={toggleActive.isPending}
                  className="inline-flex items-center px-3 py-1 bg-yellow-100 text-yellow-700 rounded-lg hover:bg-yellow-200 hover:shadow-md hover:scale-105 transition-all text-xs font-medium disabled:opacity-50"
                >
                  {row.is_active ? 'Pause' : 'Resume'}
                </button>
                <button
                  onClick={() => handleDelete(row.id)}
                  disabled={deleteRecurring.isPending}
                  className="inline-flex items-center px-3 py-1 bg-red-100 text-red-700 rounded-lg hover:bg-red-200 hover:shadow-md hover:scale-105 transition-all text-xs font-medium disabled:opacity-50"
                >
                  Delete
                </button>
              </div>
            )
          }
          return (row as any)[col.id]
        }}
      />
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

