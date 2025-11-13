import { Controller } from "@hotwired/stimulus"

/**
 * Calendar Day Controller
 * 
 * Handles day detail toggling for calendar views.
 * Manages desktop inline details and mobile drawer display.
 * 
 * Attached to: Main calendar container (same element as calendar controller)
 * 
 * Cross-controller access:
 * - getElementById('calendar-day-*') - Day detail elements accessed by ID pattern
 * - getElementById('details-drawer-*') - Drawer elements accessed outside controller scope
 * - getElementById('application-main-container') - Shared layout element
 * 
 * @see .cursor/rules/conventions/ID_naming_strategy/id_naming_category.mdc (lines 668-678)
 * @see .cursor/rules/development/hotwire/stimulus_controllers.mdc
 */
export default class extends Controller {
  connect() {
    // Cache all day elements for efficient lookup
    this.allDayElements = document.querySelectorAll('[id^="calendar-day-"]')
  }

  disconnect() {
    // Clean up any bound handlers
    if (this._detailsCloseBound) {
      this._detailsCloseBound = false
    }
  }

  // Handle keyboard navigation for day cards
  handleDayKey(event) {
    // Only handle Enter and Space keys
    if (event.key === 'Enter' || event.key === ' ') {
      event.preventDefault()
      // Trigger the same action as click
      this.toggleDay(event)
    }
  }

  // Toggle day details (for month view expandable details)
  toggleDay(event) {
    const dayId = event.currentTarget.dataset.dayId
    // Cross-controller access: day details element may be outside controller scope
    // Per rules: Keep getElementById for dynamic ID-based access
    const detailsEl = document.getElementById(dayId)
    if (!detailsEl) return

    // Mobile: open in drawer/modal instead of inline
    const isMobile = window.matchMedia('(max-width: 640px)').matches
    if (isMobile) {
      // Inject details into the mobile drawer and open it
      // Cross-controller access: drawer elements are accessed outside controller scope
      // Per rules: Keep getElementById for elements accessed by multiple controllers
      // @see .cursor/rules/conventions/ID_naming_strategy/id_naming_category.mdc (lines 668-678)
      try {
        const drawer = document.getElementById('details-drawer-modal')
        const panel = document.getElementById('details-drawer-panel')
        const content = document.getElementById('details-drawer-content')
        const mainContent = document.getElementById('application-main-container')
        const closeBtn = document.getElementById('details-drawer-close-button')

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
    // Cross-controller access: week details slot is dynamically created and accessed
    // Per rules: Keep getElementById for dynamic ID-based access outside controller scope
    const slot = document.getElementById(`calendar-week-details-${weekIndex}`)
    if (!slot) return

    // Ensure we have a cache of all detail elements to hide when needed
    // Use Stimulus targets where possible, but day elements are dynamically created
    // Per rules: For dynamic elements with ID patterns, querySelector is acceptable
    // @see .cursor/rules/development/hotwire/stimulus_controllers.mdc
    if (!this.allDayElements) {
      this.allDayElements = document.querySelectorAll('[id^="calendar-day-"]')
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

