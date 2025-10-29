/**
 * Typed API functions for recurring transactions resource
 */

import { apiGet, apiPost, apiPatch, apiDelete } from '../client'
import { endpoints } from '../endpoints'
import type { RecurringTransaction } from '../../types/models'
import type { ApiResponse } from '../../types/api'

export interface RecurringTransactionListResponse {
  recurring_transactions: RecurringTransaction[]
  breakdowns: {
    week_income: number
    week_expenses: number
    month_income: number
    month_expenses: number
    next_occurrence_date: string | null
    next_occurrence_amount: number | null
    next_occurrence_desc: string | null
  }
}

export interface RecurringTransactionCreateParams {
  transaction_id?: number
  recurring_transaction?: {
    description: string
    amount: number
    frequency: 'weekly' | 'fortnightly' | 'monthly' | 'quarterly' | 'yearly'
    next_occurrence_date: string
    transaction_type: 'income' | 'expense'
    category?: string | null
    merchant_pattern?: string | null
    amount_tolerance?: number
    projection_months?: string
    is_active?: boolean
  }
  amount_tolerance?: number
  frequency?: 'weekly' | 'fortnightly' | 'monthly' | 'quarterly' | 'yearly'
  next_occurrence_date?: string
  projection_months?: string
}

export interface RecurringTransactionUpdateParams {
  recurring_transaction: {
    description?: string
    amount?: number
    frequency?: 'weekly' | 'fortnightly' | 'monthly' | 'quarterly' | 'yearly'
    next_occurrence_date?: string
    transaction_type?: 'income' | 'expense'
    category?: string | null
    merchant_pattern?: string | null
    amount_tolerance?: number
    projection_months?: string
    is_active?: boolean
  }
}

/**
 * Get list of recurring transactions
 */
export async function getRecurringTransactions(): Promise<ApiResponse<RecurringTransactionListResponse>> {
  return apiGet<RecurringTransactionListResponse>(endpoints.recurringTransactions.index())
}

/**
 * Get a single recurring transaction by ID
 * @param id - Recurring transaction ID
 */
export async function getRecurringTransaction(id: number): Promise<ApiResponse<RecurringTransaction>> {
  return apiGet<RecurringTransaction>(endpoints.recurringTransactions.show(id))
}

/**
 * Create a new recurring transaction
 * @param params - Recurring transaction data
 */
export async function createRecurringTransaction(
  params: RecurringTransactionCreateParams
): Promise<ApiResponse<RecurringTransaction>> {
  return apiPost<RecurringTransaction>(endpoints.recurringTransactions.create(), params)
}

/**
 * Update an existing recurring transaction
 * @param id - Recurring transaction ID
 * @param params - Updated recurring transaction data
 */
export async function updateRecurringTransaction(
  id: number,
  params: RecurringTransactionUpdateParams
): Promise<ApiResponse<RecurringTransaction>> {
  return apiPatch<RecurringTransaction>(endpoints.recurringTransactions.update(id), params)
}

/**
 * Delete a recurring transaction
 * @param id - Recurring transaction ID
 */
export async function deleteRecurringTransaction(
  id: number
): Promise<ApiResponse<{ message: string }>> {
  return apiDelete<{ message: string }>(endpoints.recurringTransactions.destroy(id))
}

/**
 * Toggle active status of a recurring transaction
 * @param id - Recurring transaction ID
 */
export async function toggleRecurringTransactionActive(
  id: number
): Promise<ApiResponse<{ recurring_transaction: RecurringTransaction; message: string }>> {
  return apiPost<{ recurring_transaction: RecurringTransaction; message: string }>(
    endpoints.recurringTransactions.toggleActive(id)
  )
}

