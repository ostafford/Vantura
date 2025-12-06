import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // Check for saved theme preference or default to light mode
    const savedTheme = localStorage.getItem('theme')
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
    localStorage.setItem('theme', 'dark')
    
    // Update user preference if user is signed in
    if (window.currentUserId) {
      this.updateUserPreference(true)
    }
  }

  disableDarkMode() {
    document.documentElement.classList.remove('dark')
    localStorage.setItem('theme', 'light')
    
    // Update user preference if user is signed in
    if (window.currentUserId) {
      this.updateUserPreference(false)
    }
  }

  async updateUserPreference(isDark) {
    try {
      const response = await fetch('/settings', {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({ user: { dark_mode: isDark } })
      })
      
      if (!response.ok) {
        console.warn('Failed to update dark mode preference')
      }
    } catch (error) {
      console.warn('Error updating dark mode preference:', error)
    }
  }
}

