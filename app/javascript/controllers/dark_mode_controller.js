import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // Check for saved theme preference or default to light mode
    // Migrate old 'theme' key to 'color-theme' for Flowbite consistency
    const oldTheme = localStorage.getItem('theme')
    if (oldTheme && !localStorage.getItem('color-theme')) {
      localStorage.setItem('color-theme', oldTheme)
      localStorage.removeItem('theme')
    }
    const savedTheme = localStorage.getItem('color-theme')
    const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches
    
    if (savedTheme === 'dark' || (!savedTheme && prefersDark)) {
      this.enableDarkMode()
    } else {
      this.disableDarkMode()
    }
  }

  toggle() {
    if (document.documentElement.classList.contains('dark')) {
      this.disableDarkMode()
    } else {
      this.enableDarkMode()
    }
  }

  enableDarkMode() {
    document.documentElement.classList.add('dark')
    localStorage.setItem('color-theme', 'dark')
    
    // Update user preference if user is signed in
    if (window.currentUserId) {
      this.updateUserPreference(true)
    }
  }

  disableDarkMode() {
    document.documentElement.classList.remove('dark')
    localStorage.setItem('color-theme', 'light')
    
    // Update user preference if user is signed in
    if (window.currentUserId) {
      this.updateUserPreference(false)
    }
  }

  async updateUserPreference(isDark) {
    try {
      const csrfToken = document.querySelector('[name="csrf-token"]')
      if (!csrfToken) {
        console.warn('CSRF token not found, cannot update dark mode preference')
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
        // Handle different error types
        if (response.status === 401 || response.status === 403) {
          console.warn('Authentication error: User session may have expired')
          // Don't show error to user - they may have been logged out
        } else if (response.status === 422) {
          console.warn('Validation error: Invalid dark mode preference value')
        } else if (response.status >= 500) {
          console.error('Server error: Failed to update dark mode preference', response.status)
          // Could show a toast notification here if desired
        } else {
          console.warn('Failed to update dark mode preference', response.status)
        }
        // Note: Theme change still works locally, just database sync failed
        // This is acceptable - preference will sync on next successful request
      }
    } catch (error) {
      // Handle network errors, CORS errors, etc.
      if (error.name === 'TypeError' && error.message.includes('fetch')) {
        console.warn('Network error: Could not connect to server to sync dark mode preference')
      } else if (error.name === 'SyntaxError') {
        console.error('Response parsing error: Invalid JSON from server')
      } else {
        console.error('Unexpected error updating dark mode preference:', error)
      }
      // Note: Theme change still works locally, just database sync failed
      // This is acceptable - preference will sync on next successful request
    }
  }
}

