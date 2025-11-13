/**
 * Calendar Scroll Helper
 * 
 * Shared utilities for preserving scroll position during calendar navigation.
 * Used by calendar_controller.js to maintain scroll position across Turbo Frame updates.
 * 
 * Note: Month navigation scroll preservation is handled by month_nav_controller.js
 * This helper handles scroll preservation for full page loads/navigation (turbo:load)
 * 
 * @see .cursor/rules/conventions/ID_naming_strategy/id_naming_category.mdc (lines 668-678)
 */

// Global flag to ensure scroll listeners are only added once
let scrollListenersAdded = false
let scrollPreservationCleanup = null

/**
 * Set up scroll preservation for calendar views
 * 
 * Saves scroll position before page is cached and restores it after page loads.
 * Also prevents scroll-to-top on calendar navigation button clicks.
 * 
 * @returns {Function} Cleanup function to remove listeners
 */
export function setupCalendarScrollPreservation() {
  // Only set up once globally
  if (scrollListenersAdded) {
    return scrollPreservationCleanup
  }

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

  // Prevent scroll-to-top on calendar navigation button clicks
  // Turbo Frame already has data-turbo-preserve-scroll="true", but we add extra protection
  const calendarFrame = document.getElementById('calendar_content')
  if (calendarFrame) {
    // Listen for turbo:frame-load to ensure scroll is preserved
    calendarFrame.addEventListener('turbo:frame-load', (event) => {
      // Get the scroll position before the frame loaded
      const savedScroll = sessionStorage.getItem('calendar_scroll_pos_before_frame')
      if (savedScroll) {
        // Restore scroll position after frame loads
        requestAnimationFrame(() => {
          window.scrollTo(0, parseInt(savedScroll, 10))
          sessionStorage.removeItem('calendar_scroll_pos_before_frame')
        })
      }
    })

    // Save scroll position before any navigation within the frame
    const saveScrollBeforeNavigation = (event) => {
      // Only save if clicking calendar navigation buttons
      const target = event.target.closest('a[data-turbo-frame="calendar_content"]')
      if (target) {
        sessionStorage.setItem('calendar_scroll_pos_before_frame', window.scrollY.toString())
      }
    }

    // Listen for clicks on calendar navigation elements
    document.addEventListener('click', saveScrollBeforeNavigation, true)
    
    // Store cleanup function
    scrollPreservationCleanup = () => {
      document.removeEventListener('click', saveScrollBeforeNavigation, true)
      document.removeEventListener('turbo:before-cache', beforeCacheHandler)
      document.removeEventListener('turbo:load', loadHandler)
      scrollPreservationCleanup = null
    }
  } else {
    // Store cleanup function even if frame not found
    scrollPreservationCleanup = () => {
      document.removeEventListener('turbo:before-cache', beforeCacheHandler)
      document.removeEventListener('turbo:load', loadHandler)
      scrollPreservationCleanup = null
    }
  }

  scrollListenersAdded = true
  return scrollPreservationCleanup
}

/**
 * Clean up scroll preservation listeners
 */
export function cleanupCalendarScrollPreservation() {
  if (scrollPreservationCleanup) {
    scrollPreservationCleanup()
  }
  scrollListenersAdded = false
}

