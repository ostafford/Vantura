/**
 * Typed API functions for filters resource
 */

import { apiGet, apiPost, apiPatch, apiDelete } from '../client'
import { endpoints } from '../endpoints'
import type { Filter } from '../../types/models'
import type { ApiResponse } from '../../types/api'

export interface FilterCreateParams {
  filter: {
    name: string
    filter_types: string[]
    filter_params?: Record<string, unknown>
    date_range?: {
      start_date: string | null
      end_date: string | null
    } | null
  }
}

export interface FilterUpdateParams {
  filter: {
    name?: string
    filter_types?: string[]
    filter_params?: Record<string, unknown>
    date_range?: {
      start_date: string | null
      end_date: string | null
    } | null
  }
}

/**
 * Get list of filters
 */
export async function getFilters(): Promise<ApiResponse<Filter[]>> {
  return apiGet<Filter[]>(endpoints.filters.index())
}

/**
 * Get a single filter by ID
 * @param id - Filter ID
 */
export async function getFilter(id: number): Promise<ApiResponse<Filter>> {
  return apiGet<Filter>(endpoints.filters.show(id))
}

/**
 * Create a new filter
 * @param params - Filter data
 */
export async function createFilter(params: FilterCreateParams): Promise<ApiResponse<Filter>> {
  return apiPost<Filter>(endpoints.filters.create(), params)
}

/**
 * Update an existing filter
 * @param id - Filter ID
 * @param params - Updated filter data
 */
export async function updateFilter(
  id: number,
  params: FilterUpdateParams
): Promise<ApiResponse<Filter>> {
  return apiPatch<Filter>(endpoints.filters.update(id), params)
}

/**
 * Delete a filter
 * @param id - Filter ID
 */
export async function deleteFilter(id: number): Promise<ApiResponse<{ message: string }>> {
  return apiDelete<{ message: string }>(endpoints.filters.destroy(id))
}

