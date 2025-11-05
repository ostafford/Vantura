/**
 * Scroll Helper
 * 
 * Shared utilities for preserving scroll position during Turbo Stream updates.
 * Used by month_nav_controller.js and week_nav_controller.js.
 * 
 * This helper aggressively prevents scrolling during Turbo Stream rendering
 * to maintain the user's scroll position when navigating between months/weeks.
 * 
 * @see docs/stimulus-controllers-architecture.md
 */

/**
 * Restore scroll position after Turbo Stream rendering completes
 * 
 * Strategy: Aggressively prevent scrolling during Turbo Stream updates.
 * The browser may try to scroll to replaced elements, so we block all scroll changes
 * until our restoration happens.
 * 
 * @param {number} scrollY - The saved scroll position to restore
 * @param {string} frameId - Optional Turbo Frame ID to watch for mutations
 * @param {string} containerId - Optional container ID, defaults to 'main-content-container'
 */
export function restoreScrollAfterStream(scrollY, frameId = null, containerId = 'main-content-container') {
  // Cross-controller access: main-content-container is shared layout element
  // Per rules: Keep getElementById for elements accessed outside controller scope
  // @see .cursor/rules/conventions/ID_naming_strategy/id_naming_category.mdc (lines 668-678)
  const scrollableElement = document.getElementById(containerId) || window
  const isWindow = scrollableElement === window
  const savedScrollPosition = scrollY
  
  // Immediately lock scroll position before any updates happen
  if (isWindow) {
    window.scrollTo(0, savedScrollPosition)
  } else {
    scrollableElement.scrollTop = savedScrollPosition
  }
  
  // Prevent scroll restoration by browser
  const originalScrollRestoration = 'scrollRestoration' in window.history 
    ? window.history.scrollRestoration 
    : null
  if (originalScrollRestoration) {
    window.history.scrollRestoration = 'manual'
  }
  
  let scrollBlocked = true
  let restorationComplete = false
  
  // Actively block scroll changes during update
  const blockScroll = (e) => {
    if (scrollBlocked && !restorationComplete) {
      if (isWindow) {
        window.scrollTo(0, savedScrollPosition)
      } else {
        scrollableElement.scrollTop = savedScrollPosition
      }
      e.preventDefault && e.preventDefault()
      return false
    }
  }
  
  // Block scroll events
  if (isWindow) {
    window.addEventListener('scroll', blockScroll, { passive: false, capture: true })
  } else {
    scrollableElement.addEventListener('scroll', blockScroll, { passive: false, capture: true })
  }
  
  // Force scroll position continuously during updates (every frame)
  let forceScrollId = null
  const forceScrollPosition = () => {
    if (scrollBlocked && !restorationComplete) {
      if (isWindow) {
        const currentScroll = window.scrollY
        if (Math.abs(currentScroll - savedScrollPosition) > 1) {
          window.scrollTo(0, savedScrollPosition)
        }
      } else {
        const currentScroll = scrollableElement.scrollTop
        if (Math.abs(currentScroll - savedScrollPosition) > 1) {
          scrollableElement.scrollTop = savedScrollPosition
        }
      }
      forceScrollId = requestAnimationFrame(forceScrollPosition)
    }
  }
  forceScrollPosition()
  
  const restoreScroll = () => {
    if (restorationComplete) return
    restorationComplete = true
    scrollBlocked = false
    
    // Cancel the continuous scroll forcing
    if (forceScrollId !== null) {
      cancelAnimationFrame(forceScrollId)
      forceScrollId = null
    }
    
    // Remove scroll blocker
    if (isWindow) {
      window.removeEventListener('scroll', blockScroll, { capture: true })
    } else {
      scrollableElement.removeEventListener('scroll', blockScroll, { capture: true })
    }
    
    // Restore scroll position after a brief delay
    requestAnimationFrame(() => {
      requestAnimationFrame(() => {
        if (isWindow) {
          window.scrollTo(0, savedScrollPosition)
        } else {
          scrollableElement.scrollTop = savedScrollPosition
        }
        
        if (originalScrollRestoration) {
          window.history.scrollRestoration = originalScrollRestoration
        }
      })
    })
  }
  
  // Approach 1: Listen for turbo:after-stream-render event
  const streamRenderHandler = () => {
    requestAnimationFrame(() => {
      requestAnimationFrame(() => {
        setTimeout(() => {
          restoreScroll()
        }, 150)
      })
    })
  }
  document.addEventListener('turbo:after-stream-render', streamRenderHandler, { once: true })
  
  // Approach 2: Watch for DOM mutations to complete
  const turboFrame = frameId ? (document.getElementById(frameId) || document.querySelector(`turbo-frame#${frameId}`)) : null
  if (turboFrame) {
    let mutationTimeout
    let mutationCount = 0
    
    const observer = new MutationObserver(() => {
      mutationCount++
      clearTimeout(mutationTimeout)
      mutationTimeout = setTimeout(() => {
        // Wait for mutations to settle
        if (mutationCount > 0) {
          restoreScroll()
          observer.disconnect()
        }
      }, 200)
    })
    
    observer.observe(turboFrame, {
      childList: true,
      subtree: true,
      attributes: true
    })
    
    // Also observe scrollable container
    if (!isWindow) {
      observer.observe(scrollableElement, {
        childList: true,
        subtree: true
      })
    }
    
    // Cleanup after timeout
    setTimeout(() => {
      observer.disconnect()
      restoreScroll()
    }, 2000)
  }
  
  // Approach 3: Fallback - always restore after reasonable delay
  setTimeout(() => {
    restoreScroll()
  }, 800)
}
