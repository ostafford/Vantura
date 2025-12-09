import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["syncButton", "syncStatus", "insightBanner"]

  connect() {
    this.checkSyncStatus()
    // Poll for sync status every 30 seconds
    this.syncInterval = setInterval(() => this.checkSyncStatus(), 30000)
  }

  disconnect() {
    if (this.syncInterval) {
      clearInterval(this.syncInterval)
    }
  }

  async manualSync() {
    if (!this.hasSyncButtonTarget) return

    // Get CSRF token
    const csrfTokenElement = document.querySelector('[name="csrf-token"]')
    if (!csrfTokenElement || !csrfTokenElement.content) {
      console.error('CSRF token not found')
      this.showToast('Security token missing. Please refresh the page.', 'error')
      return
    }

    this.syncButtonTarget.disabled = true
    const originalText = this.syncButtonTarget.innerHTML
    this.syncButtonTarget.innerHTML = '<span class="animate-spin">🔄</span> Syncing...'
    
    try {
      const response = await fetch('/sync', {
        method: 'POST',
        headers: {
          'X-CSRF-Token': csrfTokenElement.content,
          'Accept': 'application/json',
          'Content-Type': 'application/json'
        }
      })
      
      if (response.ok) {
        const data = await response.json()
        this.showToast(data.message || 'Sync started! Updates will appear shortly.', 'success')
      } else if (response.status === 401) {
        this.showToast('You are not authorized to sync. Please check your Up Bank connection.', 'error')
      } else {
        this.showToast('Sync failed. Please try again.', 'error')
      }
    } catch (error) {
      console.error('Sync error:', error)
      this.showToast('Sync failed. Please try again.', 'error')
    } finally {
      setTimeout(() => {
        if (this.hasSyncButtonTarget) {
          this.syncButtonTarget.disabled = false
          this.syncButtonTarget.innerHTML = originalText
        }
      }, 2000)
    }
  }

  dismissInsight() {
    if (!this.hasInsightBannerTarget) return

    this.insightBannerTarget.style.display = 'none'
    // Store dismissal in localStorage
    localStorage.setItem('insight_dismissed', Date.now().toString())
  }

  checkSyncStatus() {
    // This can be enhanced to check actual sync status from the server
    // For now, it's a placeholder
  }

  showToast(message, type) {
    // Trigger toast notification
    const event = new CustomEvent('toast:show', {
      detail: { message, type }
    })
    window.dispatchEvent(event)
  }
}

