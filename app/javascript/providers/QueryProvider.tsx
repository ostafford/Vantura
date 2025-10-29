/**
 * React Query provider wrapper
 * Provides React Query context to all React islands
 */

import React from 'react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'

// Create a query client with default options
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      refetchOnWindowFocus: false,
      retry: 1,
      staleTime: 1000 * 60 * 5, // 5 minutes
      gcTime: 1000 * 60 * 10 // 10 minutes (formerly cacheTime)
    },
    mutations: {
      retry: 1
    }
  }
})

interface QueryProviderProps {
  children: React.ReactNode
}

/**
 * QueryProvider component - wraps children with React Query context
 */
export function QueryProvider({ children }: QueryProviderProps): React.JSX.Element {
  return (
    <QueryClientProvider client={queryClient}>
      {children}
    </QueryClientProvider>
  )
}

/**
 * Get the default query client instance
 * Useful for programmatic access outside React components
 */
export function getQueryClient(): QueryClient {
  return queryClient
}

