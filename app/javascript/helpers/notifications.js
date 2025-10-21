// Helper utility for showing toast notifications from JavaScript
// This allows any controller to easily show notifications

export function showNotification(type, message, options = {}) {
  const {
    autoDismiss = true,
    dismissAfter = 5000
  } = options

  // Find the notification container
  const container = document.querySelector('[data-controller="notification"][data-notification-target="container"]')
  
  if (!container) {
    console.error('Notification container not found. Make sure the notifications partial is rendered.')
    return
  }

  // Create the notification element
  const notification = createNotificationElement(type, message, autoDismiss, dismissAfter)
  
  // Append to container
  container.appendChild(notification)
}

function createNotificationElement(type, message, autoDismiss, dismissAfter) {
  const wrapper = document.createElement('div')
  wrapper.dataset.controller = "notification"
  wrapper.dataset.notificationType = type
  wrapper.dataset.notificationAutoDismissValue = autoDismiss
  wrapper.dataset.notificationDismissAfterValue = dismissAfter
  
  const colors = {
    success: {
      bg: 'bg-white/95 dark:bg-green-950/95 backdrop-blur-sm',
      border: 'border-2 border-green-300 dark:border-green-700',
      icon: 'text-green-600 dark:text-green-400',
      text: 'text-green-800 dark:text-green-200',
      button: 'text-green-600 dark:text-green-400 hover:text-green-700 dark:hover:text-green-300'
    },
    error: {
      bg: 'bg-white/95 dark:bg-red-950/95 backdrop-blur-sm',
      border: 'border-2 border-red-300 dark:border-red-700',
      icon: 'text-red-600 dark:text-red-400',
      text: 'text-red-800 dark:text-red-200',
      button: 'text-red-600 dark:text-red-400 hover:text-red-700 dark:hover:text-red-300'
    },
    warning: {
      bg: 'bg-white/95 dark:bg-yellow-950/95 backdrop-blur-sm',
      border: 'border-2 border-yellow-300 dark:border-yellow-700',
      icon: 'text-yellow-600 dark:text-yellow-400',
      text: 'text-yellow-800 dark:text-yellow-200',
      button: 'text-yellow-600 dark:text-yellow-400 hover:text-yellow-700 dark:hover:text-yellow-300'
    },
    info: {
      bg: 'bg-white/95 dark:bg-blue-950/95 backdrop-blur-sm',
      border: 'border-2 border-blue-300 dark:border-blue-700',
      icon: 'text-blue-600 dark:text-blue-400',
      text: 'text-blue-800 dark:text-blue-200',
      button: 'text-blue-600 dark:text-blue-400 hover:text-blue-700 dark:hover:text-blue-300'
    }
  }

  const typeColors = colors[type] || colors.info
  const icon = getIcon(type)

  wrapper.innerHTML = `
    <div class="w-96 ${typeColors.bg} ${typeColors.border} rounded-xl shadow-xl pointer-events-auto overflow-hidden transform translate-x-full opacity-0 transition-all duration-300 ease-out">
      <div class="p-4">
        <div class="flex items-start">
          <div class="flex-shrink-0">
            ${icon}
          </div>
          <div class="ml-3 w-0 flex-1 pt-0.5">
            <p class="${typeColors.text} text-sm font-medium">${escapeHtml(message)}</p>
          </div>
          <div class="ml-4 flex-shrink-0 flex">
            <button data-action="click->notification#dismiss" class="${typeColors.button} rounded-md inline-flex focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-offset-transparent transition-colors duration-200">
              <span class="sr-only">Close</span>
              <svg class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd" />
              </svg>
            </button>
          </div>
        </div>
      </div>
    </div>
  `

  return wrapper
}

function getIcon(type) {
  const icons = {
    success: `<svg class="h-6 w-6 text-green-600 dark:text-green-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
    </svg>`,
    error: `<svg class="h-6 w-6 text-red-600 dark:text-red-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
    </svg>`,
    warning: `<svg class="h-6 w-6 text-yellow-600 dark:text-yellow-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
    </svg>`,
    info: `<svg class="h-6 w-6 text-blue-600 dark:text-blue-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
    </svg>`
  }
  return icons[type] || icons.info
}

function escapeHtml(text) {
  const map = {
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#039;'
  }
  return text.replace(/[&<>"']/g, m => map[m])
}

// Make it available globally for easy access from any script
window.showNotification = showNotification

