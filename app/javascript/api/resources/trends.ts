/**
 * Typed API functions for trends resource
 */

import { apiGet } from '../client'
import { endpoints } from '../endpoints'
import type { ApiResponse } from '../../types/api'

export interface TrendsDataResponse {
  current_date: string
  current_month_income: number
  current_month_expenses: number
  net_savings: number
  last_month_income: number
  last_month_expenses: number
  income_change_pct: number
  expense_change_pct: number
  net_change_pct: number
  active_recurring_count: number
  top_merchant: {
    name: string
    amount: number
  }
}

/**
 * Get trends data
 */
export async function getTrendsData(): Promise<ApiResponse<TrendsDataResponse>> {
  return apiGet<TrendsDataResponse>(endpoints.trends.data())
}

