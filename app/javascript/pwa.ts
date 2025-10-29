// PWA Service Worker Registration
// Registers service worker and handles updates

import { showNotification } from './helpers/notifications'

if ('serviceWorker' in navigator) {
  // Only register in production/HTTPS or localhost
  const isLocalhost =
    window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1'
  const isSecure = window.location.protocol === 'https:' || isLocalhost

  if (isSecure) {
    window.addEventListener('load', () => {
      navigator.serviceWorker
        .register('/service-worker')
        .then((registration: ServiceWorkerRegistration) => {
          console.log('[PWA] Service Worker registered:', registration.scope)

          // Check for updates periodically
          registration.addEventListener('updatefound', () => {
            const newWorker = registration.installing

            if (newWorker) {
              newWorker.addEventListener('statechange', () => {
                if (newWorker.state === 'installed' && navigator.serviceWorker.controller) {
                  // New service worker available - notify user
                  console.log('[PWA] New service worker available')
                  // Optionally show notification to user
                  notifyServiceWorkerUpdate()
                }
              })
            }
          })

          // Check for updates every hour
          setInterval(() => {
            void registration.update()
          }, 3600000) // 1 hour
        })
        .catch((error: Error) => {
          console.error('[PWA] Service Worker registration failed:', error)
        })
    })

    // Listen for controller changes (service worker updated)
    navigator.serviceWorker.addEventListener('controllerchange', () => {
      console.log('[PWA] Service Worker updated - reloading page')
      window.location.reload()
    })
  } else {
    console.warn('[PWA] Service Worker requires HTTPS (or localhost)')
  }
} else {
  console.warn('[PWA] Service Worker not supported in this browser')
}

// Notify user of service worker update
function notifyServiceWorkerUpdate(): void {
  // Only notify if not already shown
  if (!document.querySelector('[data-pwa-update-notification]')) {
    showNotification('info', 'New version available', {
      autoDismiss: true,
      dismissAfter: 10000,
    })
  }
}
