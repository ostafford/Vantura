/**
 * Typed endpoint URL constants for API v1
 * All endpoints are prefixed with /api/v1
 */

export const API_BASE = '/api/v1';

export const endpoints = {
  // Transactions
  transactions: {
    index: () => `${API_BASE}/transactions`,
    show: (id: number) => `${API_BASE}/transactions/${id}`,
    create: () => `${API_BASE}/transactions`,
    update: (id: number) => `${API_BASE}/transactions/${id}`,
    destroy: (id: number) => `${API_BASE}/transactions/${id}`,
    search: () => `${API_BASE}/transactions/search`,
    month: (year: number, month: number) => `${API_BASE}/transactions/${year}/${month}`
  },

  // Recurring Transactions
  recurringTransactions: {
    index: () => `${API_BASE}/recurring_transactions`,
    show: (id: number) => `${API_BASE}/recurring_transactions/${id}`,
    create: () => `${API_BASE}/recurring_transactions`,
    update: (id: number) => `${API_BASE}/recurring_transactions/${id}`,
    destroy: (id: number) => `${API_BASE}/recurring_transactions/${id}`,
    toggleActive: (id: number) => `${API_BASE}/recurring_transactions/${id}/toggle_active`
  },

  // Filters
  filters: {
    index: () => `${API_BASE}/filters`,
    show: (id: number) => `${API_BASE}/filters/${id}`,
    create: () => `${API_BASE}/filters`,
    update: (id: number) => `${API_BASE}/filters/${id}`,
    destroy: (id: number) => `${API_BASE}/filters/${id}`
  },

  // Dashboard
  dashboard: {
    stats: () => `${API_BASE}/dashboard/stats`
  },

  // Calendar
  calendar: {
    events: () => `${API_BASE}/calendar/events`
  },

  // Trends
  trends: {
    data: () => `${API_BASE}/trends/data`
  },

  // Analysis
  analysis: {
    data: () => `${API_BASE}/analysis/data`
  }
} as const;

