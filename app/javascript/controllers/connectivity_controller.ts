// Connectivity Controller
// Monitors online/offline status and displays visual indicator

import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['indicator']

  declare readonly hasIndicatorTarget: boolean
  declare readonly indicatorTarget: HTMLElement

  private onlineHandler!: () => void
  private offlineHandler!: () => void
  private statusInterval?: number

  connect(): void {
    // Set initial state
    this.updateStatus()

    // Bind handlers so we can remove them later
    this.onlineHandler = () => this.handleOnline()
    this.offlineHandler = () => this.handleOffline()

    // Listen for online/offline events
    window.addEventListener('online', this.onlineHandler)
    window.addEventListener('offline', this.offlineHandler)

    // Also check navigator.onLine periodically (more reliable)
    this.statusInterval = window.setInterval(() => this.updateStatus(), 5000)
  }

  disconnect(): void {
    window.removeEventListener('online', this.onlineHandler)
    window.removeEventListener('offline', this.offlineHandler)

    if (this.statusInterval !== undefined) {
      window.clearInterval(this.statusInterval)
    }
  }

  updateStatus(): void {
    if (navigator.onLine) {
      this.handleOnline()
    } else {
      this.handleOffline()
    }
  }

  handleOnline(): void {
    this.element.classList.remove('offline')
    this.element.classList.add('online')

    // Remove any offline indicator
    const indicator = document.querySelector<HTMLElement>('[data-connectivity-target="indicator"]')
    if (indicator) {
      indicator.classList.add('hidden')
    }
  }

  handleOffline(): void {
    this.element.classList.remove('online')
    this.element.classList.add('offline')

    // Show offline indicator
    const indicator = document.querySelector<HTMLElement>('[data-connectivity-target="indicator"]')
    if (indicator) {
      indicator.classList.remove('hidden')
    } else {
      this.createOfflineIndicator()
    }
  }

  createOfflineIndicator(): void {
    const notification = document.createElement('div')
    notification.setAttribute('data-connectivity-target', 'indicator')
    notification.className =
      'fixed top-0 left-0 right-0 bg-warning-500 text-white px-4 py-2 text-center z-50'
    notification.textContent = 'You are offline. Some features may be unavailable.'
    document.body.appendChild(notification)
  }
}
