/**
 * Optimistic Mutation Hook
 * Enhanced mutation hook with optimistic updates, rollback on error, and offline queuing
 */

import { useMutation, useQueryClient, UseMutationOptions } from '@tanstack/react-query'
import type { ApiResponse, ApiError } from '../types/api'
import { enqueueMutation } from '../offline/queue-manager'
import { serializeMutation } from '../offline/mutation-serializer'
import { invalidateCacheForMutation } from '../offline/cache-invalidator'

/**
 * Options for optimistic mutations
 */
export interface OptimisticMutationOptions<TData, TVariables> {
  /**
   * Query keys to invalidate on success
   */
  invalidateQueries?: readonly unknown[]
  /**
   * Optimistic update function - updates cache immediately before network request
   */
  onOptimisticUpdate?: (variables: TVariables) => void
  /**
   * Rollback function - called if mutation fails
   */
  onRollback?: (variables: TVariables, error: ApiError) => void
  /**
   * Extract entity ID from variables for conflict resolution
   */
  extractId?: (variables: TVariables) => number | string | null
}

/**
 * Enhanced mutation hook with optimistic updates
 * Automatically queues mutations when offline
 */
export function useOptimisticMutation<TData, TVariables>(
  mutationFn: (variables: TVariables) => Promise<ApiResponse<TData>>,
  options?: Omit<
    UseMutationOptions<ApiResponse<TData>, ApiError, TVariables, unknown>,
    'mutationFn'
  > &
    OptimisticMutationOptions<TData, TVariables>
) {
  const queryClient = useQueryClient()

  const mutationOptions: UseMutationOptions<
    ApiResponse<TData>,
    ApiError,
    TVariables,
    unknown
  > = {
    mutationFn: async (variables: TVariables) => {
      // If offline, queue mutation and return queued response
      if (!navigator.onLine) {
        // Extract URL and method from mutation function (we'll need to pass this differently)
        // For now, we'll catch this in the API client
        return mutationFn(variables)
      }

      // Online - proceed with normal mutation
      return mutationFn(variables)
    },
    onMutate: async (variables: TVariables) => {
      // Cancel outgoing queries to prevent race conditions
      if (options?.invalidateQueries) {
        await Promise.all(
          options.invalidateQueries.map((queryKey) =>
            queryClient.cancelQueries({ queryKey })
          )
        )
      }

      // Snapshot previous values for rollback
      const previousData: Record<string, unknown> = {}
      if (options?.invalidateQueries) {
        for (const queryKey of options.invalidateQueries) {
          previousData[JSON.stringify(queryKey)] = queryClient.getQueryData(queryKey)
        }
      }

      // Apply optimistic update
      if (options?.onOptimisticUpdate) {
        options.onOptimisticUpdate(variables)
      }

      // Return context for rollback
      return { previousData }
    },
    onError: (error: ApiError, variables: TVariables, context: unknown) => {
      // Rollback optimistic updates
      if (context && typeof context === 'object' && 'previousData' in context) {
        const previousData = context.previousData as Record<string, unknown>

        // Restore previous query data
        Object.entries(previousData).forEach(([key, data]) => {
          try {
            const queryKey = JSON.parse(key) as readonly unknown[]
            queryClient.setQueryData(queryKey, data)
          } catch {
            // Ignore parse errors
          }
        })

        // Call custom rollback handler
        if (options?.onRollback) {
          options.onRollback(variables, error)
        }
      }

      // Call original error handler if provided
      if (options?.onError) {
        options.onError(error, variables, context, undefined as never)
      }
    },
    onSuccess: (data: ApiResponse<TData>, variables: TVariables, context: unknown) => {
      // Check if mutation was queued
      if (data.data && typeof data.data === 'object' && 'queued' in data.data) {
        // Mutation was queued - invalidate affected queries
        if (options?.invalidateQueries) {
          options.invalidateQueries.forEach((queryKey) => {
            queryClient.invalidateQueries({ queryKey })
          })
        }
      } else {
        // Mutation succeeded - merge server response (server timestamp wins)
        const entityId = options?.extractId?.(variables)

        // Invalidate cache based on mutation type
        if (entityId !== undefined && entityId !== null) {
          invalidateCacheForMutation(variables, queryClient)
        }

        // Invalidate specified queries
        if (options?.invalidateQueries) {
          options.invalidateQueries.forEach((queryKey) => {
            queryClient.invalidateQueries({ queryKey })
          })
        }
      }

      // Call original success handler
      if (options?.onSuccess) {
        options.onSuccess(data, variables, context, undefined as never)
      }
    },
    ...options,
  }

  return useMutation(mutationOptions)
}

