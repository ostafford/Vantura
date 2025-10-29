/**
 * Service response types for dashboard stats, calendar, trends, analysis
 */

export interface DashboardStats {
  current_balance: number
  income_total: number
  expense_total: number
  eom_projection: number
  top_merchants: MerchantStats[]
}

export interface MerchantStats {
  merchant: string | null
  amount: number
  transaction_count: number
}

export interface CalendarEvent {
  date: string // ISO date string
  count: number
  income_total: number | null
  expense_total: number | null
}

export interface CalendarStats {
  events: CalendarEvent[]
  month: number
  year: number
}

export interface TrendsData {
  periods: string[]
  income: number[]
  expenses: number[]
  net: number[]
}

export interface AnalysisData {
  category_breakdown: CategoryBreakdown[]
  merchant_breakdown: MerchantBreakdown[]
  monthly_trends: MonthlyTrend[]
}

export interface CategoryBreakdown {
  category: string | null
  total: number
  count: number
}

export interface MerchantBreakdown {
  merchant: string | null
  total: number
  count: number
}

export interface MonthlyTrend {
  month: string // Format: "YYYY-MM"
  income: number
  expenses: number
  net: number
}
