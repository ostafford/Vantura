// Main application entry point for Vite
// JavaScript dependencies are managed via package.json and resolved by Vite
// Configuration: vite.config.ts
import '@hotwired/turbo-rails'
import 'controllers'
import 'helpers/notifications'
import 'pwa'
import 'utils/react-mount'
import { syncQueuedMutations, registerBackgroundSync } from './offline/sync-service'

// Listen for background sync messages from service worker
if ('serviceWorker' in navigator) {
  navigator.serviceWorker.addEventListener('message', async (event) => {
    if (event.data && event.data.type === 'SYNC_MUTATIONS') {
      console.log('[App] Background sync triggered by service worker')
      await syncQueuedMutations()
    }
  })

  // Register background sync when online
  window.addEventListener('online', () => {
    void registerBackgroundSync()
    void syncQueuedMutations()
  })

  // Initialize background sync on load
  if (navigator.onLine) {
    void registerBackgroundSync()
  }
}
