/**
 * React Query hook for analysis data
 */

import { useApiQuery } from './useApi'
import { getAnalysisData } from '../api/resources/analysis'
import type { AnalysisDataResponse } from '../api/resources/analysis'

/**
 * Fetch analysis data with React Query
 * @param filterId - Optional filter ID to apply
 */
export function useAnalysisData(filterId?: number) {
  return useApiQuery<AnalysisDataResponse>(
    ['analysis', 'data', filterId],
    () => getAnalysisData(filterId ? { filter_id: filterId } : undefined),
    {
      staleTime: 1000 * 60 * 5 // 5 minutes
    }
  )
}

