/**
 * React Query hook for trends data
 */

import { useApiQuery } from './useApi'
import { getTrendsData } from '../api/resources/trends'
import type { TrendsDataResponse } from '../api/resources/trends'

/**
 * Fetch trends data with React Query
 */
export function useTrendsData() {
  return useApiQuery<TrendsDataResponse>(
    ['trends', 'data'],
    () => getTrendsData(),
    {
      staleTime: 1000 * 60 * 5 // 5 minutes
    }
  )
}

