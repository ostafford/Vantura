/**
 * Base API types for consistent response/error handling
 */

export interface ApiResponse<T> {
  data: T
  meta?: Meta
}

export interface ApiError {
  error: {
    code: string
    message: string
    details?: Record<string, unknown>
  }
}

export interface Meta {
  timestamp?: string
  version?: string
  pagination?: PaginationMeta
}

export interface PaginationMeta {
  page: number
  per_page: number
  total: number
  total_pages: number
}
