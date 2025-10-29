/**
 * Typed API functions for dashboard resource
 */

import { apiGet } from '../client'
import { endpoints } from '../endpoints'
import type { Transaction, RecurringTransaction } from '../../types/models'
import type { ApiResponse } from '../../types/api'

export interface DashboardStatsResponse {
  current_date: string
  recent_transactions: Transaction[]
  expense_count: number
  expense_total: number
  income_count: number
  income_total: number
  end_of_month_balance: number
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
  upcoming_recurring: {
    expenses: RecurringTransaction[]
    income: RecurringTransaction[]
    expense_total: number
    income_total: number
  }
}

/**
 * Get dashboard statistics
 */
export async function getDashboardStats(): Promise<ApiResponse<DashboardStatsResponse>> {
  return apiGet<DashboardStatsResponse>(endpoints.dashboard.stats())
}

