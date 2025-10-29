import { Controller } from '@hotwired/stimulus'

// Global flag to ensure scroll listeners are only added once
let scrollListenersAdded = false

// Connects to data-controller="calendar"
export default class extends Controller {
  private transactionCreatedHandler?: (e: Event) => void
  private allDayElements?: NodeListOf<HTMLElement>

  connect(): void {
    // Save current view to localStorage for persistence
    const viewLinks = this.element.querySelectorAll<HTMLElement>('[data-view]')
    viewLinks.forEach(link => {
      link.addEventListener('click', e => {
        const target = e.currentTarget as HTMLElement
        const view = target.dataset.view
        if (view) {
          localStorage.setItem('calendarView', view)
        }
      })
    })

    // Set up scroll preservation only once globally
    if (!scrollListenersAdded) {
      this.setupScrollPreservation()
      scrollListenersAdded = true
    }

    // Listen for transaction creation events and refresh calendar
    this.transactionCreatedHandler = this.handleTransactionCreated.bind(this)
    window.addEventListener('transaction:created', this.transactionCreatedHandler)
  }

  disconnect(): void {
    // Clean up event listener
    if (this.transactionCreatedHandler) {
      window.removeEventListener('transaction:created', this.transactionCreatedHandler)
    }
  }

  handleTransactionCreated(_event: Event): void {
    // Refresh the calendar frame when a transaction is created
    console.log('Transaction created event received, refreshing calendar...')
    const calendarFrame = document.getElementById('calendar_content')
    if (calendarFrame) {
      const currentUrl = new URL(window.location.href)
      // Add a timestamp to force reload
      currentUrl.searchParams.set('_refresh', Date.now().toString())

      // Navigate to the URL with the frame
      Turbo.visit(currentUrl.toString(), {
        frame: 'calendar_content',
        action: 'replace',
      })
    } else {
      console.log('Calendar frame not found, reloading page')
      window.location.reload()
    }
  }

  setupScrollPreservation(): void {
    // Save scroll position before page is cached
    const beforeCacheHandler = (): void => {
      if (window.scrollY > 0) {
        sessionStorage.setItem('calendar_scroll_pos', window.scrollY.toString())
      }
    }

    // Restore scroll position after page loads
    const loadHandler = (): void => {
      const savedScroll = sessionStorage.getItem('calendar_scroll_pos')
      if (savedScroll) {
        // Use requestAnimationFrame to ensure DOM is ready
        requestAnimationFrame(() => {
          requestAnimationFrame(() => {
            window.scrollTo(0, parseInt(savedScroll, 10))
            // Clear after use
            sessionStorage.removeItem('calendar_scroll_pos')
          })
        })
      }
    }

    document.addEventListener('turbo:before-cache', beforeCacheHandler)
    document.addEventListener('turbo:load', loadHandler)
  }

  // Toggle day details (for month view expandable details)
  toggleDay(event: Event): void {
    const target = event.currentTarget as HTMLElement
    const dayId = target.dataset.dayId
    if (!dayId) return

    const element = document.getElementById(dayId)
    if (!element) return

    // Cache the query selector result for better performance
    if (!this.allDayElements) {
      this.allDayElements = document.querySelectorAll<HTMLElement>('[id^="day-"]')
    }

    const isHidden = element.classList.contains('hidden')

    if (isHidden) {
      // Hide all other day details first
      this.allDayElements.forEach(el => {
        if (el.id !== dayId) {
          el.classList.add('hidden')
        }
      })
      // Show this day's details
      element.classList.remove('hidden')
      // Smooth scroll to the details using requestAnimationFrame for better performance
      requestAnimationFrame(() => {
        requestAnimationFrame(() => {
          element.scrollIntoView({ behavior: 'smooth', block: 'nearest' })
        })
      })
    } else {
      // Hide this day's details
      element.classList.add('hidden')
    }
  }
}
