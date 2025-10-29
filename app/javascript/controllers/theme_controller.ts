import { Controller } from '@hotwired/stimulus'

// Connects to data-controller="theme"
export default class extends Controller {
  static targets = ['button']

  declare readonly hasButtonTarget: boolean
  declare readonly buttonTarget: HTMLButtonElement

  private mediaQueryListener?: (e: MediaQueryListEvent) => void

  connect(): void {
    // Theme is already initialized in the <head> to prevent FOUC
    // Just update the button UI and listen for system theme changes
    this.updateButton()

    // Listen for system theme changes when in auto mode
    const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)')
    this.mediaQueryListener = (_e: MediaQueryListEvent) => {
      if (this.currentTheme === 'auto') {
        this.applyTheme('auto')
      }
    }
    mediaQuery.addEventListener('change', this.mediaQueryListener)
  }

  disconnect(): void {
    if (this.mediaQueryListener) {
      window
        .matchMedia('(prefers-color-scheme: dark)')
        .removeEventListener('change', this.mediaQueryListener)
    }
  }

  // Toggle between light, dark, and auto
  toggle(event?: Event): void {
    event?.preventDefault()

    const current = this.currentTheme
    let next: 'light' | 'dark' | 'auto'

    if (current === 'light') {
      next = 'dark'
    } else if (current === 'dark') {
      next = 'auto'
    } else {
      next = 'light'
    }

    this.applyTheme(next)
    this.updateButton()
  }

  // Apply the theme
  applyTheme(theme: 'light' | 'dark' | 'auto'): void {
    const root = document.documentElement

    if (theme === 'dark') {
      root.classList.add('dark')
    } else if (theme === 'light') {
      root.classList.remove('dark')
    } else {
      // Auto mode - use system preference
      if (window.matchMedia('(prefers-color-scheme: dark)').matches) {
        root.classList.add('dark')
      } else {
        root.classList.remove('dark')
      }
    }

    localStorage.setItem('theme', theme)
  }

  // Update the theme button UI
  updateButton(): void {
    if (!this.hasButtonTarget) return

    const theme = this.currentTheme
    const btn = this.buttonTarget

    const icons: Record<string, string> = {
      light:
        '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 3v1m0 16v1m9-9h-1M4 12H3m15.364 6.364l-.707-.707M6.343 6.343l-.707-.707m12.728 0l-.707.707M6.343 17.657l-.707.707M16 12a4 4 0 11-8 0 4 4 0 018 0z"></path>',
      dark: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20.354 15.354A9 9 0 018.646 3.646 9.003 9.003 0 0012 21a9.003 9.003 0 008.354-5.646z"></path>',
      auto: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z"></path>',
    }

    const labels: Record<string, string> = {
      light: 'Light',
      dark: 'Dark',
      auto: 'Auto',
    }

    const svg = btn.querySelector('svg')
    const span = btn.querySelector('span')

    if (svg) svg.innerHTML = icons[theme] || icons.auto
    if (span) span.textContent = labels[theme] || labels.auto
  }

  // Helper to get current theme
  get currentTheme(): 'light' | 'dark' | 'auto' {
    return (localStorage.getItem('theme') as 'light' | 'dark' | 'auto') || 'auto'
  }
}
