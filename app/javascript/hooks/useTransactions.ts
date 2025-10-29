/**
 * React Query hook for transactions data
 */

import { useApiQuery } from './useApi'
import { getTransactions, getTransactionsByMonth, type TransactionSearchParams } from '../api/resources/transactions'
import type { TransactionListResponse } from '../api/resources/transactions'

export interface UseTransactionsParams {
  year?: number
  month?: number
  filterType?: 'all' | 'expenses' | 'income' | 'hypothetical'
  page?: number
  perPage?: number
}

/**
 * Fetch transactions with React Query
 */
export function useTransactions(params?: UseTransactionsParams) {
  const queryParams: TransactionSearchParams = {
    filter: params?.filterType,
    page: params?.page,
    per_page: params?.perPage
  }

  const queryFn = params?.year && params?.month
    ? () => getTransactionsByMonth(params.year!, params.month!, queryParams)
    : () => getTransactions(queryParams)

  return useApiQuery<TransactionListResponse>(
    ['transactions', params?.year, params?.month, params?.filterType, params?.page],
    queryFn,
    {
      staleTime: 1000 * 60 * 2 // 2 minutes
    }
  )
}

