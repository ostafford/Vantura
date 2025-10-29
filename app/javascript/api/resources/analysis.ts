/**
 * Typed API functions for analysis resource
 */

import { apiGet } from '../client'
import { endpoints } from '../endpoints'
import type { Transaction, Filter } from '../../types/models'
import type { ApiResponse } from '../../types/api'

export interface AnalysisDataParams {
  filter_id?: number
}

export interface AnalysisDataResponse {
  current_date: string
  selected_filter: Filter | null
  transactions: Transaction[]
  stats: {
    current_month_income: number
    current_month_expenses: number
    net_savings: number
    last_month_income: number
    last_month_expenses: number
    income_change_pct: number
    expense_change_pct: number
    net_change_pct: number
    top_merchant: {
      name: string
      amount: number
    }
  }
  breakdowns: Record<string, Record<string, number>>
}

/**
 * Get analysis data
 * @param params - Query parameters (filter_id)
 */
export async function getAnalysisData(
  params?: AnalysisDataParams
): Promise<ApiResponse<AnalysisDataResponse>> {
  return apiGet<AnalysisDataResponse>(endpoints.analysis.data(), params as Record<string, string | number | boolean | null | undefined>)
}

