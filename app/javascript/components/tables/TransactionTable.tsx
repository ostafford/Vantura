/**
 * Transaction Table Component
 * Displays transactions in a sortable table (desktop) or card layout (mobile)
 */

import React from 'react'
import { QueryProvider } from '../../providers/QueryProvider'
import { ErrorBoundary } from '../shared/ErrorBoundary'
import { useTransactions } from '../../hooks/useTransactions'
import type { Transaction } from '../../types/models'
import { ResponsiveTable, type Column } from '../shared/ResponsiveTable'
import useTableSort from '../../hooks/useTableSort'
import { formatAmount, formatDate } from '../../utils/formatting'

interface TransactionTableProps {
  year?: number
  month?: number
  filterType?: 'all' | 'expenses' | 'income' | 'hypothetical'
  initialTransactions?: Transaction[]
}

function TransactionTableContent({
  year,
  month,
  filterType = 'all',
  initialTransactions
}: TransactionTableProps): React.JSX.Element {
  const { data, isLoading, error } = useTransactions({ year, month, filterType })

  const transactions = data?.data?.transactions || initialTransactions || []
  const meta = data?.meta

  const { sortedRows: sortedTransactions, sortState, sortBy } = useTableSort<Transaction>({
    rows: transactions,
    defaultSort: { key: 'transaction_date', direction: 'desc' },
    accessor: (row, key) => {
      if (key === 'transaction_date') return new Date(row.transaction_date)
      if (key === 'category') return row.category || 'Uncategorized'
      return (row as any)[key]
    }
  })

  const getStatusBadge = (transaction: Transaction): React.JSX.Element => {
    if (transaction.is_hypothetical) {
      return (
        <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-info-100 dark:bg-info-900/30 text-info-800 dark:text-info-300">
          Hypothetical
        </span>
      )
    } else if (transaction.status === 'HELD') {
      return (
        <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-warning-100 dark:bg-warning-900/30 text-warning-800 dark:text-warning-300">
          Pending
        </span>
      )
    } else {
      return (
        <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-success-100 dark:bg-success-900/30 text-success-800 dark:text-success-300">
          Settled
        </span>
      )
    }
  }

  const SortIcon = ({ column }: { column: keyof Transaction }): React.JSX.Element | null => {
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
        <p className="mt-2 text-sm text-gray-500 dark:text-gray-400">Loading transactions...</p>
      </div>
    )
  }

  if (error) {
    return (
      <div className="px-6 py-12 text-center">
        <p className="text-sm text-red-600 dark:text-red-400">Error loading transactions</p>
      </div>
    )
  }

  if (sortedTransactions.length === 0) {
    return (
      <div className="px-6 py-12 text-center">
        <svg className="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path>
        </svg>
        <h3 className="mt-2 text-sm font-medium text-gray-900 dark:text-white">No transactions</h3>
        <p className="mt-1 text-sm text-gray-500 dark:text-gray-400">No transactions found for the selected filter.</p>
      </div>
    )
  }

  const columns: readonly Column<Transaction>[] = [
    { id: 'transaction_date', header: 'Date', sortable: true, accessor: (r) => new Date(r.transaction_date) },
    { id: 'description', header: 'Description', sortable: true },
    { id: 'category', header: 'Category', sortable: true, accessor: (r) => (r.category || 'Uncategorized').replace(/_/g, ' ') },
    { id: 'status', header: 'Status' },
    { id: 'amount', header: 'Amount', sortable: true },
    { id: 'id', header: 'Actions' }
  ]

  return (
    <div className="overflow-x-auto">
      <ResponsiveTable<Transaction>
        ariaLabel="Transactions"
        columns={columns}
        rows={sortedTransactions}
        getRowId={(row) => String(row.id)}
        rowClassName={(row) => `${row.is_hypothetical ? 'bg-purple-50 dark:bg-purple-900/20' : ''}`}
        sortState={{ key: sortState.key, direction: sortState.direction }}
        onSortChange={(key) => sortBy(key)}
        renderCell={(row, col) => {
          if (col.id === 'transaction_date') return formatDate(row.transaction_date)
          if (col.id === 'category') return (row.category || 'Uncategorized').replace(/_/g, ' ')
          if (col.id === 'status') return getStatusBadge(row)
          if (col.id === 'amount') {
            const cls = row.amount < 0 ? 'text-expense-600 dark:text-expense-400' : 'text-income-600 dark:text-income-400'
            return <span className={`font-medium ${cls}`}>{formatAmount(row.amount)}</span>
          }
          if (col.id === 'id') return <span className="text-right block" />
          return (row as any)[col.id]
        }}
      />
      {meta?.pagination && (
        <div className="px-6 py-4 border-t border-gray-200 dark:border-gray-700">
          <p className="text-sm text-gray-500 dark:text-gray-400">
            Page {meta.pagination.page} of {meta.pagination.total_pages} ({meta.pagination.total} total)
          </p>
        </div>
      )}
    </div>
  )
}

export default function TransactionTable(props: TransactionTableProps): React.JSX.Element {
  return (
    <ErrorBoundary>
      <QueryProvider>
        <TransactionTableContent {...props} />
      </QueryProvider>
    </ErrorBoundary>
  )
}

