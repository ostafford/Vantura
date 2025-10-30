/**
 * Mutation Serializer
 * Converts React Query mutations to queue format and vice versa
 */

import type { QueuedMutation, MutationType } from '../types/offline'

/**
 * Determine mutation type from URL and method
 */
export function determineMutationType(
  url: string,
  method: string
): MutationType | null {
  if (method === 'POST') {
    if (url.includes('/transactions')) {
      return 'create_transaction'
    }
    if (url.includes('/recurring_transactions')) {
      if (url.includes('/toggle_active')) {
        return 'toggle_recurring_active'
      }
      return 'create_recurring_transaction'
    }
    if (url.includes('/filters')) {
      return 'create_filter'
    }
  }

  if (method === 'PATCH' || method === 'PUT') {
    if (url.includes('/transactions/')) {
      return 'update_transaction'
    }
    if (url.includes('/recurring_transactions/')) {
      return 'update_recurring_transaction'
    }
    if (url.includes('/filters/')) {
      return 'update_filter'
    }
  }

  if (method === 'DELETE') {
    if (url.includes('/transactions/')) {
      return 'delete_transaction'
    }
    if (url.includes('/recurring_transactions/')) {
      return 'delete_recurring_transaction'
    }
    if (url.includes('/filters/')) {
      return 'delete_filter'
    }
  }

  return null
}

/**
 * Serialize mutation for queue storage
 */
export function serializeMutation(
  url: string,
  method: string,
  payload?: Record<string, unknown>
): Omit<QueuedMutation, 'id' | 'status' | 'retries' | 'created_at'> {
  const type = determineMutationType(url, method)

  if (!type) {
    throw new Error(`Unable to determine mutation type for ${method} ${url}`)
  }

  return {
    type,
    url,
    method,
    payload: payload || {},
    error: undefined,
  }
}

/**
 * Deserialize mutation from queue
 * Reconstructs the mutation data for replay
 */
export function deserializeMutation(
  queuedMutation: QueuedMutation
): {
  url: string
  method: string
  payload?: Record<string, unknown>
} {
  return {
    url: queuedMutation.url,
    method: queuedMutation.method,
    payload: queuedMutation.payload,
  }
}

/**
 * Extract entity ID from URL
 * Used for optimistic updates and conflict resolution
 */
export function extractEntityId(url: string): number | null {
  // Extract ID from URLs like /api/v1/transactions/123 or /api/v1/filters/456
  const match = url.match(/\/(\d+)(?:\/|$)/)
  return match ? parseInt(match[1], 10) : null
}

/**
 * Extract entity type from URL
 */
export function extractEntityType(url: string): 'transaction' | 'recurring_transaction' | 'filter' | null {
  if (url.includes('/transactions/') && !url.includes('/recurring')) {
    return 'transaction'
  }
  if (url.includes('/recurring_transactions/')) {
    return 'recurring_transaction'
  }
  if (url.includes('/filters/')) {
    return 'filter'
  }
  return null
}

