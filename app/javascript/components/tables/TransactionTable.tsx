/**
 * Transaction Table Component
 * Displays transactions in a sortable table (desktop) or card layout (mobile)
 */

import React, { useState, useMemo } from 'react'
import { QueryProvider } from '../../providers/QueryProvider'
import { ErrorBoundary } from '../shared/ErrorBoundary'
import { useTransactions } from '../../hooks/useTransactions'
import { useResponsive } from '../../hooks/useResponsive'
import type { Transaction } from '../../types/models'

interface TransactionTableProps {
  year?: number
  month?: number
  filterType?: 'all' | 'expenses' | 'income' | 'hypothetical'
  initialTransactions?: Transaction[]
}

type SortColumn = 'date' | 'description' | 'category' | 'amount'
type SortDirection = 'asc' | 'desc'

function TransactionTableContent({
  year,
  month,
  filterType = 'all',
  initialTransactions
}: TransactionTableProps): React.JSX.Element {
  const { data, isLoading, error } = useTransactions({ year, month, filterType })
  const [sortColumn, setSortColumn] = useState<SortColumn>('date')
  const [sortDirection, setSortDirection] = useState<SortDirection>('desc')
  const { isMobile } = useResponsive()

  const transactions = data?.data?.transactions || initialTransactions || []
  const meta = data?.meta

  // Sort transactions client-side
  const sortedTransactions = useMemo(() => {
    const sorted = [...transactions].sort((a, b) => {
      let aVal: string | number
      let bVal: string | number

      switch (sortColumn) {
        case 'date':
          aVal = new Date(a.transaction_date).getTime()
          bVal = new Date(b.transaction_date).getTime()
          break
        case 'description':
          aVal = a.description.toLowerCase()
          bVal = b.description.toLowerCase()
          break
        case 'category':
          aVal = (a.category || 'Uncategorized').toLowerCase()
          bVal = (b.category || 'Uncategorized').toLowerCase()
          break
        case 'amount':
          aVal = a.amount
          bVal = b.amount
          break
        default:
          return 0
      }

      if (aVal < bVal) return sortDirection === 'asc' ? -1 : 1
      if (aVal > bVal) return sortDirection === 'asc' ? 1 : -1
      return 0
    })
    return sorted
  }, [transactions, sortColumn, sortDirection])

  const handleSort = (column: SortColumn) => {
    if (sortColumn === column) {
      setSortDirection(sortDirection === 'asc' ? 'desc' : 'asc')
    } else {
      setSortColumn(column)
      setSortDirection('desc')
    }
  }

  const formatAmount = (amount: number): string => {
    const sign = amount < 0 ? '-' : '+'
    return `${sign}$${Math.abs(amount).toFixed(2)}`
  }

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

  // Mobile card layout
  if (isMobile) {
    return (
      <div className="divide-y divide-gray-200 dark:divide-gray-700">
        {sortedTransactions.map((transaction) => (
          <div
            key={transaction.id}
            className={`p-4 ${
              transaction.is_hypothetical ? 'bg-purple-50 dark:bg-purple-900/20' : ''
            } hover:bg-gray-50 dark:hover:bg-gray-700`}
          >
            <div className="flex items-start justify-between mb-2">
              <div className="flex-1">
                <p className="text-sm font-medium text-gray-900 dark:text-white">
                  {transaction.description}
                </p>
                <p className="text-xs text-gray-500 dark:text-gray-400 mt-1">
                  {new Date(transaction.transaction_date).toLocaleDateString('en-US', {
                    month: 'short',
                    day: 'numeric',
                    year: 'numeric'
                  })}
                </p>
              </div>
              <span
                className={`text-sm font-medium ${
                  transaction.amount < 0
                    ? 'text-expense-600 dark:text-expense-400'
                    : 'text-income-600 dark:text-income-400'
                }`}
              >
                {formatAmount(transaction.amount)}
              </span>
            </div>
            <div className="flex items-center gap-2 flex-wrap">
              {transaction.category && (
                <span className="text-xs text-gray-500 dark:text-gray-400">
                  {(transaction.category || 'Uncategorized').replace(/_/g, ' ')}
                </span>
              )}
              {getStatusBadge(transaction)}
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
              onClick={() => handleSort('date')}
            >
              <div className="flex items-center">
                Date
                <SortIcon column="date" />
              </div>
            </th>
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
              onClick={() => handleSort('category')}
            >
              <div className="flex items-center">
                Category
                <SortIcon column="category" />
              </div>
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
              Status
            </th>
            <th
              className="px-6 py-3 text-right text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider cursor-pointer hover:bg-gray-100 dark:hover:bg-gray-800"
              onClick={() => handleSort('amount')}
            >
              <div className="flex items-center justify-end">
                Amount
                <SortIcon column="amount" />
              </div>
            </th>
            <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
              Actions
            </th>
          </tr>
        </thead>
        <tbody className="bg-white dark:bg-gray-800 divide-y divide-gray-200 dark:divide-gray-700">
          {sortedTransactions.map((transaction) => (
            <tr
              key={transaction.id}
              className={`hover:bg-gray-50 dark:hover:bg-gray-700 ${
                transaction.is_hypothetical ? 'bg-purple-50 dark:bg-purple-900/20' : ''
              }`}
            >
              <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900 dark:text-gray-300">
                {new Date(transaction.transaction_date).toLocaleDateString('en-US', {
                  month: 'short',
                  day: 'numeric',
                  year: 'numeric'
                })}
              </td>
              <td className="px-6 py-4 text-sm text-gray-900 dark:text-gray-300">
                {transaction.description}
              </td>
              <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500 dark:text-gray-400">
                {(transaction.category || 'Uncategorized').replace(/_/g, ' ')}
              </td>
              <td className="px-6 py-4 whitespace-nowrap">{getStatusBadge(transaction)}</td>
              <td
                className={`px-6 py-4 whitespace-nowrap text-sm text-right font-medium ${
                  transaction.amount < 0
                    ? 'text-expense-600 dark:text-expense-400'
                    : 'text-income-600 dark:text-income-400'
                }`}
              >
                {formatAmount(transaction.amount)}
              </td>
              <td className="px-6 py-4 whitespace-nowrap text-sm text-right">
                {/* Action buttons will be added via server-side rendering or another component */}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
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

