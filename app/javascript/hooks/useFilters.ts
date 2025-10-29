/**
 * React Query hooks for filters
 */

import { useApiQuery, useApiMutation } from './useApi'
import { getFilters, getFilter, createFilter, updateFilter, deleteFilter } from '../api/resources/filters'
import type { Filter } from '../types/models'
import type { FilterCreateParams, FilterUpdateParams } from '../api/resources/filters'

/**
 * Fetch all filters
 */
export function useFilters() {
  return useApiQuery<Filter[]>(
    ['filters'],
    () => getFilters(),
    {
      staleTime: 1000 * 60 * 5 // 5 minutes
    }
  )
}

/**
 * Fetch a single filter by ID
 */
export function useFilter(id: number | null) {
  return useApiQuery<Filter>(
    ['filters', id],
    () => {
      if (!id) throw new Error('Filter ID is required')
      return getFilter(id)
    },
    {
      enabled: !!id,
      staleTime: 1000 * 60 * 5
    }
  )
}

/**
 * Create a new filter
 */
export function useCreateFilter() {
  return useApiMutation<Filter, FilterCreateParams>(
    (params) => createFilter(params),
    {
      onSuccess: () => {
        // Invalidates filters list
      }
    }
  )
}

/**
 * Update an existing filter
 */
export function useUpdateFilter() {
  return useApiMutation<Filter, { id: number; params: FilterUpdateParams }>(
    ({ id, params }) => updateFilter(id, params),
    {
      onSuccess: () => {
        // Invalidates filters list
      }
    }
  )
}

/**
 * Delete a filter
 */
export function useDeleteFilter() {
  return useApiMutation<{ message: string }, number>(
    (id) => deleteFilter(id),
    {
      onSuccess: () => {
        // Invalidates filters list
      }
    }
  )
}

