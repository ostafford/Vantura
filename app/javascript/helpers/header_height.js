// Helper utility for calculating and setting page header height
// This ensures main content has proper spacing to avoid overlap with sticky header

let resizeObserver = null
let mutationObserver = null

/**
 * Calculate the height of the page header and set it as a CSS custom property
 */
export function calculateHeaderHeight() {
  const header = document.getElementById('page-header')
  
  if (!header) {
    // No header on this page, set height to 0
    document.documentElement.style.setProperty('--page-header-height', '0px')
    return
  }

  // Get the actual rendered height of the header
  const height = header.offsetHeight
  
  // Set CSS custom property on root element
  document.documentElement.style.setProperty('--page-header-height', `${height}px`)
}

/**
 * Initialize header height calculation and observers
 */
export function initializeHeaderHeight() {
  // Calculate initial height
  calculateHeaderHeight()

  // Set up ResizeObserver to watch for header size changes
  const header = document.getElementById('page-header')
  if (header && !resizeObserver) {
    resizeObserver = new ResizeObserver(() => {
      calculateHeaderHeight()
    })
    resizeObserver.observe(header)
  }

  // Set up MutationObserver to watch for content changes (e.g., calendar week data visibility)
  if (header && !mutationObserver) {
    mutationObserver = new MutationObserver(() => {
      // Debounce rapid changes
      clearTimeout(mutationObserver.timeout)
      mutationObserver.timeout = setTimeout(() => {
        calculateHeaderHeight()
      }, 100)
    })
    
    mutationObserver.observe(header, {
      childList: true,
      subtree: true,
      attributes: true,
      attributeFilter: ['class', 'style']
    })
  }
}

/**
 * Clean up observers
 */
export function cleanupHeaderHeight() {
  if (resizeObserver) {
    resizeObserver.disconnect()
    resizeObserver = null
  }
  
  if (mutationObserver) {
    mutationObserver.disconnect()
    if (mutationObserver.timeout) {
      clearTimeout(mutationObserver.timeout)
    }
    mutationObserver = null
  }
}

// Recalculate on window resize (for responsive changes)
let resizeTimeout
window.addEventListener('resize', () => {
  clearTimeout(resizeTimeout)
  resizeTimeout = setTimeout(() => {
    calculateHeaderHeight()
  }, 150)
})

