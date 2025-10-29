/**
 * React Query hooks for recurring transaction mutations
 */

import { useApiMutation } from './useApi'
import { createRecurringTransaction, updateRecurringTransaction } from '../api/resources/recurring'
import type { RecurringTransaction } from '../types/models'
import type { RecurringTransactionCreateParams, RecurringTransactionUpdateParams } from '../api/resources/recurring'

/**
 * Create a new recurring transaction
 */
export function useCreateRecurringTransaction() {
  return useApiMutation<RecurringTransaction, RecurringTransactionCreateParams>(
    (params) => createRecurringTransaction(params),
    {
      onSuccess: () => {
        // Invalidates recurring transactions list
      }
    }
  )
}

/**
 * Update an existing recurring transaction
 */
export function useUpdateRecurringTransaction() {
  return useApiMutation<RecurringTransaction, { id: number; params: RecurringTransactionUpdateParams }>(
    ({ id, params }) => updateRecurringTransaction(id, params),
    {
      onSuccess: () => {
        // Invalidates recurring transactions list
      }
    }
  )
}

