/**
 * Dexie storage adapter for React Query persistence
 * Implements asyncStorage interface compatible with react-query-persist-client
 */

import { db } from './index'

/**
 * Storage adapter implementing asyncStorage interface
 * Used by react-query-persist-client to store/retrieve query cache
 * Compatible with AsyncStorage pattern
 */
export const persistenceStorage = {
  async getItem(key: string): Promise<string | null> {
    try {
      const cached = await db.dashboardStats
        .where('id')
        .equals(`queryCache_${key}`)
        .first()

      if (cached && cached.expires_at > Date.now()) {
        return JSON.stringify(cached.data)
      }

      // Clear expired cache
      if (cached) {
        await db.dashboardStats
          .where('id')
          .equals(`queryCache_${key}`)
          .delete()
      }

      return null
    } catch (error) {
      console.error('[Persistence] Failed to get item:', error)
      return null
    }
  },

  async setItem(key: string, value: string): Promise<void> {
    try {
      // Parse to validate JSON, then store the string
      JSON.parse(value) // Validate JSON is valid
      const data = JSON.parse(value)
      
      const cacheEntry = {
        id: `queryCache_${key}`,
        data: data,
        cached_at: Date.now(),
        expires_at: Date.now() + 30 * 24 * 60 * 60 * 1000 // 30 days
      }

      // Upsert: delete existing, then add new
      await db.dashboardStats
        .where('id')
        .equals(`queryCache_${key}`)
        .delete()
      await db.dashboardStats.add(cacheEntry)
    } catch (error) {
      console.error('[Persistence] Failed to set item:', error)
      throw error
    }
  },

  async removeItem(key: string): Promise<void> {
    try {
      await db.dashboardStats.where('id').equals(`queryCache_${key}`).delete()
    } catch (error) {
      console.error('[Persistence] Failed to remove item:', error)
      throw error
    }
  }
}
