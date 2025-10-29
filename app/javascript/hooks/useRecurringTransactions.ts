/**
 * React Query hook for recurring transactions data
 */

import { useApiQuery, useApiMutation } from './useApi'
import { getRecurringTransactions, toggleRecurringTransactionActive, deleteRecurringTransaction } from '../api/resources/recurring'
import type { RecurringTransactionListResponse } from '../api/resources/recurring'
import type { RecurringTransaction } from '../types/models'

/**
 * Fetch recurring transactions with React Query
 */
export function useRecurringTransactions() {
  return useApiQuery<RecurringTransactionListResponse>(
    ['recurring-transactions'],
    () => getRecurringTransactions(),
    {
      staleTime: 1000 * 60 * 5 // 5 minutes
    }
  )
}

/**
 * Toggle active status of a recurring transaction
 */
export function useToggleRecurringActive() {
  return useApiMutation<{ recurring_transaction: RecurringTransaction; message: string }, number>(
    (id: number) => toggleRecurringTransactionActive(id),
    {
      onSuccess: () => {
        // Query will refetch automatically
      }
    }
  )
}

/**
 * Delete a recurring transaction
 */
export function useDeleteRecurringTransaction() {
  return useApiMutation<{ message: string }, number>(
    (id: number) => deleteRecurringTransaction(id),
    {
      onSuccess: () => {
        // Query will refetch automatically
      }
    }
  )
}

