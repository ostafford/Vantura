/**
 * Typed API functions for calendar resource
 */

import { apiGet } from '../client'
import { endpoints } from '../endpoints'
import type { Transaction } from '../../types/models'
import type { ApiResponse } from '../../types/api'

export interface CalendarEventsParams {
  year?: number
  month?: number
  day?: number
  view?: 'month' | 'week'
}

export interface CalendarDay {
  date: string
  day_name?: string
  day_number?: number
  is_today?: boolean
  is_current_month?: boolean
  in_current_month?: boolean
}

export interface CalendarWeek {
  date: string
  in_current_month: boolean
}

export interface CalendarEventsResponse {
  view: 'month' | 'week'
  date: string
  year: number
  month: number
  start_date: string
  end_date: string
  transactions: Transaction[]
  transactions_by_date: Record<string, Transaction[]>
  calendar_structure: CalendarDay[][] | CalendarDay[]
  end_of_month_balance: number
  stats: {
    hypothetical_income: number
    hypothetical_expenses: number
    actual_income: number
    actual_expenses: number
    transaction_count: number
    month_day?: number
    total_days?: number
    progress_pct?: number
    week_income?: number
    week_expenses?: number
    week_transaction_count?: number
    week_total?: number
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

/**
 * Get calendar events
 * @param params - Query parameters (year, month, day, view)
 */
export async function getCalendarEvents(
  params?: CalendarEventsParams
): Promise<ApiResponse<CalendarEventsResponse>> {
  return apiGet<CalendarEventsResponse>(endpoints.calendar.events(), params as Record<string, string | number | boolean | null | undefined>)
}

