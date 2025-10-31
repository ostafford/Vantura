import { Controller } from "@hotwired/stimulus"

// Global flag to ensure scroll listeners are only added once
let scrollListenersAdded = false

// Connects to data-controller="calendar"
export default class extends Controller {
  connect() {
    // Save current view to localStorage for persistence
    const viewLinks = this.element.querySelectorAll('[data-view]')
    viewLinks.forEach(link => {
      link.addEventListener('click', (e) => {
        const view = e.currentTarget.dataset.view
        localStorage.setItem('calendarView', view)
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

  disconnect() {
    // Clean up event listener
    window.removeEventListener('transaction:created', this.transactionCreatedHandler)
  }

  handleTransactionCreated(event) {
    // Refresh the calendar frame when a transaction is created
    console.log('Transaction created event received, refreshing calendar...')
    const calendarFrame = document.getElementById('calendar_content')
    if (calendarFrame) {
      const currentUrl = new URL(window.location.href)
      // Add a timestamp to force reload
      currentUrl.searchParams.set('_refresh', Date.now())
      
      // Navigate to the URL with the frame
      Turbo.visit(currentUrl.toString(), { 
        frame: 'calendar_content',
        action: 'replace' 
      })
    } else {
      console.log('Calendar frame not found, reloading page')
      window.location.reload()
    }
  }
  
  setupScrollPreservation() {
    // Save scroll position before page is cached
    const beforeCacheHandler = () => {
      if (window.scrollY > 0) {
        sessionStorage.setItem('calendar_scroll_pos', window.scrollY.toString())
      }
    }
    
    // Restore scroll position after page loads
    const loadHandler = () => {
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
  toggleDay(event) {
    const dayId = event.currentTarget.dataset.dayId
    const detailsEl = document.getElementById(dayId)
    if (!detailsEl) return

    // Mobile: open in drawer/modal instead of inline
    const isMobile = window.matchMedia('(max-width: 640px)').matches
    if (isMobile) {
      // Inject details into the mobile drawer and open it
      try {
        const drawer = document.getElementById('detailsDrawer')
        const panel = document.getElementById('detailsDrawerPanel')
        const content = document.getElementById('detailsDrawerContent')
        const mainContent = document.getElementById('mainContent')
        const closeBtn = document.getElementById('detailsDrawerClose')

        if (drawer && panel && content && mainContent) {
          // Insert cloned HTML so desktop inline panel can remain hidden/independent
          const clone = detailsEl.cloneNode(true)
          clone.classList.remove('hidden', 'mt-6')
          content.innerHTML = ''
          content.appendChild(clone)

          // Open drawer
          drawer.classList.remove('hidden')
          drawer.classList.add('flex')
          // shrink main content on desktop only; on mobile it's full width already
          if (window.innerWidth >= 640) {
            mainContent.classList.add('sm:mr-96')
          }
          // slide in
          panel.classList.remove('translate-x-full')
          panel.classList.add('translate-x-0')

          // Wire close behavior (idempotent)
          if (closeBtn && !this._detailsCloseBound) {
            closeBtn.addEventListener('click', () => {
              // slide out
              panel.classList.remove('translate-x-0')
              panel.classList.add('translate-x-full')
              // restore content
              mainContent.classList.remove('sm:mr-96')
              setTimeout(() => {
                drawer.classList.add('hidden')
                drawer.classList.remove('flex')
                content.innerHTML = ''
              }, 300)
            })
            this._detailsCloseBound = true
          }
        } else {
          // fallback: reveal in place
          detailsEl.classList.remove('hidden')
        }
      } catch (e) {
        // fallback: reveal in place
        detailsEl.classList.remove('hidden')
      }
      return
    }

    // Desktop: inject into this week's inline slot
    const weekContainer = event.currentTarget.closest('[data-week-index]')
    if (!weekContainer) return
    const weekIndex = weekContainer.getAttribute('data-week-index')
    const slot = document.getElementById(`week-details-${weekIndex}`)
    if (!slot) return

    // Ensure we have a cache of all detail elements to hide when needed
    if (!this.allDayElements) {
      this.allDayElements = document.querySelectorAll('[id^="day-"]')
    }

    // If this detailsEl is already shown inside slot, toggle it closed
    const alreadyInSlot = slot.contains(detailsEl) && !detailsEl.classList.contains('hidden')
    if (alreadyInSlot) {
      detailsEl.classList.add('hidden')
      return
    }

    // Hide any currently shown details in this slot
    Array.from(slot.children).forEach(child => child.classList.add('hidden'))

    // Move the selected details element into the slot (keeps a single DOM instance)
    // Normalize spacing when moved inline
    detailsEl.classList.remove('mt-6')
    slot.appendChild(detailsEl)
    detailsEl.classList.remove('hidden')

    // Smooth scroll to the inline details
    requestAnimationFrame(() => {
      requestAnimationFrame(() => {
        detailsEl.scrollIntoView({ behavior: 'smooth', block: 'nearest' })
      })
    })
  }
}

