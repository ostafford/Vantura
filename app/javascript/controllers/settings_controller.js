import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = []

  connect() {
    // Settings controller for handling settings page interactions
  }

  toggleDarkMode(event) {
    const checkbox = event.target
    const isDark = checkbox.checked

    // Update UI immediately
    if (isDark) {
      document.documentElement.classList.add('dark')
      localStorage.setItem('color-theme', 'dark')
    } else {
      document.documentElement.classList.remove('dark')
      localStorage.setItem('color-theme', 'light')
    }

    // Sync with database
    this.updateDarkModePreference(isDark)
  }

  async updateDarkModePreference(isDark) {
    try {
      const csrfToken = document.querySelector('[name="csrf-token"]')
      if (!csrfToken) {
        console.warn('CSRF token not found')
        return
      }

      const response = await fetch('/settings', {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': csrfToken.content,
          'Accept': 'application/json'
        },
        body: JSON.stringify({ user: { dark_mode: isDark } }),
        credentials: 'same-origin'
      })

      if (!response.ok) {
        console.warn('Failed to update dark mode preference', response.status)
      }
    } catch (error) {
      console.error('Error updating dark mode preference:', error)
    }
  }

  syncNow(event) {
    // The form submission is handled by Turbo
    // This method can be used for additional UI feedback if needed
    const button = event.currentTarget
    button.disabled = true
    button.innerHTML = '<svg class="animate-spin h-4 w-4 inline mr-2" fill="none" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path></svg>Syncing...'
  }

  disconnectBank(event) {
    // Confirmation is handled by data-confirm attribute
    // This method can be used for additional UI feedback if needed
    if (!confirm(event.currentTarget.dataset.confirm)) {
      event.preventDefault()
      return false
    }
  }
}

