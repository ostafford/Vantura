import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["backdrop"]

  connect() {
    // Sidebar toggle is handled by Flowbite's drawer component via data-drawer-toggle
    // This controller handles backdrop click to close and syncs backdrop visibility with drawer state
    
    const sidebar = document.getElementById('sidebar')
    const backdrop = this.backdropTarget
    
    // Sync backdrop visibility with drawer state
    // Flowbite drawer uses aria-hidden attribute to track state
    const observer = new MutationObserver(() => {
      const isHidden = sidebar.classList.contains('-translate-x-full') || 
                       sidebar.getAttribute('aria-hidden') === 'true'
      if (isHidden) {
        backdrop.classList.add('hidden')
      } else {
        backdrop.classList.remove('hidden')
      }
    })
    
    observer.observe(sidebar, {
      attributes: true,
      attributeFilter: ['class', 'aria-hidden']
    })
    
    // Initial sync
    const isHidden = sidebar.classList.contains('-translate-x-full') || 
                     sidebar.getAttribute('aria-hidden') === 'true'
    if (isHidden) {
      backdrop.classList.add('hidden')
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
      sidebar.classList.add('-translate-x-full')
      sidebar.setAttribute('aria-hidden', 'true')
      backdrop.classList.add('hidden')
    }
  }
}

