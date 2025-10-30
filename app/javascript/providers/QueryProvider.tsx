/**
 * React Query provider wrapper
 * Provides React Query context to all React islands
 * Includes IndexedDB persistence for offline support
 */

import React, { useEffect, useMemo } from 'react'
import { QueryClient } from '@tanstack/react-query'
import { PersistQueryClientProvider } from '@tanstack/react-query-persist-client'
import { persistenceStorage } from '../db/persistence-adapter'
import { initializeDatabase } from '../db/index'
import type { PersistedClient, Persister } from '@tanstack/react-query-persist-client'

// Create a query client with default options
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      refetchOnWindowFocus: false,
      retry: 1,
      staleTime: 1000 * 60 * 5, // 5 minutes
      gcTime: 1000 * 60 * 10, // 10 minutes (formerly cacheTime)
    },
    mutations: {
      retry: 1,
    },
  },
})

/**
 * Create custom persister using Dexie/IndexedDB
 */
function createDexiePersister(): Persister {
  return {
    persistClient: async (client: PersistedClient): Promise<void> => {
      await persistenceStorage.setItem('react-query-cache', JSON.stringify(client))
    },
    restoreClient: async (): Promise<PersistedClient | undefined> => {
      const data = await persistenceStorage.getItem('react-query-cache')
      return data ? (JSON.parse(data) as PersistedClient) : undefined
    },
    removeClient: async (): Promise<void> => {
      await persistenceStorage.removeItem('react-query-cache')
    },
  }
}

interface QueryProviderProps {
  children: React.ReactNode
}

/**
 * QueryProvider component - wraps children with React Query context
 * Includes persistence for offline support
 */
export function QueryProvider({ children }: QueryProviderProps): React.JSX.Element {
  // Initialize database on mount
  useEffect(() => {
    void initializeDatabase()
  }, [])

  // Create persister using our Dexie storage adapter
  const persister = useMemo(() => createDexiePersister(), [])

  return (
    <PersistQueryClientProvider
      client={queryClient}
      persistOptions={{
        persister,
        buster: '', // Cache buster (can be version-based)
        maxAge: 30 * 24 * 60 * 60 * 1000, // 30 days
      }}
    >
      {children}
    </PersistQueryClientProvider>
  )
}

/**
 * Get the default query client instance
 * Useful for programmatic access outside React components
 */
export function getQueryClient(): QueryClient {
  return queryClient
}
