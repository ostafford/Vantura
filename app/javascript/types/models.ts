/**
 * Model type definitions matching Rails models
 */

export interface Transaction {
  id: number
  account_id: number
  up_transaction_id: string | null
  description: string
  merchant: string | null
  amount: number // Decimal as number in JSON
  category: string | null
  transaction_date: string // ISO date string
  status: TransactionStatus
  is_hypothetical: boolean
  recurring_transaction_id: number | null
  created_at: string
  updated_at: string
}

export type TransactionStatus = 'HELD' | 'SETTLED' | 'HYPOTHETICAL'

export interface RecurringTransaction {
  id: number
  account_id: number
  description: string
  amount: number // Decimal as number in JSON
  frequency: RecurringFrequency
  next_occurrence_date: string // ISO date string
  is_active: boolean
  transaction_type: TransactionType
  category: string | null
  template_transaction_id: number | null
  merchant_pattern: string | null
  amount_tolerance: number | null
  projection_months: string
  created_at: string
  updated_at: string
}

export type RecurringFrequency = 'weekly' | 'fortnightly' | 'monthly' | 'quarterly' | 'yearly'
export type TransactionType = 'income' | 'expense'

export interface Filter {
  id: number
  user_id: number
  name: string
  filter_params: FilterParams
  filter_types: string[] // Array of filter type strings
  date_range: DateRange | null
  created_at: string
  updated_at: string
}

export interface FilterParams {
  categories?: string[]
  merchants?: string[]
  statuses?: string[]
  recurring_transactions?: 'true' | 'false' | 'both'
}

export interface DateRange {
  start_date: string | null // ISO date string
  end_date: string | null // ISO date string
}

export interface User {
  id: number
  email: string
  created_at: string
  updated_at: string
}

export interface Account {
  id: number
  user_id: number | null
  up_account_id: string
  display_name: string
  account_type: AccountType
  current_balance: number // Decimal as number in JSON
  last_synced_at: string | null // ISO datetime string
  created_at: string
  updated_at: string
}

export type AccountType = 'TRANSACTIONAL' | 'SAVER' | 'HOME_LOAN'
