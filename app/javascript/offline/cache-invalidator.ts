/**
 * Cache Invalidation Rules Engine
 * Invalidates React Query cache based on mutation type
 */

import type { QueryClient } from '@tanstack/react-query'
import { extractEntityType } from './mutation-serializer'

/**
 * Invalidate cache for a mutation based on its type
 */
export function invalidateCacheForMutation(
  variables: unknown,
  queryClient: QueryClient
): void {
  // Try to determine mutation type from variables
  // This is a best-effort approach since we don't have the URL here
  // In practice, callers should pass mutation type or URL

  // Transaction mutations
  if (
    variables &&
    typeof variables === 'object' &&
    ('transaction' in variables || 'description' in variables || 'amount' in variables)
  ) {
    queryClient.invalidateQueries({ queryKey: ['transactions'] })
    queryClient.invalidateQueries({ queryKey: ['dashboard/stats'] })
    queryClient.invalidateQueries({ queryKey: ['calendar/events'] })
    return
  }

  // Recurring transaction mutations
  if (
    variables &&
    typeof variables === 'object' &&
    ('recurring_transaction' in variables ||
      'frequency' in variables ||
      'next_occurrence_date' in variables)
  ) {
    queryClient.invalidateQueries({ queryKey: ['recurring-transactions'] })
    queryClient.invalidateQueries({ queryKey: ['calendar/events'] })
    queryClient.invalidateQueries({ queryKey: ['dashboard/stats'] })
    return
  }

  // Filter mutations
  if (
    variables &&
    typeof variables === 'object' &&
    ('filter' in variables || 'filter_types' in variables || 'filter_params' in variables)
  ) {
    queryClient.invalidateQueries({ queryKey: ['filters'] })
    queryClient.invalidateQueries({ queryKey: ['dashboard/stats'] })
    return
  }
}

/**
 * Invalidate cache based on mutation URL
 */
export function invalidateCacheForUrl(url: string, queryClient: QueryClient): void {
  const entityType = extractEntityType(url)

  switch (entityType) {
    case 'transaction':
      queryClient.invalidateQueries({ queryKey: ['transactions'] })
      queryClient.invalidateQueries({ queryKey: ['dashboard/stats'] })
      queryClient.invalidateQueries({ queryKey: ['calendar/events'] })
      break

    case 'recurring_transaction':
      queryClient.invalidateQueries({ queryKey: ['recurring-transactions'] })
      queryClient.invalidateQueries({ queryKey: ['calendar/events'] })
      queryClient.invalidateQueries({ queryKey: ['dashboard/stats'] })
      break

    case 'filter':
      queryClient.invalidateQueries({ queryKey: ['filters'] })
      queryClient.invalidateQueries({ queryKey: ['dashboard/stats'] })
      break

    default:
      // Fallback: invalidate all
      queryClient.invalidateQueries({ queryKey: [] })
  }
}

/**
 * Invalidate cache after successful sync
 */
export function invalidateCacheAfterSync(
  mutationType: string,
  queryClient: QueryClient
): void {
  if (mutationType.includes('transaction') && !mutationType.includes('recurring')) {
    queryClient.invalidateQueries({ queryKey: ['transactions'] })
    queryClient.invalidateQueries({ queryKey: ['dashboard/stats'] })
    queryClient.invalidateQueries({ queryKey: ['calendar/events'] })
  } else if (mutationType.includes('recurring')) {
    queryClient.invalidateQueries({ queryKey: ['recurring-transactions'] })
    queryClient.invalidateQueries({ queryKey: ['calendar/events'] })
    queryClient.invalidateQueries({ queryKey: ['dashboard/stats'] })
  } else if (mutationType.includes('filter')) {
    queryClient.invalidateQueries({ queryKey: ['filters'] })
    queryClient.invalidateQueries({ queryKey: ['dashboard/stats'] })
  }
}

