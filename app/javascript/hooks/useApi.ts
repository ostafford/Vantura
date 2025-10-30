/**
 * Custom hooks for API calls using React Query
 */

import { useQuery, useMutation, useQueryClient, UseQueryOptions, UseMutationOptions } from '@tanstack/react-query'
import type { ApiResponse, ApiError } from '../types/api'

/**
 * Generic hook for GET requests
 */
export function useApiQuery<T>(
  queryKey: readonly unknown[],
  queryFn: () => Promise<ApiResponse<T>>,
  options?: Omit<UseQueryOptions<ApiResponse<T>, ApiError, ApiResponse<T>, readonly unknown[]>, 'queryKey' | 'queryFn'>
) {
  return useQuery({
    queryKey,
    queryFn,
    ...options
  } as UseQueryOptions<ApiResponse<T>, ApiError, ApiResponse<T>, readonly unknown[]>)
}

/**
 * Generic hook for mutations (POST, PATCH, PUT, DELETE)
 * Now supports offline queuing automatically via API client
 */
export function useApiMutation<TData, TVariables>(
  mutationFn: (variables: TVariables) => Promise<ApiResponse<TData>>,
  options?: Omit<UseMutationOptions<ApiResponse<TData>, ApiError, TVariables, unknown>, 'mutationFn'>
) {
  const queryClient = useQueryClient()

  const mutationOptions = {
    mutationFn,
    ...options,
    onError: (error: ApiError, variables: TVariables, context: unknown, _mutation: unknown) => {
      console.error('[useApiMutation] Error:', error)
      if (options?.onError) {
        // @ts-expect-error - React Query v5 type mismatch workaround
        options.onError(error, variables, context)
      }
    },
    onSuccess: (data: ApiResponse<TData>, variables: TVariables, context: unknown, _mutation: unknown) => {
      // Check if mutation was queued (offline mode)
      const wasQueued =
        data.data &&
        typeof data.data === 'object' &&
        'queued' in data.data &&
        (data.data as { queued?: boolean }).queued === true

      if (!wasQueued) {
        // Only invalidate if mutation actually succeeded (not queued)
        // Invalidate relevant queries on success
        queryClient.invalidateQueries({ queryKey: [] })
      }

      if (options?.onSuccess) {
        // @ts-expect-error - React Query v5 type mismatch workaround
        options.onSuccess(data, variables, context)
      }
    },
  }

  return useMutation(mutationOptions as UseMutationOptions<ApiResponse<TData>, ApiError, TVariables, unknown>)
}

