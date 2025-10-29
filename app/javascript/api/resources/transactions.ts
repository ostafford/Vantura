/**
 * Typed API functions for transactions resource
 */

import { apiGet, apiPost, apiPatch, apiDelete } from '../client'
import { endpoints } from '../endpoints'
import type { Transaction } from '../../types/models'
import type { ApiResponse } from '../../types/api'

export interface TransactionListResponse {
  transactions: Transaction[]
  stats: {
    expense_total: number
    income_total: number
    expense_count: number
    income_count: number
    net_cash_flow: number
    transaction_count: number
    top_category: string
    top_category_amount: number
    top_expense_merchants: Array<{
      merchant: string
      total: number
      count: number
      hypothetical: boolean
    }>
    top_income_merchants: Array<{
      merchant: string
      total: number
      count: number
      hypothetical: boolean
    }>
  }
}

export interface TransactionSearchParams {
  q?: string
  year?: number
  month?: number
  filter?: 'all' | 'expenses' | 'income' | 'hypothetical'
  page?: number
  per_page?: number
}

export interface TransactionCreateParams {
  transaction: {
    description: string
    amount: number
    transaction_date: string
    category?: string | null
    merchant?: string | null
    transaction_type?: 'expense' | 'income'
  }
}

export interface TransactionUpdateParams {
  transaction: {
    description?: string
    amount?: number
    transaction_date?: string
    category?: string | null
    merchant?: string | null
  }
}

/**
 * Get list of transactions
 * @param params - Query parameters (filter, year, month, page, per_page)
 */
export async function getTransactions(
  params?: TransactionSearchParams
): Promise<ApiResponse<TransactionListResponse>> {
  return apiGet<TransactionListResponse>(endpoints.transactions.index(), params as Record<string, string | number | boolean | null | undefined>)
}

/**
 * Get transactions for a specific month
 * @param year - Year
 * @param month - Month (1-12)
 * @param params - Additional query parameters
 */
export async function getTransactionsByMonth(
  year: number,
  month: number,
  params?: Omit<TransactionSearchParams, 'year' | 'month'>
): Promise<ApiResponse<TransactionListResponse>> {
  return apiGet<TransactionListResponse>(
    endpoints.transactions.month(year, month),
    params as Record<string, string | number | boolean | null | undefined>
  )
}

/**
 * Get a single transaction by ID
 * @param id - Transaction ID
 */
export async function getTransaction(id: number): Promise<ApiResponse<Transaction>> {
  return apiGet<Transaction>(endpoints.transactions.show(id))
}

/**
 * Search transactions
 * @param params - Search parameters (q, year, month)
 */
export async function searchTransactions(
  params: Pick<TransactionSearchParams, 'q' | 'year' | 'month'>
): Promise<ApiResponse<TransactionListResponse>> {
  return apiGet<TransactionListResponse>(endpoints.transactions.search(), params as Record<string, string | number | boolean | null | undefined>)
}

/**
 * Create a new transaction
 * @param params - Transaction data
 */
export async function createTransaction(
  params: TransactionCreateParams
): Promise<ApiResponse<Transaction>> {
  return apiPost<Transaction>(endpoints.transactions.create(), params)
}

/**
 * Update an existing transaction
 * @param id - Transaction ID
 * @param params - Updated transaction data
 */
export async function updateTransaction(
  id: number,
  params: TransactionUpdateParams
): Promise<ApiResponse<Transaction>> {
  return apiPatch<Transaction>(endpoints.transactions.update(id), params)
}

/**
 * Delete a transaction
 * @param id - Transaction ID
 */
export async function deleteTransaction(
  id: number
): Promise<ApiResponse<{ message: string }>> {
  return apiDelete<{ message: string }>(endpoints.transactions.destroy(id))
}

