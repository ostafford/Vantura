import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["backdrop"]

  connect() {
    // Sidebar toggle is handled by Flowbite's drawer component via data-drawer-toggle
    // This controller handles backdrop click to close and syncs backdrop visibility with drawer state
    
    const sidebar = document.getElementById('sidebar')
    const backdrop = this.backdropTarget
    
    // Continuously monitor sidebar state and blur focused elements when hidden
    // This prevents accessibility warnings about aria-hidden on focused elements
    // Using requestAnimationFrame ensures we catch state changes immediately
    const checkAndBlur = () => {
      const isHidden = sidebar.classList.contains('-translate-x-full') || 
                       sidebar.getAttribute('aria-hidden') === 'true'
      
      if (isHidden) {
        backdrop.classList.add('hidden')
        // Aggressively blur any focused elements inside hidden sidebar
        const activeElement = document.activeElement
        if (activeElement && sidebar.contains(activeElement)) {
          activeElement.blur()
        }
      } else {
        backdrop.classList.remove('hidden')
      }
      
      // Continue monitoring on next animation frame
      requestAnimationFrame(checkAndBlur)
    }
    
    // Start continuous monitoring loop
    requestAnimationFrame(checkAndBlur)
    
    // Prevent focus from entering hidden sidebar (capture phase to intercept early)
    // Use a flag to prevent infinite recursion
    let isHandlingFocus = false
    sidebar.addEventListener('focusin', (e) => {
      // Prevent re-entry to avoid infinite recursion
      if (isHandlingFocus) {
        e.stopPropagation()
        return
      }
      
      const isHidden = sidebar.classList.contains('-translate-x-full') || 
                       sidebar.getAttribute('aria-hidden') === 'true'
      if (isHidden && sidebar.contains(e.target)) {
        isHandlingFocus = true
        e.stopPropagation() // Stop event from propagating
        e.target.blur()
        // Don't redirect focus - just blur. The requestAnimationFrame loop handles any remaining focus.
        // Redirecting focus causes infinite loops when the target triggers focusin events.
        // Use setTimeout to reset flag after current event loop completes
        setTimeout(() => {
          isHandlingFocus = false
        }, 0)
      }
    }, true) // Use capture phase to intercept focus events before they reach the target
    
    // Initial sync
    const isHidden = sidebar.classList.contains('-translate-x-full') || 
                     sidebar.getAttribute('aria-hidden') === 'true'
    if (isHidden) {
      backdrop.classList.add('hidden')
      const activeElement = document.activeElement
      if (activeElement && sidebar.contains(activeElement)) {
        activeElement.blur()
      }
    }
  }

  close() {
    // Close drawer by clicking the toggle button (which Flowbite handles)
    // This ensures Flowbite's drawer state is properly managed
    const toggleButton = document.querySelector('[data-drawer-toggle="sidebar"]')
    if (toggleButton) {
      toggleButton.click()
    } else {
      // Fallback: manually close drawer if toggle button not found
      const sidebar = document.getElementById('sidebar')
      const backdrop = this.backdropTarget
      
      // Blur any focused elements BEFORE hiding to prevent accessibility warnings
      const activeElement = document.activeElement
      if (activeElement && sidebar.contains(activeElement)) {
        activeElement.blur()
      }
      
      sidebar.classList.add('-translate-x-full')
      sidebar.setAttribute('aria-hidden', 'true')
      backdrop.classList.add('hidden')
    }
  }
}

